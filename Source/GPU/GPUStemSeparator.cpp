#include "GPUStemSeparator.h"
#include <cmath>

#if USE_HIP
#include <hip/hip_runtime.h>
#include <rocfft/rocfft.h>

// GPU implementation struct with HIP/rocFFT resources
// Optimized for batch processing and reduced synchronization
struct GPUStemSeparator::GPUImpl
{
    hipStream_t stream = nullptr;
    hipStream_t stream2 = nullptr;  // Second stream for overlapping operations
    rocfft_plan fftPlanForward = nullptr;
    rocfft_plan fftPlanInverse = nullptr;
    rocfft_plan fftPlanBatchForward = nullptr;  // Batch plan for L+R channels
    rocfft_plan fftPlanBatchInverse = nullptr;
    rocfft_execution_info execInfo = nullptr;
    rocfft_execution_info execInfoBatch = nullptr;

    // Device buffers - doubled for batch L+R processing
    float* d_inputL = nullptr;
    float* d_inputR = nullptr;
    float* d_outputL = nullptr;
    float* d_outputR = nullptr;
    float* d_batchInput = nullptr;   // Batched L+R input
    float* d_batchOutput = nullptr;  // Batched L+R output
    void* d_workBuffer = nullptr;
    size_t workBufferSize = 0;

    // Pinned host memory for faster transfers
    float* h_pinnedInput = nullptr;
    float* h_pinnedOutput = nullptr;
    static constexpr int pinnedBufferSize = 4096 * 2;  // 2 channels worth

    bool initialized = false;
    bool batchModeAvailable = false;
    juce::String deviceName;
    int currentFftSize = 0;

    bool initialize (int fftSize)
    {
        hipError_t err;
        currentFftSize = fftSize;

        // Get device info
        int deviceCount = 0;
        err = hipGetDeviceCount (&deviceCount);
        if (err != hipSuccess || deviceCount == 0)
            return false;

        hipDeviceProp_t props;
        err = hipGetDeviceProperties (&props, 0);
        if (err != hipSuccess)
            return false;

        deviceName = juce::String (props.name) + " (" +
                     juce::String (props.multiProcessorCount) + " CUs)";

        // Create streams
        err = hipStreamCreate (&stream);
        if (err != hipSuccess)
            return false;

        err = hipStreamCreate (&stream2);
        if (err != hipSuccess)
        {
            cleanup();
            return false;
        }

        // Allocate device memory (padded for FFT)
        size_t bufferBytes = (fftSize + 2) * sizeof (float);
        size_t batchBufferBytes = bufferBytes * 2;  // For L+R batch

        if (hipMalloc (&d_inputL, bufferBytes) != hipSuccess ||
            hipMalloc (&d_inputR, bufferBytes) != hipSuccess ||
            hipMalloc (&d_outputL, bufferBytes) != hipSuccess ||
            hipMalloc (&d_outputR, bufferBytes) != hipSuccess ||
            hipMalloc (&d_batchInput, batchBufferBytes) != hipSuccess ||
            hipMalloc (&d_batchOutput, batchBufferBytes) != hipSuccess)
        {
            cleanup();
            return false;
        }

        // Allocate pinned host memory for faster transfers
        if (hipHostMalloc (&h_pinnedInput, pinnedBufferSize * sizeof (float), hipHostMallocDefault) != hipSuccess)
            h_pinnedInput = nullptr;
        if (hipHostMalloc (&h_pinnedOutput, pinnedBufferSize * sizeof (float), hipHostMallocDefault) != hipSuccess)
            h_pinnedOutput = nullptr;

        // Create rocFFT plans
        size_t lengths[1] = { (size_t) fftSize };
        rocfft_status status;

        // Single-transform Forward R2C plan
        status = rocfft_plan_create (&fftPlanForward,
                                      rocfft_placement_notinplace,
                                      rocfft_transform_type_real_forward,
                                      rocfft_precision_single,
                                      1, lengths, 1, nullptr);
        if (status != rocfft_status_success)
        {
            cleanup();
            return false;
        }

        // Single-transform Inverse C2R plan
        status = rocfft_plan_create (&fftPlanInverse,
                                      rocfft_placement_notinplace,
                                      rocfft_transform_type_real_inverse,
                                      rocfft_precision_single,
                                      1, lengths, 1, nullptr);
        if (status != rocfft_status_success)
        {
            cleanup();
            return false;
        }

        // Batch plans for processing both channels simultaneously
        status = rocfft_plan_create (&fftPlanBatchForward,
                                      rocfft_placement_notinplace,
                                      rocfft_transform_type_real_forward,
                                      rocfft_precision_single,
                                      1, lengths, 2, nullptr);  // batch=2
        batchModeAvailable = (status == rocfft_status_success);

        if (batchModeAvailable)
        {
            status = rocfft_plan_create (&fftPlanBatchInverse,
                                          rocfft_placement_notinplace,
                                          rocfft_transform_type_real_inverse,
                                          rocfft_precision_single,
                                          1, lengths, 2, nullptr);
            if (status != rocfft_status_success)
                batchModeAvailable = false;
        }

        // Get work buffer size (use largest plan)
        size_t forwardWorkSize = 0, inverseWorkSize = 0, batchWorkSize = 0;
        rocfft_plan_get_work_buffer_size (fftPlanForward, &forwardWorkSize);
        rocfft_plan_get_work_buffer_size (fftPlanInverse, &inverseWorkSize);
        if (batchModeAvailable)
            rocfft_plan_get_work_buffer_size (fftPlanBatchForward, &batchWorkSize);

        workBufferSize = std::max ({forwardWorkSize, inverseWorkSize, batchWorkSize});
        if (workBufferSize > 0)
            hipMalloc (&d_workBuffer, workBufferSize);

        // Create execution info
        rocfft_execution_info_create (&execInfo);
        if (d_workBuffer != nullptr)
            rocfft_execution_info_set_work_buffer (execInfo, d_workBuffer, workBufferSize);
        rocfft_execution_info_set_stream (execInfo, stream);

        // Batch execution info on second stream
        rocfft_execution_info_create (&execInfoBatch);
        if (d_workBuffer != nullptr)
            rocfft_execution_info_set_work_buffer (execInfoBatch, d_workBuffer, workBufferSize);
        rocfft_execution_info_set_stream (execInfoBatch, stream);

        initialized = true;
        return true;
    }

