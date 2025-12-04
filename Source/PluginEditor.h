#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "GUI/StemChannel.h"
#include "GUI/Visualizer.h"
#include "GUI/PremiumLookAndFeel.h"

/**
 * StemperatorEditor - Premium plugin GUI
 *
 * FabFilter-inspired design:
 * - Clean, modern, no skeuomorphic elements
 * - Vibrant stem colors with gradients and glow
 * - Smooth visual feedback and animations
 * - Resizable with proper scaling
 */
class StemperatorEditor : public juce::AudioProcessorEditor,
                          public juce::Timer
{
public:
    explicit StemperatorEditor (StemperatorProcessor&);
    ~StemperatorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;
    void timerCallback() override;

private:
    StemperatorProcessor& processor;
    PremiumLookAndFeel premiumLookAndFeel;

    // Stem channels
    std::array<std::unique_ptr<StemChannel>, 4> stemChannels;

    // Visualizer
    Visualizer visualizer;

    // Master section
    juce::Slider masterSlider;
    juce::Label masterLabel { {}, "MASTER" };
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> masterAttachment;

    // Focus controls
    juce::Slider vocalsFocusSlider;
    juce::Slider bassCutoffSlider;
    juce::Slider drumSensSlider;
    juce::Label vocalsFocusLabel { {}, "VOCAL FOCUS" };
    juce::Label bassCutoffLabel { {}, "BASS CUTOFF" };
    juce::Label drumSensLabel { {}, "DRUM SENS" };

    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> vocalsFocusAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> bassCutoffAttachment;
    std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> drumSensAttachment;

    // Quality selector
    juce::ComboBox qualityBox;
    juce::Label qualityLabel { {}, "QUALITY" };
    std::unique_ptr<juce::AudioProcessorValueTreeState::ComboBoxAttachment> qualityAttachment;

    // Header components
    juce::Label titleLabel { {}, "STEMPERATOR" };
    juce::Label subtitleLabel { {}, "AI-POWERED STEM SEPARATION" };
    juce::Label brandLabel { {}, "flarkAUDIO" };

    // Colours
    const std::array<juce::Colour, 4> stemColours = {
        PremiumLookAndFeel::Colours::vocals,
        PremiumLookAndFeel::Colours::drums,
        PremiumLookAndFeel::Colours::bass,
        PremiumLookAndFeel::Colours::other
    };

    void setupSlider (juce::Slider& slider, juce::Colour colour);
    void setupKnob (juce::Slider& slider, juce::Label& label, const juce::String& text, juce::Colour colour);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorEditor)
};
