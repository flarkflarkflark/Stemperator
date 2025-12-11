#pragma once

#include <JuceHeader.h>

/**
 * StemChannel - Premium channel strip for individual stem control
 *
 * Features:
 * - Smooth gradient fader with glow effect
 * - Animated VU meter with peak hold
 * - Modern mute/solo buttons with active glow
 * - Clean typography and spacing
 */
class StemChannel : public juce::Component,
                    public juce::Button::Listener,
                    public juce::Timer
{
public:
    StemChannel (const juce::String& name, juce::Colour colour);

    void paint (juce::Graphics&) override;
    void resized() override;
    void buttonClicked (juce::Button* button) override;
    void timerCallback() override { repaint(); }

    // Parameter attachment
    void attachToParameters (juce::AudioProcessorValueTreeState& apvts,
                             const juce::String& gainID,
                             const juce::String& muteID,
                             const juce::String& soloID);

    // Level meter
    void setLevel (float level);

    // Callbacks
    std::function<void (bool)> onMuteChanged;
    std::function<void (bool)> onSoloChanged;

private:
    juce::String stemName;
    juce::Colour stemColour;

    // Controls
    juce::Slider gainSlider;
    juce::TextButton muteButton { "M" };
    juce::TextButton soloButton { "S" };
    juce::Label nameLabel;

    // Attachments
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> gainAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> muteAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::ButtonAttachment> soloAttachment;

    // Metering with peak hold
    float currentLevel = 0.0f;
    float displayLevel = 0.0f;
    float peakLevel = 0.0f;
    int peakHoldCount = 0;
    static constexpr int peakHoldTime = 30;  // ~1 second at 30fps

    void updateMeter();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemChannel)
};
