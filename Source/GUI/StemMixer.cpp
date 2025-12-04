#include "StemMixer.h"

StemMixer::StemMixer (StemperatorProcessor& p) : processor (p)
{
    for (int i = 0; i < 4; ++i)
    {
        auto& ch = channels[i];

        ch.fader.setSliderStyle (juce::Slider::LinearVertical);
        ch.fader.setRange (0.0, 1.0, 0.01);
        ch.fader.setValue (1.0);
        ch.fader.setTextBoxStyle (juce::Slider::TextBoxBelow, false, 50, 20);
        ch.fader.addListener (this);
        ch.fader.setColour (juce::Slider::thumbColourId, stemColours[i]);
        addAndMakeVisible (ch.fader);

        ch.muteButton.setClickingTogglesState (true);
        ch.muteButton.addListener (this);
        ch.muteButton.setColour (juce::TextButton::buttonOnColourId, juce::Colours::red);
        addAndMakeVisible (ch.muteButton);

        ch.soloButton.setClickingTogglesState (true);
        ch.soloButton.addListener (this);
        ch.soloButton.setColour (juce::TextButton::buttonOnColourId, juce::Colours::yellow);
        addAndMakeVisible (ch.soloButton);

        ch.nameLabel.setText (stemNames[i], juce::dontSendNotification);
        ch.nameLabel.setJustificationType (juce::Justification::centred);
        ch.nameLabel.setColour (juce::Label::textColourId, stemColours[i]);
        addAndMakeVisible (ch.nameLabel);

        ch.colour = stemColours[i];
    }
}

StemMixer::~StemMixer() = default;

void StemMixer::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff16213e));

    // Draw channel backgrounds
    int channelWidth = getWidth() / 4;
    for (int i = 0; i < 4; ++i)
    {
        auto bounds = juce::Rectangle<int> (i * channelWidth, 0, channelWidth, getHeight());
        g.setColour (stemColours[i].withAlpha (0.1f));
        g.fillRect (bounds.reduced (2));

        g.setColour (stemColours[i].withAlpha (0.3f));
        g.drawRect (bounds.reduced (2), 1);
    }
}

void StemMixer::resized()
{
    int channelWidth = getWidth() / 4;
    int padding = 10;

    for (int i = 0; i < 4; ++i)
    {
        auto bounds = juce::Rectangle<int> (i * channelWidth + padding, padding,
                                             channelWidth - padding * 2, getHeight() - padding * 2);

        auto& ch = channels[i];

        ch.nameLabel.setBounds (bounds.removeFromTop (25));
        bounds.removeFromTop (5);

        auto buttonRow = bounds.removeFromBottom (30);
        ch.muteButton.setBounds (buttonRow.removeFromLeft (buttonRow.getWidth() / 2).reduced (2));
        ch.soloButton.setBounds (buttonRow.reduced (2));

        bounds.removeFromBottom (5);
        ch.fader.setBounds (bounds);
    }
}

void StemMixer::sliderValueChanged (juce::Slider* slider)
{
    for (int i = 0; i < 4; ++i)
    {
        if (&channels[i].fader == slider)
        {
            processor.setStemLevel (static_cast<StemperatorProcessor::Stem> (i),
                                    static_cast<float> (slider->getValue()));
            break;
        }
    }
}

void StemMixer::buttonClicked (juce::Button* button)
{
    for (int i = 0; i < 4; ++i)
    {
        auto stem = static_cast<StemperatorProcessor::Stem> (i);

        if (&channels[i].muteButton == button)
        {
            processor.setStemMute (stem, button->getToggleState());
            break;
        }
        if (&channels[i].soloButton == button)
        {
            processor.setStemSolo (stem, button->getToggleState());
            break;
        }
    }
}
