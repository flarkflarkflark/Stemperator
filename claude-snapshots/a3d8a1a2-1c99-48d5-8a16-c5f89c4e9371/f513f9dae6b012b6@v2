#pragma once

#include <JuceHeader.h>

/**
 * Visualizer - Premium real-time stem visualization
 *
 * Features:
 * - Animated bar graph with glow effects
 * - Color-coded stem levels
 * - Smooth animations
 * - Mini waveform preview (future)
 */
class Visualizer : public juce::Component,
                   public juce::Timer
{
public:
    Visualizer();

    void paint (juce::Graphics&) override;
    void resized() override;
    void timerCallback() override;

    // Set stem levels for display
    void setStemLevels (float vocals, float drums, float bass, float other);
    void setInputLevel (float level);

    // Animation control - call setActive(true) when playing/exporting
    void setActive (bool shouldBeActive);

private:
    std::array<float, 4> stemLevels = { 0, 0, 0, 0 };
    std::array<float, 4> displayLevels = { 0, 0, 0, 0 };
    std::array<float, 4> peakLevels = { 0, 0, 0, 0 };
    std::array<int, 4> peakHoldCounts = { 0, 0, 0, 0 };
    float inputLevel = 0.0f;
    float displayInputLevel = 0.0f;

    // Animation phase for subtle effects
    float animationPhase = 0.0f;

    const std::array<juce::Colour, 4> stemColours = {
        juce::Colour (0xffff5555),  // Vocals - Vibrant red
        juce::Colour (0xff5599ff),  // Drums - Electric blue
        juce::Colour (0xff55ff99),  // Bass - Neon green
        juce::Colour (0xffffaa33)   // Other - Warm orange
    };

    const std::array<juce::String, 4> stemNames = { "VOCALS", "DRUMS", "BASS", "OTHER" };
    const std::array<juce::String, 4> stemIcons = { "🎤", "🥁", "🎸", "🎹" };

    static constexpr int peakHoldTime = 45;  // ~1.5 seconds at 30fps

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Visualizer)
};
