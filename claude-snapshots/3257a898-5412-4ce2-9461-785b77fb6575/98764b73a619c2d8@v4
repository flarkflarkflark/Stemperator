#include "PluginProcessor.h"
#include "PluginEditor.h"

StemperatorEditor::StemperatorEditor (StemperatorProcessor& p)
    : AudioProcessorEditor (&p), processor (p)
{
    // Apply premium look and feel
    setLookAndFeel (&premiumLookAndFeel);

    // Create stem channels with premium colors
    const char* names[] = { "VOCALS", "DRUMS", "BASS", "OTHER" };
    const char* gainIDs[] = { "vocalsGain", "drumsGain", "bassGain", "otherGain" };
    const char* muteIDs[] = { "vocalsMute", "drumsMute", "bassMute", "otherMute" };
    const char* soloIDs[] = { "vocalsSolo", "drumsSolo", "bassSolo", "otherSolo" };

    for (int i = 0; i < 4; ++i)
    {
        stemChannels[i] = std::make_unique<StemChannel> (names[i], stemColours[static_cast<size_t> (i)]);
        stemChannels[i]->attachToParameters (processor.getParameters(), gainIDs[i], muteIDs[i], soloIDs[i]);
        addAndMakeVisible (*stemChannels[i]);
    }

    // Visualizer
    addAndMakeVisible (visualizer);

    // Master slider - vertical fader style
    setupSlider (masterSlider, PremiumLookAndFeel::Colours::accent);
    masterSlider.setSliderStyle (juce::Slider::LinearVertical);
    masterSlider.setTextBoxStyle (juce::Slider::TextBoxBelow, false, 60, 22);
    masterSlider.setRange (-60.0, 12.0, 0.1);
    masterSlider.setTextValueSuffix (" dB");

    masterLabel.setJustificationType (juce::Justification::centred);
    masterLabel.setFont (juce::FontOptions (13.0f).withStyle ("Bold"));
    masterLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
    addAndMakeVisible (masterLabel);

    masterAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment> (
        processor.getParameters(), "masterGain", masterSlider);

    // Focus controls - rotary knobs
    setupKnob (vocalsFocusSlider, vocalsFocusLabel, "VOCAL FOCUS", stemColours[0]);
    setupKnob (bassCutoffSlider, bassCutoffLabel, "BASS CUTOFF", stemColours[2]);
    setupKnob (drumSensSlider, drumSensLabel, "DRUM SENS", stemColours[1]);

    vocalsFocusAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment> (
        processor.getParameters(), "vocalsFocus", vocalsFocusSlider);
    bassCutoffAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment> (
        processor.getParameters(), "bassCutoff", bassCutoffSlider);
    drumSensAttachment = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment> (
        processor.getParameters(), "drumSensitivity", drumSensSlider);

    // Quality selector
    qualityBox.addItem ("Fast", 1);
    qualityBox.addItem ("Balanced", 2);
    qualityBox.addItem ("Best", 3);
    addAndMakeVisible (qualityBox);

    qualityLabel.setJustificationType (juce::Justification::centred);
    qualityLabel.setFont (juce::FontOptions (11.0f).withStyle ("Bold"));
    qualityLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textMid);
    addAndMakeVisible (qualityLabel);

    qualityAttachment = std::make_unique<juce::AudioProcessorValueTreeState::ComboBoxAttachment> (
        processor.getParameters(), "quality", qualityBox);

    // Title - large and prominent
    titleLabel.setFont (juce::FontOptions (32.0f).withStyle ("Bold"));
    titleLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
    titleLabel.setJustificationType (juce::Justification::centredLeft);
    addAndMakeVisible (titleLabel);

    // Subtitle
    subtitleLabel.setFont (juce::FontOptions (11.0f));
    subtitleLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
    subtitleLabel.setJustificationType (juce::Justification::centredLeft);
    addAndMakeVisible (subtitleLabel);

    // Brand label (right-aligned)
    brandLabel.setFont (juce::FontOptions (14.0f).withStyle ("Bold"));
    brandLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::accent);
    brandLabel.setJustificationType (juce::Justification::centredRight);
    addAndMakeVisible (brandLabel);

    // Start timer for level updates
    startTimerHz (30);

    // Resizable with aspect ratio constraint
    setResizable (true, true);
    setResizeLimits (700, 450, 1400, 900);
    setSize (850, 550);
}

StemperatorEditor::~StemperatorEditor()
{
    setLookAndFeel (nullptr);
    stopTimer();
}

void StemperatorEditor::setupSlider (juce::Slider& slider, juce::Colour colour)
{
    slider.setColour (juce::Slider::thumbColourId, colour);
    slider.setColour (juce::Slider::trackColourId, colour.darker (0.3f));
    slider.setColour (juce::Slider::textBoxTextColourId, PremiumLookAndFeel::Colours::textBright);
    slider.setColour (juce::Slider::textBoxOutlineColourId, juce::Colours::transparentBlack);
    slider.setColour (juce::Slider::textBoxBackgroundColourId, PremiumLookAndFeel::Colours::bgPanel);
    addAndMakeVisible (slider);
}

void StemperatorEditor::setupKnob (juce::Slider& slider, juce::Label& label, const juce::String& text, juce::Colour colour)
{
    slider.setSliderStyle (juce::Slider::RotaryHorizontalVerticalDrag);
    slider.setTextBoxStyle (juce::Slider::TextBoxBelow, false, 60, 18);
    setupSlider (slider, colour);

    label.setText (text, juce::dontSendNotification);
    label.setJustificationType (juce::Justification::centred);
    label.setFont (juce::FontOptions (10.0f).withStyle ("Bold"));
    label.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textMid);
    addAndMakeVisible (label);
}