    void cleanup()
    {
        if (fftPlanForward) { rocfft_plan_destroy (fftPlanForward); fftPlanForward = nullptr; }
        if (fftPlanInverse) { rocfft_plan_destroy (fftPlanInverse); fftPlanInverse = nullptr; }
        if (fftPlanBatchForward) { rocfft_plan_destroy (fftPlanBatchForward); fftPlanBatchForward = nullptr; }
        if (fftPlanBatchInverse) { rocfft_plan_destroy (fftPlanBatchInverse); fftPlanBatchInverse = nullptr; }
        if (execInfo) { rocfft_execution_info_destroy (execInfo); execInfo = nullptr; }
        if (execInfoBatch) { rocfft_execution_info_destroy (execInfoBatch); execInfoBatch = nullptr; }
        if (d_inputL) { hipFree (d_inputL); d_inputL = nullptr; }
        if (d_inputR) { hipFree (d_inputR); d_inputR = nullptr; }
        if (d_outputL) { hipFree (d_outputL); d_outputL = nullptr; }
        if (d_outputR) { hipFree (d_outputR); d_outputR = nullptr; }
        if (d_batchInput) { hipFree (d_batchInput); d_batchInput = nullptr; }
        if (d_batchOutput) { hipFree (d_batchOutput); d_batchOutput = nullptr; }
        if (d_workBuffer) { hipFree (d_workBuffer); d_workBuffer = nullptr; }
        if (h_pinnedInput) { hipHostFree (h_pinnedInput); h_pinnedInput = nullptr; }
        if (h_pinnedOutput) { hipHostFree (h_pinnedOutput); h_pinnedOutput = nullptr; }
        if (stream) { hipStreamDestroy (stream); stream = nullptr; }
        if (stream2) { hipStreamDestroy (stream2); stream2 = nullptr; }
        initialized = false;
    }

