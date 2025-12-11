#pragma once

#include <JuceHeader.h>
#include <array>
#include <functional>

/**
 * DemucsProcessor - AI-powered stem separation using Meta's Demucs
 *
 * This class provides offline (non-realtime) stem separation using the
 * Demucs deep learning model. For real-time use, the plugin uses GPU-accelerated
 * spectral separation; this class is for "Best Quality" mode.
 *
 * Requirements:
 * - Python 3 with PyTorch and Demucs installed
 * - For GPU: PyTorch with ROCm (AMD) or CUDA (NVIDIA)
 *
 * Architecture:
 * - Audio is written to a temp WAV file
 * - Python script runs Demucs model
 * - Separated stems are read back
 * - ~10-30 seconds processing time per song (GPU) or 2-5 minutes (CPU)
 */
class DemucsProcessor
{
public:
    // Maximum stems supported (6-stem model has the most)
    static constexpr int MaxStems = 6;
    static constexpr int NumStems4 = 4;  // Standard 4-stem models
    static constexpr int NumStems6 = 6;  // 6-stem model (htdemucs_6s)

    // Stem indices - first 4 are always the same
    enum Stem { Vocals = 0, Drums, Bass, Other, Guitar, Piano };
    static constexpr const char* StemNames[MaxStems] = { "vocals", "drums", "bass", "other", "guitar", "piano" };

    // Available Demucs models
    enum Model
    {
        HTDemucs,       // Default hybrid transformer (best quality/speed balance)
        HTDemucs_FT,    // Fine-tuned version (slightly better quality)
        HTDemucs_6S,    // 6-stem version (adds piano, guitar)
        MDX_Extra,      // MDX competition winner
        MDX_Extra_Q     // Quantized MDX (faster, slightly lower quality)
    };

    DemucsProcessor();
    ~DemucsProcessor();

    /**
     * Check if Demucs is available (Python + dependencies installed)
     */
    bool isAvailable() const { return demucsAvailable; }

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
     * Set the model to use
     */
    void setModel (Model model) { currentModel = model; }
    Model getModel() const { return currentModel; }

    /**
     * Get number of stems for the current model (4 or 6)
     */
    int getNumStems() const { return currentModel == HTDemucs_6S ? NumStems6 : NumStems4; }

    /**
     * Check if current model is 6-stem
     */
    bool is6StemModel() const { return currentModel == HTDemucs_6S; }

    /**
     * Process an audio buffer through Demucs (blocking, can take seconds to minutes)
     *
     * @param inputBuffer Stereo input audio
     * @param sampleRate Sample rate of the input
     * @param progressCallback Called periodically with progress 0.0-1.0
     * @return true if successful
     */
    bool process (const juce::AudioBuffer<float>& inputBuffer,
                  double sampleRate,
                  std::function<void (float)> progressCallback = nullptr);

    /**
     * Process an audio file through Demucs (blocking)
     *
     * @param inputFile Path to input audio file
     * @param outputDir Directory to write output stems
     * @param progressCallback Called periodically with progress 0.0-1.0
     * @return true if successful
     */
    bool processFile (const juce::File& inputFile,
                      const juce::File& outputDir,
                      std::function<void (float)> progressCallback = nullptr);

    /**
     * Get the separated stems after processing
     * Only valid after a successful process() call
     * Array has MaxStems elements, but only getNumStems() are valid
     */
    std::array<juce::AudioBuffer<float>, MaxStems>& getStems() { return stems; }

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

private:
    bool demucsAvailable = false;
    bool gpuAvailable = false;
    juce::String statusMessage;
    juce::String gpuName;
    juce::String pythonPath;
    juce::File scriptPath;

    Model currentModel = HTDemucs;

    std::array<juce::AudioBuffer<float>, MaxStems> stems;
    double stemSampleRate = 44100.0;

    std::atomic<bool> shouldCancel { false };
    std::atomic<bool> processing { false };

    // Find Python and check dependencies
    void checkAvailability();

    // Get model name string
    juce::String getModelName() const;

    // Run the Python script
    bool runDemucs (const juce::File& inputFile, const juce::File& outputDir,
                    std::function<void (float)> progressCallback);

    // Load stems from output directory
    bool loadStems (const juce::File& outputDir);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DemucsProcessor)
};
