#pragma once

#include <JuceHeader.h>

/**
 * PremiumLookAndFeel - FabFilter-inspired modern design
 *
 * Design principles:
 * - Clean, minimal, no skeuomorphic elements
 * - Vibrant stem colors with subtle gradients
 * - Smooth animations and visual feedback
 * - High-contrast text for readability
 * - Resizable with vector graphics
 */
class PremiumLookAndFeel : public juce::LookAndFeel_V4
{
public:
    // Color scheme - vibrant but professional
    struct Colours
    {
        // Background gradients
        static inline const juce::Colour bgDark     = juce::Colour (0xff0a0a0f);
        static inline const juce::Colour bgMid      = juce::Colour (0xff151520);
        static inline const juce::Colour bgLight    = juce::Colour (0xff1e1e2a);
        static inline const juce::Colour bgPanel    = juce::Colour (0xff252535);

        // Stem colours (vibrant)
        static inline const juce::Colour vocals     = juce::Colour (0xffff5555);  // Vibrant red
        static inline const juce::Colour drums      = juce::Colour (0xff5599ff);  // Electric blue
        static inline const juce::Colour bass       = juce::Colour (0xff55ff99);  // Neon green
        static inline const juce::Colour other      = juce::Colour (0xffffaa33);  // Warm orange
        static inline const juce::Colour guitar     = juce::Colour (0xffffb450);  // Golden orange (6-stem)
        static inline const juce::Colour piano      = juce::Colour (0xffff78c8);  // Pink magenta (6-stem)

        // UI accents
        static inline const juce::Colour accent     = juce::Colour (0xff7b68ee);  // Medium slate blue
        static inline const juce::Colour highlight  = juce::Colour (0xff00d4ff);  // Cyan highlight
        static inline const juce::Colour textBright = juce::Colour (0xffffffff);
        static inline const juce::Colour textMid    = juce::Colour (0xffaaaacc);
        static inline const juce::Colour textDim    = juce::Colour (0xff666688);

        // State colors
        static inline const juce::Colour mute       = juce::Colour (0xffff4444);  // Mute red
        static inline const juce::Colour solo       = juce::Colour (0xffffcc00);  // Solo yellow
        static inline const juce::Colour active     = juce::Colour (0xff44ff88);  // Active green
    };

    PremiumLookAndFeel()
    {
        // Set default colors
        setColour (juce::Slider::thumbColourId, Colours::accent);
        setColour (juce::Slider::trackColourId, Colours::bgPanel);
        setColour (juce::Slider::backgroundColourId, Colours::bgDark);

        setColour (juce::TextButton::buttonColourId, Colours::bgPanel);
        setColour (juce::TextButton::textColourOnId, Colours::textBright);
        setColour (juce::TextButton::textColourOffId, Colours::textMid);

        setColour (juce::ComboBox::backgroundColourId, Colours::bgPanel);
        setColour (juce::ComboBox::textColourId, Colours::textBright);
        setColour (juce::ComboBox::outlineColourId, Colours::accent.withAlpha (0.5f));

        setColour (juce::Label::textColourId, Colours::textBright);

        setColour (juce::PopupMenu::backgroundColourId, Colours::bgPanel);
        setColour (juce::PopupMenu::textColourId, Colours::textBright);
        setColour (juce::PopupMenu::highlightedBackgroundColourId, Colours::accent);

        // Window title bar colors - match the dark interface
        setColour (juce::ResizableWindow::backgroundColourId, Colours::bgDark);
        setColour (juce::DocumentWindow::textColourId, Colours::textBright);
    }

