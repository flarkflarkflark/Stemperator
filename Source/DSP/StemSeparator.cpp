#include "StemSeparator.h"
#include <complex>

StemSeparator::StemSeparator()
{
    fftData.resize (fftSize * 2);
    inputBuffer.resize (fftSize);
    initGPU();
}

StemSeparator::~StemSeparator() = default;

void StemSeparator::initGPU()
{
    // TODO: Initialize GPU backend (OpenCL/CUDA/HIP)
    // For now, use CPU
    gpuAvailable = false;
    gpuInfo = "CPU (GPU support coming soon)";
}

void StemSeparator::prepare (double sr, int blockSz)
{
    sampleRate = sr;
    blockSize = blockSz;

    for (auto& stem : stems)
        stem.setSize (2, blockSz);

    inputBufferPos = 0;
    std::fill (inputBuffer.begin(), inputBuffer.end(), 0.0f);
}

void StemSeparator::reset()
{
    inputBufferPos = 0;
    std::fill (inputBuffer.begin(), inputBuffer.end(), 0.0f);

    for (auto& stem : stems)
        stem.clear();
}

void StemSeparator::process (juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    // Ensure stems are sized correctly
    for (auto& stem : stems)
    {
        if (stem.getNumSamples() != numSamples)
            stem.setSize (2, numSamples, false, false, true);
    }

    // For now: simple spectral separation
    // Mix to mono for analysis
    std::vector<float> mono (numSamples);
    for (int i = 0; i < numSamples; ++i)
    {
        mono[i] = (buffer.getSample (0, i) + buffer.getSample (1, i)) * 0.5f;
    }

    processSpectralSeparation (mono.data(), numSamples);

    // Copy original to "Other" as fallback
    for (int ch = 0; ch < 2; ++ch)
    {
        // Vocals: center channel extraction (L-R for stereo)
        // This is a simple approach - real Demucs would be much better
        if (buffer.getNumChannels() >= 2)
        {
            for (int i = 0; i < numSamples; ++i)
            {
                float L = buffer.getSample (0, i);
                float R = buffer.getSample (1, i);
                float mid = (L + R) * 0.5f;
                float side = (L - R) * 0.5f;

                // Vocals tend to be in the center (mid)
                stems[Vocals].setSample (ch, i, mid * 0.7f);

                // Side contains more instruments
                stems[Other].setSample (ch, i, side + mid * 0.3f);
            }
        }

        // Bass: low-pass filter < 200Hz
        // Simple first-order IIR
        float bassCoeff = std::exp (-2.0f * juce::MathConstants<float>::pi * 200.0f / (float) sampleRate);
        float bassState = 0.0f;
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = buffer.getSample (ch, i);
            bassState = bassCoeff * bassState + (1.0f - bassCoeff) * sample;
            stems[Bass].setSample (ch, i, bassState);
        }

        // Drums: transient detection (high-pass + envelope follower)
        float hpCoeff = std::exp (-2.0f * juce::MathConstants<float>::pi * 100.0f / (float) sampleRate);
        float hpState = 0.0f;
        float envState = 0.0f;
        float envAttack = 0.01f;
        float envRelease = 0.1f;

        for (int i = 0; i < numSamples; ++i)
        {
            float sample = buffer.getSample (ch, i);
            float hp = sample - hpState;
            hpState = hpCoeff * hpState + (1.0f - hpCoeff) * sample;

            // Envelope follower
            float absHp = std::abs (hp);
            if (absHp > envState)
                envState = envAttack * absHp + (1.0f - envAttack) * envState;
            else
                envState = envRelease * absHp + (1.0f - envRelease) * envState;

            // Gate based on envelope
            float drumGate = envState > 0.1f ? 1.0f : envState * 10.0f;
            stems[Drums].setSample (ch, i, hp * drumGate);
        }
    }
}

void StemSeparator::processSpectralSeparation (const float* input, int numSamples)
{
    // Accumulate input for FFT processing
    for (int i = 0; i < numSamples; ++i)
    {
        inputBuffer[inputBufferPos++] = input[i];

        if (inputBufferPos >= fftSize)
        {
            // Apply window and FFT
            std::copy (inputBuffer.begin(), inputBuffer.end(), fftData.begin());
            window.multiplyWithWindowingTable (fftData.data(), fftSize);
            fft.performRealOnlyForwardTransform (fftData.data());

            // TODO: GPU-accelerated spectral masking for better separation
            // This would use the GPU kernels from VinylRestorationSuite

            // Shift buffer
            std::copy (inputBuffer.begin() + fftSize / 2, inputBuffer.end(), inputBuffer.begin());
            inputBufferPos = fftSize / 2;
        }
    }
}

void StemSeparator::extractVocals (const std::vector<std::complex<float>>& spectrum,
                                   std::vector<std::complex<float>>& vocals)
{
    // Vocals are typically 300Hz - 3kHz with harmonic structure
    int lowBin = (int) (300.0 * fftSize / sampleRate);
    int highBin = (int) (3000.0 * fftSize / sampleRate);

    vocals.resize (spectrum.size());
    for (size_t i = 0; i < spectrum.size(); ++i)
    {
        if (i >= (size_t) lowBin && i <= (size_t) highBin)
            vocals[i] = spectrum[i] * 0.8f;  // Soft mask
        else
            vocals[i] = spectrum[i] * 0.1f;
    }
}

void StemSeparator::extractBass (const std::vector<std::complex<float>>& spectrum,
                                 std::vector<std::complex<float>>& bass)
{
    // Bass is < 200Hz
    int cutoffBin = (int) (200.0 * fftSize / sampleRate);

    bass.resize (spectrum.size());
    for (size_t i = 0; i < spectrum.size(); ++i)
    {
        if (i <= (size_t) cutoffBin)
            bass[i] = spectrum[i];
        else
            bass[i] = spectrum[i] * 0.05f;
    }
}

void StemSeparator::extractDrums (const std::vector<std::complex<float>>& spectrum,
                                  std::vector<std::complex<float>>& drums)
{
    // Drums have broadband transients - use onset detection
    // This is a placeholder - real implementation needs temporal analysis
    drums.resize (spectrum.size());
    for (size_t i = 0; i < spectrum.size(); ++i)
    {
        drums[i] = spectrum[i] * 0.3f;
    }
}
