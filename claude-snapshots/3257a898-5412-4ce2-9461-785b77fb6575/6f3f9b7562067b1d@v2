#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * StemSeparator - AI-based audio stem separation
 *
 * Separates audio into 4 stems: Vocals, Drums, Bass, Other
 *
 * Modes:
 * - Real-time: Fast spectral separation (FFT-based)
 * - Offline: High-quality AI separation (Demucs/Spleeter via GPU)
 *
 * GPU acceleration via OpenCL/CUDA/HIP for faster processing.
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

    /** Real-time spectral separation */
    void process (juce::AudioBuffer<float>& buffer);

    /** Get separated stems (updated after process()) */
    std::array<juce::AudioBuffer<float>, NumStems>& getStems() { return stems; }

    /** Status */
    bool isProcessing() const { return processing.load(); }
    float getProgress() const { return progress.load(); }
    juce::String getStatusMessage() const { return statusMessage; }

    /** GPU info */
    bool isUsingGPU() const { return gpuAvailable; }
    juce::String getGPUInfo() const { return gpuInfo; }

private:
    double sampleRate = 44100.0;
    int blockSize = 512;

    std::array<juce::AudioBuffer<float>, NumStems> stems;

    // FFT for spectral separation
    static constexpr int fftOrder = 11; // 2048 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT fft { fftOrder };
    juce::dsp::WindowingFunction<float> window { fftSize, juce::dsp::WindowingFunction<float>::hann };

    std::vector<float> fftData;
    std::vector<float> inputBuffer;
    int inputBufferPos = 0;

    // Status
    std::atomic<bool> processing { false };
    std::atomic<float> progress { 0.0f };
    juce::String statusMessage = "Ready";

    // GPU
    bool gpuAvailable = false;
    juce::String gpuInfo = "CPU only";

    void initGPU();
    void processSpectralSeparation (const float* input, int numSamples);
    void extractVocals (const std::vector<std::complex<float>>& spectrum, std::vector<std::complex<float>>& vocals);
    void extractBass (const std::vector<std::complex<float>>& spectrum, std::vector<std::complex<float>>& bass);
    void extractDrums (const std::vector<std::complex<float>>& spectrum, std::vector<std::complex<float>>& drums);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemSeparator)
};
