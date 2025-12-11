#include "PluginProcessor.h"
#include "PluginEditor.h"

StemperatorEditor::StemperatorEditor (StemperatorProcessor& p)
    : AudioProcessorEditor (&p), processor (p), stemMixer (p)
{
    addAndMakeVisible (stemMixer);
    setSize (600, 400);
}

StemperatorEditor::~StemperatorEditor() = default;

void StemperatorEditor::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colour (0xff1a1a2e));

    g.setColour (juce::Colours::white);
    g.setFont (24.0f);
    g.drawText ("Stemperator", getLocalBounds().removeFromTop (50), juce::Justification::centred);

    g.setFont (12.0f);
    g.setColour (juce::Colours::grey);
    g.drawText ("flarkAUDIO", getLocalBounds().removeFromBottom (20), juce::Justification::centred);
}

void StemperatorEditor::resized()
{
    auto bounds = getLocalBounds().reduced (10);
    bounds.removeFromTop (50);
    bounds.removeFromBottom (20);
    stemMixer.setBounds (bounds);
}
