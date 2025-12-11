#include "Visualizer.h"
#include "PremiumLookAndFeel.h"
#include <cmath>

Visualizer::Visualizer()
{
    // Don't start timer - will be started when setActive(true) is called

    // Optimize rendering - cache to reduce GPU load when idle
    setBufferedToImage (true);
    setOpaque (true);
}

void Visualizer::paint (juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background with subtle gradient
    juce::ColourGradient bgGradient (
        PremiumLookAndFeel::Colours::bgDark, bounds.getX(), bounds.getY(),
        PremiumLookAndFeel::Colours::bgMid, bounds.getX(), bounds.getBottom(), false);
    g.setGradientFill (bgGradient);
    g.fillRoundedRectangle (bounds, 10.0f);

    // Border
    g.setColour (PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
    g.drawRoundedRectangle (bounds.reduced (1.0f), 10.0f, 1.5f);

    // Title with glow effect
    g.setFont (juce::FontOptions (14.0f).withStyle ("Bold"));
    g.setColour (PremiumLookAndFeel::Colours::accent.withAlpha (0.5f));
    g.drawText ("STEM LEVELS", bounds.removeFromTop (28), juce::Justification::centred, false);
    g.setColour (PremiumLookAndFeel::Colours::textBright);
    g.drawText ("STEM LEVELS", bounds.getX(), 0, bounds.getWidth(), 28, juce::Justification::centred, false);

    // Calculate bar dimensions
    auto contentArea = getLocalBounds().toFloat().reduced (15.0f);
    contentArea.removeFromTop (28);
    contentArea.removeFromBottom (35);

    float barSpacing = 12.0f;
    float totalSpacing = barSpacing * 3;
    float barWidth = (contentArea.getWidth() - totalSpacing) / 4.0f;
    float maxHeight = contentArea.getHeight();

    // Draw each stem bar
    for (size_t i = 0; i < 4; ++i)
    {
        float x = contentArea.getX() + i * (barWidth + barSpacing);
        float barHeight = displayLevels[i] * maxHeight;
        float barY = contentArea.getBottom() - barHeight;

        // Bar background (track)
        g.setColour (stemColours[i].withAlpha (0.15f));
        g.fillRoundedRectangle (x, contentArea.getY(), barWidth, maxHeight, 6.0f);

        // Grid lines
        g.setColour (PremiumLookAndFeel::Colours::textDim.withAlpha (0.1f));
        for (int gridLine = 1; gridLine < 4; ++gridLine)
        {
            float gridY = contentArea.getY() + maxHeight * gridLine / 4.0f;
            g.drawHorizontalLine ((int) gridY, x + 2, x + barWidth - 2);
        }

        // Main bar with gradient fill
        if (barHeight > 0)
        {
            auto barRect = juce::Rectangle<float> (x, barY, barWidth, barHeight);

            // Glow effect (larger, more diffuse)
            g.setColour (stemColours[i].withAlpha (0.25f));
            g.fillRoundedRectangle (barRect.expanded (4.0f, 2.0f), 8.0f);

            // Main gradient fill
            juce::ColourGradient barGradient (
                stemColours[i].brighter (0.2f), barRect.getX(), barRect.getY(),
                stemColours[i].darker (0.2f), barRect.getX(), barRect.getBottom(), false);
            g.setGradientFill (barGradient);
            g.fillRoundedRectangle (barRect, 6.0f);

            // Highlight at top of bar
            g.setColour (stemColours[i].brighter (0.5f));
            g.fillRoundedRectangle (x + 2, barY, barWidth - 4, juce::jmin (4.0f, barHeight), 2.0f);

            // Animated shimmer effect (subtle)
            float shimmerY = barY + (barHeight * 0.5f) + std::sin (animationPhase + i * 0.5f) * barHeight * 0.1f;
            g.setColour (juce::Colours::white.withAlpha (0.15f));
            g.fillRoundedRectangle (x + 4, shimmerY - 2, barWidth - 8, 4.0f, 2.0f);
        }

        // Peak hold indicator
        if (peakLevels[i] > 0.01f)
        {
            float peakY = contentArea.getBottom() - (peakLevels[i] * maxHeight);
            juce::Colour peakColour = peakLevels[i] > 0.9f
                                          ? PremiumLookAndFeel::Colours::mute
                                          : stemColours[i].brighter (0.3f);
            g.setColour (peakColour);
            g.fillRoundedRectangle (x, peakY - 2, barWidth, 4.0f, 2.0f);
        }

        // Stem label at bottom
        auto labelArea = juce::Rectangle<float> (x, contentArea.getBottom() + 5, barWidth, 30);
        g.setFont (juce::FontOptions (11.0f).withStyle ("Bold"));
        g.setColour (stemColours[i]);
        g.drawText (stemNames[i], labelArea, juce::Justification::centredTop, false);

        // dB value below label
        float dbValue = 20.0f * std::log10 (juce::jmax (displayLevels[i], 0.0001f));
        g.setFont (juce::FontOptions (10.0f));
        g.setColour (PremiumLookAndFeel::Colours::textDim);
        g.drawText (juce::String (dbValue, 1) + " dB", labelArea.translated (0, 13),
                    juce::Justification::centredTop, false);
    }

    // Input level indicator (small bar on the right)
    auto inputBarArea = bounds.removeFromRight (20).reduced (0, 20);
    g.setColour (PremiumLookAndFeel::Colours::bgDark);
    g.fillRoundedRectangle (inputBarArea, 4.0f);

    float inputHeight = displayInputLevel * inputBarArea.getHeight();
    if (inputHeight > 0)
    {
        auto inputFill = juce::Rectangle<float> (
            inputBarArea.getX(), inputBarArea.getBottom() - inputHeight,
            inputBarArea.getWidth(), inputHeight);
        g.setColour (PremiumLookAndFeel::Colours::accent);
        g.fillRoundedRectangle (inputFill, 4.0f);
    }

    g.setFont (juce::FontOptions (10.0f));
    g.setColour (PremiumLookAndFeel::Colours::textDim);
    g.drawText ("IN", inputBarArea.getX() - 2, inputBarArea.getBottom() + 2, 24, 12,
                juce::Justification::centred, false);
}

void Visualizer::resized()
{
}

void Visualizer::timerCallback()
{
    // Track if anything has changed that requires a repaint
    bool needsRepaint = false;
    constexpr float changeThreshold = 0.001f;  // Minimum change to trigger repaint

    // Smooth level display with fast attack, slow release
    for (size_t i = 0; i < 4; ++i)
    {
        float target = stemLevels[i];
        float oldDisplay = displayLevels[i];

        if (target > displayLevels[i])
            displayLevels[i] = target;  // Fast attack
        else
            displayLevels[i] = displayLevels[i] * 0.88f + target * 0.12f;  // Smooth release

        // Check if display changed significantly
        if (std::abs (displayLevels[i] - oldDisplay) > changeThreshold)
            needsRepaint = true;

        // Peak hold
        float oldPeak = peakLevels[i];
        if (target >= peakLevels[i])
        {
            peakLevels[i] = target;
            peakHoldCounts[i] = 0;
        }
        else
        {
            peakHoldCounts[i]++;
            if (peakHoldCounts[i] > peakHoldTime)
                peakLevels[i] *= 0.93f;
        }

        if (std::abs (peakLevels[i] - oldPeak) > changeThreshold)
            needsRepaint = true;
    }

    float oldInputDisplay = displayInputLevel;
    displayInputLevel = displayInputLevel * 0.85f + inputLevel * 0.15f;
    if (std::abs (displayInputLevel - oldInputDisplay) > changeThreshold)
        needsRepaint = true;

    // Update animation phase only if there are active levels (something is playing)
    bool hasActiveLevels = (displayLevels[0] > 0.01f || displayLevels[1] > 0.01f ||
                            displayLevels[2] > 0.01f || displayLevels[3] > 0.01f);
    if (hasActiveLevels)
    {
        animationPhase += 0.1f;
        if (animationPhase > juce::MathConstants<float>::twoPi)
            animationPhase -= juce::MathConstants<float>::twoPi;
        needsRepaint = true;  // Animation needs repaint
    }

    // Only repaint if something actually changed
    if (needsRepaint)
        repaint();
}

void Visualizer::setStemLevels (float vocals, float drums, float bass, float other)
{
    stemLevels[0] = vocals;
    stemLevels[1] = drums;
    stemLevels[2] = bass;
    stemLevels[3] = other;
}

void Visualizer::setInputLevel (float level)
{
    inputLevel = level;
}

void Visualizer::setActive (bool shouldBeActive)
{
    if (shouldBeActive && ! isTimerRunning())
        startTimerHz (30);
    else if (! shouldBeActive && isTimerRunning())
        stopTimer();
}