    // Process both L and R channels with a single batch FFT (more efficient)
    void forwardFFTBatch (float* hostInputL, float* hostInputR,
                          float* hostOutputL, float* hostOutputR, int fftSize)
    {
        if (!initialized) return;

        size_t inputBytes = fftSize * sizeof (float);
        size_t outputBytes = (fftSize + 2) * sizeof (float);

        // Use pinned memory if available for faster transfers
        if (h_pinnedInput && fftSize * 2 <= pinnedBufferSize)
        {
            // Copy to pinned memory first
            std::memcpy (h_pinnedInput, hostInputL, inputBytes);
            std::memcpy (h_pinnedInput + fftSize, hostInputR, inputBytes);

            // Single transfer from pinned memory
            hipMemcpyAsync (d_batchInput, h_pinnedInput, inputBytes * 2,
                            hipMemcpyHostToDevice, stream);
        }
        else
        {
            // Parallel async transfers on separate streams
            hipMemcpyAsync (d_inputL, hostInputL, inputBytes, hipMemcpyHostToDevice, stream);
            hipMemcpyAsync (d_inputR, hostInputR, inputBytes, hipMemcpyHostToDevice, stream2);
        }

        // Execute FFTs
        if (batchModeAvailable && h_pinnedInput)
        {
            // Batch FFT for both channels
            void* inBuffers[1] = { d_batchInput };
            void* outBuffers[1] = { d_batchOutput };
            rocfft_execute (fftPlanBatchForward, inBuffers, outBuffers, execInfoBatch);

            // Copy results back using pinned memory
            hipMemcpyAsync (h_pinnedOutput, d_batchOutput, outputBytes * 2,
                            hipMemcpyDeviceToHost, stream);
            hipStreamSynchronize (stream);

            std::memcpy (hostOutputL, h_pinnedOutput, outputBytes);
            std::memcpy (hostOutputR, h_pinnedOutput + fftSize + 2, outputBytes);
        }
        else
        {
            // Separate FFTs in parallel streams
            void* inBuffersL[1] = { d_inputL };
            void* outBuffersL[1] = { d_outputL };
            rocfft_execute (fftPlanForward, inBuffersL, outBuffersL, execInfo);

            void* inBuffersR[1] = { d_inputR };
            void* outBuffersR[1] = { d_outputR };
            // Note: We use same execInfo but HIP handles concurrent kernel execution
            rocfft_execute (fftPlanForward, inBuffersR, outBuffersR, execInfo);

            // Copy results back
            hipMemcpyAsync (hostOutputL, d_outputL, outputBytes, hipMemcpyDeviceToHost, stream);
            hipMemcpyAsync (hostOutputR, d_outputR, outputBytes, hipMemcpyDeviceToHost, stream);
            hipStreamSynchronize (stream);
        }
    }

    // Legacy single-channel forward FFT (kept for compatibility)
    void forwardFFT (float* hostInput, float* hostOutput, int fftSize)
    {
        if (!initialized) return;

        // Copy input to device
        hipMemcpyAsync (d_inputL, hostInput, fftSize * sizeof (float),
                        hipMemcpyHostToDevice, stream);

        // Execute forward FFT
        void* inBuffers[1] = { d_inputL };
        void* outBuffers[1] = { d_outputL };
        rocfft_execute (fftPlanForward, inBuffers, outBuffers, execInfo);

        // Copy result back
        hipMemcpyAsync (hostOutput, d_outputL, (fftSize + 2) * sizeof (float),
                        hipMemcpyDeviceToHost, stream);
        hipStreamSynchronize (stream);
    }

    void inverseFFT (float* hostInput, float* hostOutput, int fftSize)
    {
        if (!initialized) return;

        // Copy input to device
        hipMemcpyAsync (d_inputL, hostInput, (fftSize + 2) * sizeof (float),
                        hipMemcpyHostToDevice, stream);

        // Execute inverse FFT
        void* inBuffers[1] = { d_inputL };
        void* outBuffers[1] = { d_outputL };
        rocfft_execute (fftPlanInverse, inBuffers, outBuffers, execInfo);

        // Copy result back
        hipMemcpyAsync (hostOutput, d_outputL, fftSize * sizeof (float),
                        hipMemcpyDeviceToHost, stream);
        hipStreamSynchronize (stream);
    }

    // Check if batch mode is available (more efficient)
    bool hasBatchMode() const { return batchModeAvailable; }
};
#else
// Stub implementation when HIP is not available
struct GPUStemSeparator::GPUImpl
{
    bool initialized = false;
    juce::String deviceName = "N/A";
    bool initialize (int) { return false; }
    void cleanup() {}
    void forwardFFT (float*, float*, int) {}
    void inverseFFT (float*, float*, int) {}
    void forwardFFTBatch (float*, float*, float*, float*, int) {}
    bool hasBatchMode() const { return false; }
};
#endif

