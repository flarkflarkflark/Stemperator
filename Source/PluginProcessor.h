#pragma once

#include <JuceHeader.h>
#include "AI/DemucsProcessor.h"

// Use GPU-accelerated separator when available
#if USE_HIP || USE_OPENCL
    #include "GPU/GPUStemSeparator.h"
    using StemSeparatorImpl = GPUStemSeparator;
#else
    #include "DSP/StemSeparator.h"
    using StemSeparatorImpl = StemSeparator;
#endif

/**
 * Stemperator - AI-Powered Stem Separation Plugin
 *
 * Multi-output VST3 plugin that separates audio into 4-6 stems:
 * - Vocals (center channel extraction + harmonic analysis)
 * - Drums (transient detection + spectral percussion)
 * - Bass (low frequency isolation)
 * - Other (residual - everything else)
 * - Guitar (6-stem model only)
 * - Piano (6-stem model only)
 *
 * Each stem is output on a separate stereo bus for flexible DAW routing.
 */
class StemperatorProcessor : public juce::AudioProcessor,
                              public juce::AudioProcessorValueTreeState::Listener
{
public:
    StemperatorProcessor();
    ~StemperatorProcessor() override;

    //==============================================================================
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==============================================================================
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    //==============================================================================
    const juce::String getName() const override { return JucePlugin_Name; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.5; }

    //==============================================================================
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int) override {}
    const juce::String getProgramName (int) override { return {}; }
    void changeProgramName (int, const juce::String&) override {}

    //==============================================================================
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==============================================================================
    void parameterChanged (const juce::String& parameterID, float newValue) override;

    //==============================================================================
    // Stem enumeration - supports up to 6 stems (htdemucs_6s model)
    static constexpr int MaxStems = 6;
    static constexpr int NumStems4 = 4;  // Standard 4-stem models
    static constexpr int NumStems6 = 6;  // 6-stem model (htdemucs_6s)
    enum Stem { Vocals = 0, Drums, Bass, Other, Guitar, Piano };
    static constexpr const char* stemNames[MaxStems] = { "Vocals", "Drums", "Bass", "Other", "Guitar", "Piano" };

    // Get number of active stems based on current model
    int getNumStems() const { return demucsProcessor.is6StemModel() ? NumStems6 : NumStems4; }
    bool is6StemModel() const { return demucsProcessor.is6StemModel(); }

    // Get stem levels for visualization
    float getStemLevel (Stem stem) const { return stemLevels[stem].load(); }

    // Get input level for visualization
    float getInputLevel() const { return inputLevel.load(); }

    // Parameter tree
    juce::AudioProcessorValueTreeState& getParameters() { return parameters; }

    // Separator access for advanced features
    StemSeparatorImpl& getSeparator() { return separator; }

    // GPU status (only available with GPU build)
    bool isUsingGPU() const { return separator.isUsingGPU(); }
    juce::String getGPUInfo() const { return separator.getGPUInfo(); }

    // AI/Demucs status
    bool isDemucsAvailable() const { return demucsProcessor.isAvailable(); }
    juce::String getDemucsStatus() const { return demucsProcessor.getStatusMessage(); }
    DemucsProcessor& getDemucsProcessor() { return demucsProcessor; }

    // Standalone playback support - set an audio source to play through processor
    void setPlaybackSource (juce::AudioSource* source);
    juce::AudioSource* getPlaybackSource() const { return playbackSource; }

    // Skip spectral separation (when playing pre-separated stems)
    void setSkipSeparation (bool skip) { skipSeparation = skip; }
    bool getSkipSeparation() const { return skipSeparation; }

private:
    //==============================================================================
    juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

    juce::AudioProcessorValueTreeState parameters;
    StemSeparatorImpl separator;
    DemucsProcessor demucsProcessor;

    // Atomic levels for thread-safe GUI updates
    std::array<std::atomic<float>, MaxStems> stemLevels;
    std::atomic<float> inputLevel { 0.0f };

    // Smoothed parameters
    juce::LinearSmoothedValue<float> stemGains[MaxStems];
    juce::LinearSmoothedValue<float> masterGain;

    // Processing state
    double currentSampleRate = 44100.0;
    int currentBlockSize = 512;

    // Standalone playback source (set by editor)
    juce::AudioSource* playbackSource = nullptr;
    juce::AudioBuffer<float> playbackBuffer;
    bool skipSeparation = false;  // Skip GPU processing when playing pre-separated stems

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorProcessor)
};
