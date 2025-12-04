#pragma once

#include <JuceHeader.h>

class WaveformView : public juce::Component
{
public:
    WaveformView();

    void setBuffer (const juce::AudioBuffer<float>* buffer);
    void setColour (juce::Colour c) { colour = c; repaint(); }

    void paint (juce::Graphics&) override;

private:
    const juce::AudioBuffer<float>* audioBuffer = nullptr;
    juce::Colour colour = juce::Colours::cyan;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (WaveformView)
};