GPUStemSeparator::GPUStemSeparator()
    : gpu (std::make_unique<GPUImpl>())
{
    // Initialize window (Hann)
    window.resize (fftSize);
    for (int i = 0; i < fftSize; ++i)
        window[static_cast<size_t> (i)] = 0.5f * (1.0f - std::cos (2.0f * juce::MathConstants<float>::pi * i / (fftSize - 1)));

    // Initialize FFT buffers (separate for L and R for batch processing)
    fftBufferL.resize (fftSize * 2, 0.0f);
    fftBufferR.resize (fftSize * 2, 0.0f);
    spectrumL.resize (numBins);
    spectrumR.resize (numBins);
    spectrumMid.resize (numBins);
    spectrumSide.resize (numBins);
    prevMagnitude.resize (numBins, 0.0f);

    for (int stem = 0; stem < NumStems; ++stem)
    {
        stemSpectraL[static_cast<size_t> (stem)].resize (numBins);
        stemSpectraR[static_cast<size_t> (stem)].resize (numBins);
    }

    // Input/output buffers
    for (int ch = 0; ch < 2; ++ch)
    {
        inputBuffer[static_cast<size_t> (ch)].resize (fftSize, 0.0f);
        for (int stem = 0; stem < NumStems; ++stem)
            outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)].resize (fftSize, 0.0f);
    }

    // Try to initialize GPU
#if USE_HIP
    gpuAvailable = gpu->initialize (fftSize);
    if (gpuAvailable)
    {
        gpuInfo = gpu->deviceName + " (rocFFT";
        if (gpu->hasBatchMode())
            gpuInfo += ", batch)";
        else
            gpuInfo += ")";
    }
    else
        gpuInfo = "CPU (GPU unavailable)";
#else
    gpuInfo = "CPU (no GPU support)";
#endif
}

GPUStemSeparator::~GPUStemSeparator()
{
#if USE_HIP
    if (gpu)
        gpu->cleanup();
#endif
}

void GPUStemSeparator::prepare (double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    for (int stem = 0; stem < NumStems; ++stem)
        stems[static_cast<size_t> (stem)].setSize (2, maxBlockSize);

    reset();
}

void GPUStemSeparator::reset()
{
    inputWritePos = 0;
    outputReadPos = 0;
    samplesUntilNextFFT = hopSize;

    for (int ch = 0; ch < 2; ++ch)
    {
        std::fill (inputBuffer[static_cast<size_t> (ch)].begin(),
                   inputBuffer[static_cast<size_t> (ch)].end(), 0.0f);
        for (int stem = 0; stem < NumStems; ++stem)
            std::fill (outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)].begin(),
                       outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)].end(), 0.0f);
    }

    std::fill (prevMagnitude.begin(), prevMagnitude.end(), 0.0f);
}

void GPUStemSeparator::process (juce::AudioBuffer<float>& buffer)
{
    int numSamples = buffer.getNumSamples();
    int numChannels = juce::jmin (2, buffer.getNumChannels());

    // Prepare stem output buffers
    for (int stem = 0; stem < NumStems; ++stem)
    {
        stems[static_cast<size_t> (stem)].setSize (2, numSamples, false, false, true);
        stems[static_cast<size_t> (stem)].clear();
    }

    // Process sample by sample through overlap-add
    for (int i = 0; i < numSamples; ++i)
    {
        // Write input to circular buffer
        for (int ch = 0; ch < numChannels; ++ch)
            inputBuffer[static_cast<size_t> (ch)][static_cast<size_t> (inputWritePos)] = buffer.getSample (ch, i);

        // Read output from circular buffer
        for (int stem = 0; stem < NumStems; ++stem)
        {
            for (int ch = 0; ch < numChannels; ++ch)
            {
                stems[static_cast<size_t> (stem)].setSample (ch, i,
                    outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)][static_cast<size_t> (outputReadPos)]);
                outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)][static_cast<size_t> (outputReadPos)] = 0.0f;
            }
        }

        inputWritePos = (inputWritePos + 1) % fftSize;
        outputReadPos = (outputReadPos + 1) % fftSize;
        samplesUntilNextFFT--;

        // Time to process an FFT frame
        if (samplesUntilNextFFT <= 0)
        {
            processFrame();
            samplesUntilNextFFT = hopSize;
        }
    }
}