void StemperatorEditor::paint (juce::Graphics& g)
{
    // Premium gradient background
    juce::ColourGradient bgGradient (
        PremiumLookAndFeel::Colours::bgDark, 0, 0,
        PremiumLookAndFeel::Colours::bgMid, 0, (float) getHeight(), false);
    bgGradient.addColour (0.5, PremiumLookAndFeel::Colours::bgLight.interpolatedWith (
        PremiumLookAndFeel::Colours::bgDark, 0.7f));
    g.setGradientFill (bgGradient);
    g.fillAll();

    // Subtle grid pattern for depth
    g.setColour (PremiumLookAndFeel::Colours::textDim.withAlpha (0.03f));
    for (int y = 0; y < getHeight(); y += 3)
        g.drawHorizontalLine (y, 0, (float) getWidth());

    // Header separator with accent glow
    auto headerBottom = 65;
    juce::ColourGradient separatorGradient (
        PremiumLookAndFeel::Colours::accent.withAlpha (0.0f), 0, (float) headerBottom,
        PremiumLookAndFeel::Colours::accent.withAlpha (0.5f), getWidth() * 0.5f, (float) headerBottom, false);
    separatorGradient.addColour (1.0, PremiumLookAndFeel::Colours::accent.withAlpha (0.0f));
    g.setGradientFill (separatorGradient);
    g.fillRect (0, headerBottom, getWidth(), 2);

    // Footer separator
    auto footerTop = getHeight() - 100;
    g.setGradientFill (separatorGradient);
    g.fillRect (0, footerTop, getWidth(), 1);

    // Panel backgrounds for stem channels area
    auto channelsPanelArea = juce::Rectangle<int> (15, 75, 400, getHeight() - 185);
    g.setColour (PremiumLookAndFeel::Colours::bgPanel.withAlpha (0.3f));
    g.fillRoundedRectangle (channelsPanelArea.toFloat(), 8.0f);
}

void StemperatorEditor::resized()
{
    auto bounds = getLocalBounds();

    // Header area
    auto header = bounds.removeFromTop (65);
    auto headerLeft = header.removeFromLeft (header.getWidth() / 2).reduced (20, 12);
    titleLabel.setBounds (headerLeft.removeFromTop (32));
    subtitleLabel.setBounds (headerLeft);

    auto headerRight = header.reduced (20, 20);
    brandLabel.setBounds (headerRight);

    // Footer with focus controls
    auto footer = bounds.removeFromBottom (95);
    auto controlsArea = footer.reduced (20, 10);

    int knobWidth = 80;

    // Focus knobs on the left
    auto knobArea = controlsArea.removeFromLeft (knobWidth * 3 + 30);

    auto vocalKnob = knobArea.removeFromLeft (knobWidth);
    vocalsFocusLabel.setBounds (vocalKnob.removeFromTop (14));
    vocalsFocusSlider.setBounds (vocalKnob.reduced (4, 0));

    knobArea.removeFromLeft (5);
    auto bassKnob = knobArea.removeFromLeft (knobWidth);
    bassCutoffLabel.setBounds (bassKnob.removeFromTop (14));
    bassCutoffSlider.setBounds (bassKnob.reduced (4, 0));

    knobArea.removeFromLeft (5);
    auto drumKnob = knobArea.removeFromLeft (knobWidth);
    drumSensLabel.setBounds (drumKnob.removeFromTop (14));
    drumSensSlider.setBounds (drumKnob.reduced (4, 0));

    // Quality selector in the center
    auto qualityArea = controlsArea.removeFromLeft (100).reduced (10, 12);
    qualityLabel.setBounds (qualityArea.removeFromTop (14));
    qualityArea.removeFromTop (4);
    qualityBox.setBounds (qualityArea.removeFromTop (28));

    // Main content area
    bounds.reduce (15, 8);

    // Stem channels (left section)
    int channelWidth = 95;
    auto channelsArea = bounds.removeFromLeft (channelWidth * 4 + 20);
    channelsArea.removeFromTop (5);

    for (size_t i = 0; i < 4; ++i)
    {
        stemChannels[i]->setBounds (channelsArea.removeFromLeft (channelWidth).reduced (2, 0));
    }

    // Master fader
    bounds.removeFromLeft (10);
    auto masterArea = bounds.removeFromLeft (75).reduced (0, 5);
    masterLabel.setBounds (masterArea.removeFromTop (22));
    masterSlider.setBounds (masterArea);

    // Visualizer (remaining space)
    bounds.removeFromLeft (15);
    visualizer.setBounds (bounds.reduced (0, 5));
}

void StemperatorEditor::timerCallback()
{
    // Update stem levels from processor
    for (size_t i = 0; i < 4; ++i)
    {
        float level = processor.getStemLevel (static_cast<StemperatorProcessor::Stem> (i));
        stemChannels[i]->setLevel (level);
    }

    // Update visualizer
    visualizer.setStemLevels (
        processor.getStemLevel (StemperatorProcessor::Vocals),
        processor.getStemLevel (StemperatorProcessor::Drums),
        processor.getStemLevel (StemperatorProcessor::Bass),
        processor.getStemLevel (StemperatorProcessor::Other));
    visualizer.setInputLevel (processor.getInputLevel());
}
