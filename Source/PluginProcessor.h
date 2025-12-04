#pragma once

#include <JuceHeader.h>
#include "DSP/StemSeparator.h"

class StemperatorProcessor : public juce::AudioProcessor
{
public:
    StemperatorProcessor();
    ~StemperatorProcessor() override;

    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    const juce::String getName() const override { return JucePlugin_Name; }

    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int) override {}
    const juce::String getProgramName (int) override { return {}; }
    void changeProgramName (int, const juce::String&) override {}

    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    // Stem access
    enum Stem { Vocals = 0, Drums, Bass, Other, NumStems };

    float getStemLevel (Stem stem) const { return stemLevels[stem]; }
    void setStemLevel (Stem stem, float level) { stemLevels[stem] = level; }

    bool getStemMute (Stem stem) const { return stemMutes[stem]; }
    void setStemMute (Stem stem, bool mute) { stemMutes[stem] = mute; }

    bool getStemSolo (Stem stem) const { return stemSolos[stem]; }
    void setStemSolo (Stem stem, bool solo) { stemSolos[stem] = solo; }

    StemSeparator& getSeparator() { return separator; }

private:
    StemSeparator separator;

    std::array<float, NumStems> stemLevels = { 1.0f, 1.0f, 1.0f, 1.0f };
    std::array<bool, NumStems> stemMutes = { false, false, false, false };
    std::array<bool, NumStems> stemSolos = { false, false, false, false };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorProcessor)
};
