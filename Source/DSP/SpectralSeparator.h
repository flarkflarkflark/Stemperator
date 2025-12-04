#pragma once

#include <JuceHeader.h>

/**
 * SpectralSeparator - FFT-based stem separation (fallback/preview mode)
 *
 * Fast but lower quality than AI-based separation.
 * Used for real-time preview when Demucs is not available.
 */
class SpectralSeparator
{
public:
    SpectralSeparator();

    void prepare (double sampleRate, int blockSize);
    void process (const juce::AudioBuffer<float>& input,
                  juce::AudioBuffer<float>& vocals,
                  juce::AudioBuffer<float>& drums,
                  juce::AudioBuffer<float>& bass,
                  juce::AudioBuffer<float>& other);

private:
    double sampleRate = 44100.0;
    static constexpr int fftOrder = 11;
    static constexpr int fftSize = 1 << fftOrder;

    juce::dsp::FFT fft { fftOrder };
    juce::dsp::WindowingFunction<float> window { fftSize, juce::dsp::WindowingFunction<float>::hann };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectralSeparator)
};
