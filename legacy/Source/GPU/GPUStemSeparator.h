#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <complex>
#include <atomic>

/**
 * GPUStemSeparator - GPU-accelerated stem separation
 *
 * Uses rocFFT for GPU-accelerated FFT operations on AMD GPUs.
 * Spectral processing is done on CPU for now (will be optimized later).
 * Falls back to CPU FFT if GPU is not available.
 *
 * Performance improvement: ~3-5x faster FFT with GPU
 */
class GPUStemSeparator
{
public:
    static constexpr int NumStems = 4;
    enum Stem { Vocals = 0, Drums, Bass, Other };

    GPUStemSeparator();
    ~GPUStemSeparator();

    // Prepare for processing
    void prepare (double sampleRate, int maxBlockSize);
    void reset();

    // Main processing - returns separated stems
    void process (juce::AudioBuffer<float>& buffer);

    // Get separated stem buffers
    std::array<juce::AudioBuffer<float>, NumStems>& getStems() { return stems; }

    // Parameters
    void setBassCutoff (float hz) { bassCutoffHz = hz; }
    void setVocalsFocus (float focus) { vocalsFocus = focus; }
    void setDrumSensitivity (float sens) { drumSensitivity = sens; }

    // GPU status
    bool isUsingGPU() const { return gpuAvailable; }
    juce::String getGPUInfo() const { return gpuInfo; }

private:
    // FFT configuration
    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    static constexpr int hopSize = fftSize / 4;  // 75% overlap
    static constexpr int numBins = fftSize / 2 + 1;

    double currentSampleRate = 44100.0;
    std::array<juce::AudioBuffer<float>, NumStems> stems;

    // Parameters
    float bassCutoffHz = 150.0f;
    float vocalsFocus = 0.5f;
    float drumSensitivity = 0.5f;

    // GPU state
    bool gpuAvailable = false;
    juce::String gpuInfo;

    // GPU implementation (opaque pointer for HIP types)
    struct GPUImpl;
    std::unique_ptr<GPUImpl> gpu;

    // CPU fallback using JUCE FFT
    juce::dsp::FFT fft { fftOrder };
    std::vector<float> fftBufferL;  // Left channel FFT buffer
    std::vector<float> fftBufferR;  // Right channel FFT buffer
    std::vector<std::complex<float>> spectrumL, spectrumR;
    std::vector<std::complex<float>> spectrumMid, spectrumSide;
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraL;
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraR;

    // Previous magnitude for transient detection
    std::vector<float> prevMagnitude;

    // Overlap-add buffers
    std::array<std::vector<float>, 2> inputBuffer;
    std::array<std::array<std::vector<float>, 2>, NumStems> outputBuffers;
    std::vector<float> window;
    int inputWritePos = 0;
    int outputReadPos = 0;
    int samplesUntilNextFFT = hopSize;

    // Processing methods
    void processFrame();
    void processFFTFrameBatch();  // Process both channels together (GPU optimized)
    void processFFTFrame (int channel);  // Process single channel (CPU fallback)
    void separateStems();
    void synthesizeStems();

    // Helper functions
    float binToFreq (int bin) const { return (float) bin * (float) currentSampleRate / (float) fftSize; }
    int freqToBin (float freq) const { return (int) (freq * fftSize / currentSampleRate); }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (GPUStemSeparator)
};
