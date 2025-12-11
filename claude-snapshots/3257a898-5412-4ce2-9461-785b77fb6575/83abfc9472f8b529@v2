#pragma once

#include <JuceHeader.h>
#include "../PluginProcessor.h"

class StemMixer : public juce::Component,
                  public juce::Slider::Listener,
                  public juce::Button::Listener
{
public:
    explicit StemMixer (StemperatorProcessor& p);
    ~StemMixer() override;

    void paint (juce::Graphics&) override;
    void resized() override;

    void sliderValueChanged (juce::Slider* slider) override;
    void buttonClicked (juce::Button* button) override;

private:
    StemperatorProcessor& processor;

    struct StemChannel
    {
        juce::Slider fader;
        juce::TextButton muteButton { "M" };
        juce::TextButton soloButton { "S" };
        juce::Label nameLabel;
        juce::Colour colour;
    };

    std::array<StemChannel, 4> channels;
    const std::array<juce::String, 4> stemNames = { "Vocals", "Drums", "Bass", "Other" };
    const std::array<juce::Colour, 4> stemColours = {
        juce::Colour (0xffe74c3c),  // Red - Vocals
        juce::Colour (0xff3498db),  // Blue - Drums
        juce::Colour (0xff2ecc71),  // Green - Bass
        juce::Colour (0xfff39c12)   // Orange - Other
    };

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemMixer)
};
