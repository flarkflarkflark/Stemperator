#pragma once

#include <JuceHeader.h>
#include <array>
#include <functional>

/**
 * UVRProcessor - AI-powered stem separation using Ultimate Vocal Remover
 *
 * Integrates with UVR (https://ultimatevocalremover.com/) for high-quality
 * stem separation. UVR supports multiple model architectures:
 * - MDX-Net: Fast and high quality vocal separation
 * - VR Architecture: Original UVR models
 * - Demucs: Facebook's hybrid transformer (also available standalone)
 *
 * Requirements:
 * - Python 3.10+ with UVR installed (audio-separator package or full UVR)
 * - For GPU: PyTorch with CUDA, ROCm, or DirectML
 *
 * Architecture:
 * - Uses the 'audio-separator' Python package (lightweight UVR wrapper)
 * - Falls back to full UVR installation if available
 * - Processes audio files via subprocess
 */
class UVRProcessor
{
public:
    static constexpr int NumStems = 4;
    enum Stem { Vocals = 0, Drums, Bass, Other };
    static constexpr const char* StemNames[NumStems] = { "vocals", "drums", "bass", "other" };

    // Available model architectures
    enum Architecture
    {
        MDX_Net,        // Fast, excellent vocal separation
        VR_Arch,        // Original UVR architecture
        Demucs,         // Hybrid transformer (best quality)
        MDX23C          // Latest competition winner
    };

    // Predefined model presets (popular combinations)
    enum ModelPreset
    {
        // Vocal separation
        Vocals_MDX_Kim2,        // Kim Vocal 2 - popular for clean vocals
        Vocals_MDX_Inst_HQ3,    // Instumental HQ3 - clean instrumentals
        Vocals_VR_5HP_Karaoke,  // 5HP Karaoke - good all-round

        // Full stem separation (4 stems)
        Stems_HTDemucs,         // HTDemucs - balanced quality/speed
        Stems_HTDemucs_FT,      // Fine-tuned HTDemucs
        Stems_MDX23C_8KFFT,     // MDX23C - competition quality

        // Special purpose
        Denoise_MDX_DeNoise,    // Audio denoising
        Dereverb_MDX_DeReverb,  // Reverb removal

        Custom                   // User-specified model
    };

    UVRProcessor();
    ~UVRProcessor();

    /**
     * Check if UVR/audio-separator is available
     */
    bool isAvailable() const { return uvrAvailable; }

    /**
     * Get status message (available GPU, model info, or error)
     */
    juce::String getStatusMessage() const { return statusMessage; }

    /**
     * Check if GPU acceleration is available
     */
    bool hasGPU() const { return gpuAvailable; }

    /**
     * Get GPU name if available
     */
    juce::String getGPUName() const { return gpuName; }

    /**
     * Set the model preset to use
     */
    void setModelPreset (ModelPreset preset) { currentPreset = preset; }
    ModelPreset getModelPreset() const { return currentPreset; }

    /**
     * Set a custom model name (for ModelPreset::Custom)
     */
    void setCustomModel (const juce::String& model) { customModelName = model; }

    /**
     * Get list of available models (queries UVR)
     */
    juce::StringArray getAvailableModels() const { return availableModels; }

    /**
     * Process an audio buffer (blocking, can take seconds to minutes)
     *
     * @param inputBuffer Stereo input audio
     * @param sampleRate Sample rate of the input
     * @param progressCallback Called periodically with progress 0.0-1.0
     * @param completionCallback Called when done with success status and error message
     * @return true if processing started successfully
     */
    bool process (const juce::AudioBuffer<float>& inputBuffer,
                  double sampleRate,
                  std::function<void (float)> progressCallback = nullptr,
                  std::function<void (bool, const juce::String&)> completionCallback = nullptr);

    /**
     * Process an audio file (blocking)
     *
     * @param inputFile Path to input audio file
     * @param outputDir Directory to write output stems
     * @param progressCallback Called periodically with progress 0.0-1.0
     * @param completionCallback Called when done with success status and error message
     * @return true if processing started successfully
     */
    bool processFile (const juce::File& inputFile,
                      const juce::File& outputDir,
                      std::function<void (float)> progressCallback = nullptr,
                      std::function<void (bool, const juce::String&)> completionCallback = nullptr);

    /**
     * Get the separated stems after processing
     * Only valid after a successful process() call
     */
    std::array<juce::AudioBuffer<float>, NumStems>& getStems() { return stems; }

    /**
     * Get the sample rate of the stems
     */
    double getStemSampleRate() const { return stemSampleRate; }

    /**
     * Cancel ongoing processing (thread-safe)
     */
    void cancel() { shouldCancel.store (true); }

    /**
     * Check if processing is in progress
     */
    bool isProcessing() const { return processing.load(); }

    /**
     * Get the installation command for audio-separator
     */
    static juce::String getInstallCommand()
    {
        return "pip install audio-separator[gpu]";  // or [cpu] for CPU-only
    }

private:
    bool uvrAvailable = false;
    bool gpuAvailable = false;
    bool useAudioSeparator = false;  // true = audio-separator package, false = full UVR
    juce::String statusMessage;
    juce::String gpuName;
    juce::String pythonPath;
    juce::File uvrPath;  // Path to UVR or audio-separator

    ModelPreset currentPreset = Stems_HTDemucs;
    juce::String customModelName;
    juce::StringArray availableModels;

    std::array<juce::AudioBuffer<float>, NumStems> stems;
    double stemSampleRate = 44100.0;

    std::atomic<bool> shouldCancel { false };
    std::atomic<bool> processing { false };

    // Find Python and check dependencies
    void checkAvailability();

    // Query available models from UVR
    void queryAvailableModels();

    // Get model name for current preset
    juce::String getModelName() const;

    // Get the command line for separation
    juce::String buildCommand (const juce::File& inputFile, const juce::File& outputDir) const;

    // Run the separation
    bool runSeparation (const juce::File& inputFile, const juce::File& outputDir,
                        std::function<void (float)> progressCallback);

    // Load stems from output directory
    bool loadStems (const juce::File& outputDir);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (UVRProcessor)
};
