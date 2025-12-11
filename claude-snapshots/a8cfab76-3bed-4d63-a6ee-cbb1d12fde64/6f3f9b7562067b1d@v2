#pragma once

#include <JuceHeader.h>
#include <array>
#include <complex>
#include <deque>

/**
 * StemSeparator - Real-time spectral stem separation
 *
 * Uses multiple techniques for separation:
 * 1. Stereo Mid/Side for center (vocals) extraction
 * 2. Low-pass filtering for bass isolation
 * 3. TRUE HPSS (Harmonic-Percussive Source Separation) with median filtering
 * 4. Residual calculation for "other"
 *
 * HPSS works by:
 * - Buffering multiple spectrogram frames
 * - Median filtering along TIME axis → Harmonic (horizontal lines in spectrogram)
 * - Median filtering along FREQUENCY axis → Percussive (vertical lines in spectrogram)
 * - Using soft masks derived from these filtered spectrograms
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
    juce::String getGPUInfo() const { return "Preview: CPU | Export: GPU"; }

private:
    double sampleRate = 44100.0;
    int blockSize = 512;

    // FFT configuration
    static constexpr int fftOrder = 11;  // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    static constexpr int hopSize = fftSize / 4;  // 75% overlap
    static constexpr int numBins = fftSize / 2 + 1;

    // HPSS configuration - number of frames for median filtering
    static constexpr int hpssFrames = 17;  // Must be odd for median (17 frames ≈ 200ms at 44.1kHz)
    static constexpr int hpssCenter = hpssFrames / 2;  // Center frame index
    static constexpr int freqMedianSize = 17;  // Frequency bins for percussive median (must be odd)

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

    // HPSS spectrogram buffer - stores magnitude spectrograms for median filtering
    // Each frame is numBins magnitudes, we keep hpssFrames history
    std::deque<std::vector<float>> spectrogramHistory;  // Magnitude history for HPSS
    std::deque<std::vector<std::complex<float>>> spectrumHistoryL;  // Complex spectrum history L
    std::deque<std::vector<std::complex<float>>> spectrumHistoryR;  // Complex spectrum history R

    // Stem spectra
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraL;
    std::array<std::vector<std::complex<float>>, NumStems> stemSpectraR;

    // Output stems
    std::array<juce::AudioBuffer<float>, NumStems> stems;

    // Parameters
    float bassCutoffHz = 150.0f;
    float vocalsFocus = 0.5f;
    float drumSensitivity = 0.5f;

    // Internal processing
    void processFFTFrame (int channel);
    void separateStems();
    void reconstructStems (int channel);

    // HPSS helpers
    float medianOfVector (std::vector<float>& values);
    void computeHPSSMasks (std::vector<float>& harmonicMask, std::vector<float>& percussiveMask);

    // Frequency helpers
    int freqToBin (float freq) const { return (int) (freq * fftSize / sampleRate); }
    float binToFreq (int bin) const { return (float) bin * (float) sampleRate / (float) fftSize; }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemSeparator)
};