    //==============================================================================
    // SLIDERS - Modern rotary knobs with glow
    //==============================================================================
    void drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height,
                           float sliderPos, float rotaryStartAngle, float rotaryEndAngle,
                           juce::Slider& slider) override
    {
        auto bounds = juce::Rectangle<float> (x, y, width, height).reduced (4.0f);
        auto radius = juce::jmin (bounds.getWidth(), bounds.getHeight()) / 2.0f;
        auto centreX = bounds.getCentreX();
        auto centreY = bounds.getCentreY();
        auto rx = centreX - radius;
        auto ry = centreY - radius;
        auto rw = radius * 2.0f;
        auto angle = rotaryStartAngle + sliderPos * (rotaryEndAngle - rotaryStartAngle);

        // Get thumb color (stem color if set)
        auto thumbColour = slider.findColour (juce::Slider::thumbColourId);

        // Background ring
        g.setColour (Colours::bgDark);
        g.fillEllipse (rx, ry, rw, rw);

        // Track arc (background)
        juce::Path backgroundArc;
        backgroundArc.addCentredArc (centreX, centreY, radius * 0.85f, radius * 0.85f,
                                     0.0f, rotaryStartAngle, rotaryEndAngle, true);
        g.setColour (Colours::bgPanel);
        g.strokePath (backgroundArc, juce::PathStrokeType (4.0f, juce::PathStrokeType::curved,
                                                           juce::PathStrokeType::rounded));

        // Value arc (filled portion with glow)
        juce::Path valueArc;
        valueArc.addCentredArc (centreX, centreY, radius * 0.85f, radius * 0.85f,
                                0.0f, rotaryStartAngle, angle, true);

        // Glow effect
        g.setColour (thumbColour.withAlpha (0.3f));
        g.strokePath (valueArc, juce::PathStrokeType (8.0f, juce::PathStrokeType::curved,
                                                       juce::PathStrokeType::rounded));

        // Main value arc
        g.setColour (thumbColour);
        g.strokePath (valueArc, juce::PathStrokeType (4.0f, juce::PathStrokeType::curved,
                                                       juce::PathStrokeType::rounded));

        // Knob center
        auto knobRadius = radius * 0.6f;
        juce::ColourGradient knobGradient (Colours::bgLight, centreX, centreY - knobRadius * 0.5f,
                                           Colours::bgDark, centreX, centreY + knobRadius, false);
        g.setGradientFill (knobGradient);
        g.fillEllipse (centreX - knobRadius, centreY - knobRadius, knobRadius * 2.0f, knobRadius * 2.0f);

        // Pointer line
        juce::Path pointer;
        auto pointerLength = radius * 0.5f;
        auto pointerThickness = 3.0f;
        pointer.addRoundedRectangle (-pointerThickness * 0.5f, -radius * 0.75f,
                                     pointerThickness, pointerLength, 1.5f);
        g.setColour (thumbColour);
        g.fillPath (pointer, juce::AffineTransform::rotation (angle).translated (centreX, centreY));
    }

    //==============================================================================
    // LINEAR SLIDERS - Fader style with gradient fill
    //==============================================================================
    void drawLinearSlider (juce::Graphics& g, int x, int y, int width, int height,
                           float sliderPos, float minSliderPos, float maxSliderPos,
                           juce::Slider::SliderStyle style, juce::Slider& slider) override
    {
        auto thumbColour = slider.findColour (juce::Slider::thumbColourId);
        auto isVertical = style == juce::Slider::LinearVertical || style == juce::Slider::LinearBarVertical;

        auto bounds = juce::Rectangle<float> (x, y, width, height);

        if (isVertical)
        {
            // Vertical fader
            auto trackWidth = 8.0f;
            auto trackBounds = bounds.withSizeKeepingCentre (trackWidth, bounds.getHeight() - 20);

            // Track background
            g.setColour (Colours::bgDark);
            g.fillRoundedRectangle (trackBounds, 4.0f);

            // Track fill with gradient
            auto fillHeight = trackBounds.getBottom() - sliderPos;
            auto fillBounds = trackBounds.withTop (sliderPos);

            if (fillBounds.getHeight() > 0)
            {
                juce::ColourGradient gradient (thumbColour.withAlpha (0.8f), 0, fillBounds.getY(),
                                               thumbColour.darker (0.3f), 0, fillBounds.getBottom(), false);
                g.setGradientFill (gradient);
                g.fillRoundedRectangle (fillBounds, 4.0f);

                // Glow
                g.setColour (thumbColour.withAlpha (0.2f));
                g.fillRoundedRectangle (fillBounds.expanded (3.0f, 0), 6.0f);
            }

            // Thumb
            auto thumbSize = 24.0f;
            auto thumbY = sliderPos - thumbSize / 2.0f;
            auto thumbBounds = juce::Rectangle<float> (bounds.getCentreX() - thumbSize / 2, thumbY,
                                                       thumbSize, thumbSize);

            // Thumb shadow
            g.setColour (juce::Colours::black.withAlpha (0.4f));
            g.fillRoundedRectangle (thumbBounds.translated (0, 2), 4.0f);

            // Thumb body
            juce::ColourGradient thumbGradient (Colours::bgLight, thumbBounds.getX(), thumbBounds.getY(),
                                                Colours::bgPanel, thumbBounds.getX(), thumbBounds.getBottom(), false);
            g.setGradientFill (thumbGradient);
            g.fillRoundedRectangle (thumbBounds, 4.0f);

            // Thumb highlight line
            g.setColour (thumbColour);
            g.fillRoundedRectangle (thumbBounds.getCentreX() - 8, thumbBounds.getCentreY() - 1.5f, 16.0f, 3.0f, 1.5f);
        }
        else
        {
            // Horizontal slider
            auto trackHeight = 6.0f;
            auto trackBounds = bounds.withSizeKeepingCentre (bounds.getWidth() - 20, trackHeight);

            g.setColour (Colours::bgDark);
            g.fillRoundedRectangle (trackBounds, 3.0f);

            auto fillWidth = sliderPos - trackBounds.getX();
            auto fillBounds = trackBounds.withWidth (fillWidth);

            if (fillBounds.getWidth() > 0)
            {
                juce::ColourGradient gradient (thumbColour, fillBounds.getX(), 0,
                                               thumbColour.darker (0.3f), fillBounds.getRight(), 0, false);
                g.setGradientFill (gradient);
                g.fillRoundedRectangle (fillBounds, 3.0f);
            }

            // Thumb
            auto thumbSize = 18.0f;
            g.setColour (thumbColour);
            g.fillEllipse (sliderPos - thumbSize / 2, bounds.getCentreY() - thumbSize / 2, thumbSize, thumbSize);
        }
    }

    //==============================================================================
    // BUTTONS - 3D push-button style with bevel effect
    //==============================================================================
    void drawButtonBackground (juce::Graphics& g, juce::Button& button,
                               const juce::Colour& backgroundColour,
                               bool shouldDrawButtonAsHighlighted,
                               bool shouldDrawButtonAsDown) override
    {
        auto bounds = button.getLocalBounds().toFloat().reduced (1.0f);
        auto baseColour = backgroundColour;
        bool isToggled = false;

        // Check if toggled (for M/S buttons)
        if (auto* toggle = dynamic_cast<juce::ToggleButton*> (&button))
            isToggled = toggle->getToggleState();
        else if (auto* textBtn = dynamic_cast<juce::TextButton*> (&button))
            isToggled = textBtn->getToggleState();

        if (isToggled)
        {
            auto onColour = button.findColour (juce::TextButton::buttonOnColourId);
            baseColour = onColour;

            // Glow effect for active state
            g.setColour (onColour.withAlpha (0.3f));
            g.fillRoundedRectangle (bounds.expanded (2.0f), 6.0f);
        }

        // Check if this is a Play/Stop button (by checking button text)
        auto buttonText = button.getButtonText().toLowerCase();
        bool isTransportButton = buttonText == "play" || buttonText == "stop";

        if (isTransportButton)
        {
            // 3D Push-button style for Play/Stop
            float cornerSize = 6.0f;

            if (shouldDrawButtonAsDown)
            {
                // Pressed state - inset look
                g.setColour (baseColour.darker (0.3f));
                g.fillRoundedRectangle (bounds, cornerSize);

                // Inner shadow (top-left darker)
                g.setColour (juce::Colours::black.withAlpha (0.3f));
                g.drawRoundedRectangle (bounds.reduced (1), cornerSize, 1.5f);
            }
            else
            {
                // Normal/hover state - raised 3D look

                // Shadow underneath
                g.setColour (juce::Colours::black.withAlpha (0.4f));
                g.fillRoundedRectangle (bounds.translated (0, 2), cornerSize);

                // Main button body with gradient
                juce::ColourGradient gradient (
                    baseColour.brighter (shouldDrawButtonAsHighlighted ? 0.3f : 0.15f),
                    bounds.getX(), bounds.getY(),
                    baseColour.darker (0.1f),
                    bounds.getX(), bounds.getBottom(), false);
                g.setGradientFill (gradient);
                g.fillRoundedRectangle (bounds, cornerSize);

                // Top highlight
                g.setColour (juce::Colours::white.withAlpha (0.15f));
                g.fillRoundedRectangle (bounds.getX() + 2, bounds.getY() + 1,
                                        bounds.getWidth() - 4, bounds.getHeight() * 0.4f, cornerSize);

                // Border
                g.setColour (baseColour.darker (0.4f));
                g.drawRoundedRectangle (bounds, cornerSize, 1.0f);
            }
        }
        else
        {
            // Standard flat button style for M/S and other buttons
            if (shouldDrawButtonAsDown)
                baseColour = baseColour.brighter (0.2f);
            else if (shouldDrawButtonAsHighlighted)
                baseColour = baseColour.brighter (0.1f);

            g.setColour (baseColour);
            g.fillRoundedRectangle (bounds, 4.0f);

            g.setColour (Colours::accent.withAlpha (0.3f));
            g.drawRoundedRectangle (bounds, 4.0f, 1.0f);
        }
    }

    void drawButtonText (juce::Graphics& g, juce::TextButton& button,
                         bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override
    {
        // Check if this is a Play/Stop button or M/S button
        auto buttonText = button.getButtonText().toLowerCase();
        bool isTransportButton = buttonText == "play" || buttonText == "stop";
        bool isMuteOrSolo = buttonText == "m" || buttonText == "s";

        // Bigger font for transport buttons and M/S buttons
        juce::Font font;
        if (isTransportButton)
            font = juce::FontOptions (22.0f).withStyle ("Bold");
        else if (isMuteOrSolo)
            font = juce::FontOptions (18.0f).withStyle ("Bold");  // Bigger M/S text
        else
            font = juce::FontOptions (14.0f);
        g.setFont (font);

        juce::Colour textColour;
        if (isTransportButton)
        {
            // Always white text for transport buttons
            textColour = Colours::textBright;
            if (shouldDrawButtonAsDown)
                textColour = textColour.darker (0.2f);
        }
        else
        {
            textColour = button.getToggleState()
                              ? button.findColour (juce::TextButton::textColourOnId)
                              : button.findColour (juce::TextButton::textColourOffId);

            if (shouldDrawButtonAsHighlighted)
                textColour = textColour.brighter (0.2f);
        }

        g.setColour (textColour);

        // Offset text slightly when pressed for 3D effect
        auto textBounds = button.getLocalBounds();
        if (isTransportButton && shouldDrawButtonAsDown)
            textBounds.translate (0, 1);

        g.drawText (button.getButtonText(), textBounds, juce::Justification::centred, false);
    }

    //==============================================================================
    // COMBOBOX - Modern dropdown style
    //==============================================================================
    void drawComboBox (juce::Graphics& g, int width, int height, bool isButtonDown,
                       int buttonX, int buttonY, int buttonW, int buttonH,
                       juce::ComboBox& box) override
    {
        auto bounds = juce::Rectangle<float> (0, 0, width, height).reduced (1.0f);

        g.setColour (Colours::bgPanel);
        g.fillRoundedRectangle (bounds, 4.0f);

        g.setColour (Colours::accent.withAlpha (0.4f));
        g.drawRoundedRectangle (bounds, 4.0f, 1.0f);

        // Arrow
        auto arrowZone = juce::Rectangle<float> (width - 20.0f, 0, 20.0f, height);
        juce::Path arrow;
        arrow.addTriangle (arrowZone.getCentreX() - 4, arrowZone.getCentreY() - 2,
                           arrowZone.getCentreX() + 4, arrowZone.getCentreY() - 2,
                           arrowZone.getCentreX(), arrowZone.getCentreY() + 4);

        g.setColour (Colours::textMid);
        g.fillPath (arrow);
    }

    //==============================================================================
    // LABELS - Clean with proper colors
    //==============================================================================
    void drawLabel (juce::Graphics& g, juce::Label& label) override
    {
        g.fillAll (label.findColour (juce::Label::backgroundColourId));

        auto text = label.getText();
        auto font = label.getFont();
        auto textArea = label.getBorderSize().subtractedFrom (label.getLocalBounds());

        g.setColour (label.findColour (juce::Label::textColourId));
        g.setFont (font);
        g.drawText (text, textArea, label.getJustificationType(), false);
    }

    //==============================================================================
    // TOOLTIP - Multi-line with full text visibility
    //==============================================================================
    juce::Rectangle<int> getTooltipBounds (const juce::String& tipText,
                                           juce::Point<int> screenPos,
                                           juce::Rectangle<int> parentArea) override
    {
        juce::Font font (juce::FontOptions (18.0f));
        int maxWidth = 450;  // Max width before wrapping

        juce::AttributedString s;
        s.setJustification (juce::Justification::centredLeft);
        s.append (tipText, font, Colours::textBright);

        juce::TextLayout tl;
        tl.createLayout (s, (float) maxWidth);

        int w = juce::jmin ((int) tl.getWidth() + 24, maxWidth + 24);
        int h = (int) tl.getHeight() + 16;

        // Position tooltip - prefer below and to the right of cursor
        int x = screenPos.x + 10;
        int y = screenPos.y + 20;

        // If would go off right edge, flip to left
        if (x + w > parentArea.getRight())
            x = screenPos.x - w - 10;

        // If would go off bottom, flip to above cursor
        if (y + h > parentArea.getBottom())
            y = screenPos.y - h - 10;

        return juce::Rectangle<int> (x, y, w, h).constrainedWithin (parentArea);
    }

    void drawTooltip (juce::Graphics& g, const juce::String& text, int width, int height) override
    {
        auto bounds = juce::Rectangle<float> (0, 0, (float) width, (float) height);

        // Background with slight transparency
        g.setColour (Colours::bgPanel.withAlpha (0.97f));
        g.fillRoundedRectangle (bounds, 6.0f);

        // Accent border
        g.setColour (Colours::accent.withAlpha (0.6f));
        g.drawRoundedRectangle (bounds.reduced (0.5f), 6.0f, 1.5f);

        // Multi-line text layout
        juce::Font font (juce::FontOptions (18.0f));
        juce::AttributedString s;
        s.setJustification (juce::Justification::centredLeft);
        s.append (text, font, Colours::textBright);

        juce::TextLayout tl;
        tl.createLayout (s, bounds.getWidth() - 20.0f);
        tl.draw (g, bounds.reduced (12.0f, 8.0f));
    }

    //==============================================================================
    // DOCUMENT WINDOW - Dark title bar matching interface with colorful title
    //==============================================================================
    void drawDocumentWindowTitleBar (juce::DocumentWindow& window, juce::Graphics& g,
                                     int w, int h, int titleSpaceX, int titleSpaceW,
                                     const juce::Image* icon, bool drawTitleTextOnLeft) override
    {
        // Fill title bar with SAME dark background as main app area
        g.fillAll (juce::Colour (0xff0a0a12));  // Very dark, matching app background

        // Draw a subtle gradient matching the app's premium look
        juce::ColourGradient gradient (
            juce::Colour (0xff12121a), 0, 0,  // Slightly lighter at top
            juce::Colour (0xff0a0a12), 0, (float) h, false);  // Dark at bottom
        g.setGradientFill (gradient);
        g.fillRect (0, 0, w, h);

        // Bottom accent line - subtle cyan glow
        g.setColour (Colours::accent.withAlpha (0.5f));
        g.fillRect (0, h - 2, w, 2);

        // Title text with colorful "STEMPERATOR" letters - bigger font
        auto title = window.getName();
        g.setFont (juce::FontOptions ((float) h * 0.55f).withStyle ("Bold"));

        // Check if title starts with "Stemperator"
        if (title.startsWithIgnoreCase ("Stemperator"))
        {
            // Colorful letters for "STEMPERATOR" cycling through stem colors
            const juce::Colour letterColors[] = {
                Colours::vocals,  // S - red
                Colours::drums,   // T - blue
                Colours::bass,    // E - green
                Colours::other,   // M - orange
                Colours::vocals,  // P - red
                Colours::drums,   // E - blue
                Colours::bass,    // R - green
                Colours::other,   // A - orange
                Colours::vocals,  // T - red
                Colours::drums,   // O - blue
                Colours::bass     // R - green
            };

            // Calculate total width for centering
            float totalWidth = g.getCurrentFont().getStringWidthFloat (title);
            float startX = drawTitleTextOnLeft ? (float) titleSpaceX
                                                : (float) titleSpaceX + ((float) titleSpaceW - totalWidth) / 2.0f;

            // Draw each character
            float x = startX;
            for (int i = 0; i < title.length(); ++i)
            {
                juce::String ch = title.substring (i, i + 1);
                float charWidth = g.getCurrentFont().getStringWidthFloat (ch);

                // Use stem colors for first 11 chars ("Stemperator"), white for rest
                if (i < 11)
                    g.setColour (letterColors[i]);
                else
                    g.setColour (Colours::textMid);

                g.drawText (ch, (int) x, 0, (int) charWidth + 2, h, juce::Justification::centredLeft, false);
                x += charWidth;
            }
        }
        else
        {
            // Normal title drawing
            g.setColour (Colours::textBright);
            auto textBounds = juce::Rectangle<int> (titleSpaceX, 0, titleSpaceW, h);
            g.drawText (title, textBounds, drawTitleTextOnLeft ? juce::Justification::centredLeft
                                                               : juce::Justification::centred, true);
        }
    }

    //==============================================================================
    // Helper: Get stem color by index
    //==============================================================================
    static juce::Colour getStemColour (int stemIndex)
    {
        switch (stemIndex)
        {
            case 0: return Colours::vocals;
            case 1: return Colours::drums;
            case 2: return Colours::bass;
            case 3: return Colours::other;
            default: return Colours::accent;
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PremiumLookAndFeel)
};
