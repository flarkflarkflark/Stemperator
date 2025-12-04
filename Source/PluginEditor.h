#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "GUI/StemMixer.h"

class StemperatorEditor : public juce::AudioProcessorEditor
{
public:
    explicit StemperatorEditor (StemperatorProcessor&);
    ~StemperatorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;

private:
    StemperatorProcessor& processor;
    StemMixer stemMixer;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorEditor)
};
