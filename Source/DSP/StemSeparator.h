#pragma once

#include <JuceHeader.h>
#include <array>
#include <complex>

/**
 * StemSeparator - Real-time spectral stem separation
 *
 * Uses multiple techniques for separation:
 * 1. Stereo Mid/Side for center (vocals) extraction
 * 2. Low-pass filtering for bass isolation
 * 3. Transient/Steady-state decomposition for drums
 * 4. Harmonic/Percussive separation (HPSS)
 * 5. Residual calculation for "other"
 *
 * All processing happens in the frequency domain using overlap-add FFT.
 */
class StemSeparator
{
public:
    static constexpr int NumStems = 4;
    enum Stem { Vocals = 0, Drums, Bass, Other };

    StemSeparator();
    ~StemSeparator();

    void prepare (double sampleRate, int samplesPerBlock);
    void reset();

    /** Main processing function */
    void process (juce::AudioBuffer<float>& buffer);

    /** Get separated stems */
    std::array<juce::AudioBuffer<float>, NumStems>& getStems() { return stems; }

    /** Adjustable parameters */
    void setBassCutoff (float hz) { bassCutoffHz = hz; }
    void setVocalsFocus (float focus) { vocalsFocus = juce::jlimit (0.0f, 1.0f, focus); }
    void setDrumSensitivity (float sens) { drumSensitivity = juce::jlimit (0.0f, 1.0f, sens); }

    /** GPU status (CPU version always returns false) */
    bool isUsingGPU() const { return false; }
    juce::String getGPUInfo() const { return "CPU Processing"; }

private:
    double sampleRate = 44100.0;
    int blockSize = 512;

    // FFT configuration
    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    static constexpr int hopSize = fftSize / 4;  // 75% overlap
    static constexpr int numBins = fftSize / 2 + 1;

    juce::dsp::FFT fft { fftOrder };
    juce::dsp::WindowingFunction<float> window { fftSize, juce::dsp::WindowingFunction<float>::hann };

    // Circular buffers for overlap-add
    std::array<std::vector<float>, 2> inputBuffer;    // L/R input circular buffer
    std::array<std::vector<float>, 2> outputBuffers[NumStems];  // L/R output for each stem
    int inputWritePos = 0;
    int outputReadPos = 0;

    // FFT working buffers
    std::vector<float> fftBuffer;
    std::vector<std::complex<float>> spectrumL, spectrumR;
    std::vector<std::complex<float>> spectrumMid, spectrumSide;

    // Stem spectra
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraL;
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraR;

    // Output stems
    std::array<juce::AudioBuffer<float>, NumStems> stems;

    // Parameters
    float bassCutoffHz = 150.0f;
    float vocalsFocus = 0.5f;
    float drumSensitivity = 0.5f;

    // Previous frame for transient detection
    std::vector<float> prevMagnitude;

    // Internal processing
    void processFFTFrame (int channel);
    void separateStems();
    void reconstructStems (int channel);

    // Frequency helpers
    int freqToBin (float freq) const { return (int) (freq * fftSize / sampleRate); }
    float binToFreq (int bin) const { return (float) bin * (float) sampleRate / (float) fftSize; }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemSeparator)
};