void GPUStemSeparator::processFrame()
{
    // Process both channels (use batch mode on GPU for efficiency)
#if USE_HIP
    if (gpuAvailable)
    {
        processFFTFrameBatch();  // GPU batch processing for both channels
    }
    else
#endif
    {
        // CPU fallback: process channels separately
        processFFTFrame (0);  // Left
        processFFTFrame (1);  // Right
    }

    // Separate into stems
    separateStems();

    // Synthesize stem outputs
    synthesizeStems();
}

void GPUStemSeparator::processFFTFrameBatch()
{
    int readPos = (inputWritePos - fftSize + fftSize) % fftSize;

    // Copy both channels with window
    for (int i = 0; i < fftSize; ++i)
    {
        int pos = (readPos + i) % fftSize;
        float w = window[static_cast<size_t> (i)];
        fftBufferL[static_cast<size_t> (i)] = inputBuffer[0][static_cast<size_t> (pos)] * w;
        fftBufferR[static_cast<size_t> (i)] = inputBuffer[1][static_cast<size_t> (pos)] * w;
    }

    // Batch FFT for both channels
#if USE_HIP
    gpu->forwardFFTBatch (fftBufferL.data(), fftBufferR.data(),
                          fftBufferL.data(), fftBufferR.data(), fftSize);
#endif

    // Extract spectra from both channels
    for (int bin = 0; bin < numBins; ++bin)
    {
        size_t b = static_cast<size_t> (bin);
        float realL = fftBufferL[b * 2];
        float imagL = fftBufferL[b * 2 + 1];
        float realR = fftBufferR[b * 2];
        float imagR = fftBufferR[b * 2 + 1];
        spectrumL[b] = std::complex<float> (realL, imagL);
        spectrumR[b] = std::complex<float> (realR, imagR);
    }
}

void GPUStemSeparator::processFFTFrame (int channel)
{
    int readPos = (inputWritePos - fftSize + fftSize) % fftSize;

    // Select the appropriate buffer for this channel
    auto& fftBuffer = (channel == 0) ? fftBufferL : fftBufferR;

    // Copy input with window
    for (int i = 0; i < fftSize; ++i)
    {
        int pos = (readPos + i) % fftSize;
        fftBuffer[static_cast<size_t> (i)] = inputBuffer[static_cast<size_t> (channel)][static_cast<size_t> (pos)] *
                                             window[static_cast<size_t> (i)];
    }

    // Forward FFT (CPU only - GPU uses batch mode)
    // Clear imaginary part for real FFT
    for (int i = 0; i < fftSize; ++i)
        fftBuffer[static_cast<size_t> (fftSize + i)] = 0.0f;
    fft.performRealOnlyForwardTransform (fftBuffer.data());

    // Extract spectrum
    auto& spectrum = (channel == 0) ? spectrumL : spectrumR;
    for (int bin = 0; bin < numBins; ++bin)
    {
        float real = fftBuffer[static_cast<size_t> (bin * 2)];
        float imag = fftBuffer[static_cast<size_t> (bin * 2 + 1)];
        spectrum[static_cast<size_t> (bin)] = std::complex<float> (real, imag);
    }
}

void GPUStemSeparator::separateStems()
{
    // Compute Mid/Side
    for (int bin = 0; bin < numBins; ++bin)
    {
        spectrumMid[static_cast<size_t> (bin)] = (spectrumL[static_cast<size_t> (bin)] + spectrumR[static_cast<size_t> (bin)]) * 0.5f;
        spectrumSide[static_cast<size_t> (bin)] = (spectrumL[static_cast<size_t> (bin)] - spectrumR[static_cast<size_t> (bin)]) * 0.5f;
    }

    int bassCutoffBin = freqToBin (bassCutoffHz);

    for (int bin = 0; bin < numBins; ++bin)
    {
        float freq = binToFreq (bin);
        float midMag = std::abs (spectrumMid[static_cast<size_t> (bin)]);
        float sideMag = std::abs (spectrumSide[static_cast<size_t> (bin)]);

        // Bass mask - low frequencies from mid channel
        float bassMask = 0.0f;
        if (bin < bassCutoffBin)
        {
            float rolloff = 1.0f - (float) bin / bassCutoffBin;
            bassMask = rolloff * rolloff;
        }
        else if (bin < bassCutoffBin * 2)
        {
            float t = (float) (bin - bassCutoffBin) / bassCutoffBin;
            bassMask = (1.0f - t) * 0.2f;
        }

        // Vocals mask - center channel in vocal frequency range
        float vocalsMask = 0.0f;
        if (freq > 100.0f && freq < 8000.0f)
        {
            float centerWeight = midMag / std::max (sideMag + midMag, 0.0001f);
            vocalsMask = centerWeight * vocalsFocus;
            if (freq > 300.0f && freq < 3500.0f)
                vocalsMask *= 1.3f;
            vocalsMask = std::min (vocalsMask, 1.0f);
        }

        // Drums mask - transient detection
        float currentMag = std::abs (spectrumL[static_cast<size_t> (bin)]) + std::abs (spectrumR[static_cast<size_t> (bin)]);
        float prevMag = prevMagnitude[static_cast<size_t> (bin)];
        float transientRatio = (currentMag - prevMag) / std::max (prevMag, 0.0001f);
        transientRatio = std::max (0.0f, transientRatio);

        float drumsMask = transientRatio * drumSensitivity;
        if ((freq > 50.0f && freq < 400.0f) || (freq > 4000.0f && freq < 12000.0f))
            drumsMask *= 1.2f;
        drumsMask = std::min (drumsMask, 1.0f);

        prevMagnitude[static_cast<size_t> (bin)] = currentMag * 0.3f + prevMag * 0.7f;

        // Normalize and compute Other
        float total = bassMask + vocalsMask + drumsMask;
        float otherMask = std::max (0.0f, 1.0f - total);

        if (total > 1.0f)
        {
            float scale = 1.0f / total;
            bassMask *= scale;
            vocalsMask *= scale;
            drumsMask *= scale;
            otherMask = 0.0f;
        }

        // Apply masks
        size_t b = static_cast<size_t> (bin);

        // Bass: mono from mid
        stemSpectraL[Bass][b] = spectrumMid[b] * bassMask;
        stemSpectraR[Bass][b] = stemSpectraL[Bass][b];

        // Vocals: from mid
        stemSpectraL[Vocals][b] = spectrumMid[b] * vocalsMask;
        stemSpectraR[Vocals][b] = stemSpectraL[Vocals][b];

        // Drums: from full mix
        stemSpectraL[Drums][b] = spectrumL[b] * drumsMask;
        stemSpectraR[Drums][b] = spectrumR[b] * drumsMask;

        // Other: remainder
        stemSpectraL[Other][b] = spectrumL[b] * otherMask;
        stemSpectraR[Other][b] = spectrumR[b] * otherMask;
    }
}

void GPUStemSeparator::synthesizeStems()
{
    int writePos = (outputReadPos - hopSize + fftSize) % fftSize;

    for (int stem = 0; stem < NumStems; ++stem)
    {
        for (int ch = 0; ch < 2; ++ch)
        {
            auto& spectrum = (ch == 0) ? stemSpectraL[static_cast<size_t> (stem)]
                                       : stemSpectraR[static_cast<size_t> (stem)];
            auto& fftBuffer = (ch == 0) ? fftBufferL : fftBufferR;

            // Pack spectrum into FFT buffer
            for (int bin = 0; bin < numBins; ++bin)
            {
                fftBuffer[static_cast<size_t> (bin * 2)] = spectrum[static_cast<size_t> (bin)].real();
                fftBuffer[static_cast<size_t> (bin * 2 + 1)] = spectrum[static_cast<size_t> (bin)].imag();
            }

            // Inverse FFT (GPU or CPU)
#if USE_HIP
            if (gpuAvailable)
            {
                gpu->inverseFFT (fftBuffer.data(), fftBuffer.data(), fftSize);
            }
            else
#endif
            {
                fft.performRealOnlyInverseTransform (fftBuffer.data());
            }

            // Overlap-add with window
            for (int i = 0; i < fftSize; ++i)
            {
                int pos = (writePos + i) % fftSize;
                outputBuffers[static_cast<size_t> (stem)][static_cast<size_t> (ch)][static_cast<size_t> (pos)] +=
                    fftBuffer[static_cast<size_t> (i)] * window[static_cast<size_t> (i)] / (fftSize * 0.375f);
            }
        }
    }
}
