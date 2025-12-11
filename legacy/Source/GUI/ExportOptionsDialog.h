#pragma once

#include <JuceHeader.h>
#include "PremiumLookAndFeel.h"
#include "StyledDialogWindow.h"

/**
 * ExportOptionsDialog - Modal dialog for export settings
 *
 * Options:
 * - Format: WAV, FLAC, OGG
 * - Bit depth: 16, 24, 32 (WAV/FLAC only)
 * - Sample rate: Original, 44100, 48000, 96000
 * - Quality: 0-10 for OGG
 */
class ExportOptionsDialog : public juce::Component
{
public:
    struct ExportSettings
    {
        juce::String format = "WAV";   // WAV, FLAC, OGG
        int bitDepth = 24;             // 16, 24, 32
        int sampleRate = 0;            // 0 = original, or specific rate
        float oggQuality = 0.8f;       // 0.0 - 1.0 for OGG
    };

    // Callback when user clicks Export
    std::function<void (const ExportSettings&, const juce::File&)> onExport;

    ExportOptionsDialog (const juce::String& defaultFileName, const juce::File& defaultFolder, double originalSampleRate)
        : originalRate (originalSampleRate)
    {
        setSize (400, 320);

        // Title
        titleLabel.setText ("Export Options", juce::dontSendNotification);
        titleLabel.setFont (juce::FontOptions (20.0f).withStyle ("Bold"));
        titleLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
        titleLabel.setJustificationType (juce::Justification::centred);
        addAndMakeVisible (titleLabel);

        // Format selector
        formatLabel.setText ("Format:", juce::dontSendNotification);
        formatLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        addAndMakeVisible (formatLabel);

        formatBox.addItem ("WAV (Uncompressed)", 1);
        formatBox.addItem ("FLAC (Lossless)", 2);
        formatBox.addItem ("OGG Vorbis (Lossy)", 3);
        formatBox.setSelectedId (1);
        formatBox.onChange = [this] { updateOptionsVisibility(); };
        addAndMakeVisible (formatBox);

        // Bit depth selector
        bitDepthLabel.setText ("Bit Depth:", juce::dontSendNotification);
        bitDepthLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        addAndMakeVisible (bitDepthLabel);

        bitDepthBox.addItem ("16-bit", 1);
        bitDepthBox.addItem ("24-bit", 2);
        bitDepthBox.addItem ("32-bit float", 3);
        bitDepthBox.setSelectedId (2);  // Default 24-bit
        addAndMakeVisible (bitDepthBox);

        // Sample rate selector
        sampleRateLabel.setText ("Sample Rate:", juce::dontSendNotification);
        sampleRateLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        addAndMakeVisible (sampleRateLabel);

        sampleRateBox.addItem ("Original (" + juce::String ((int) originalRate) + " Hz)", 1);
        sampleRateBox.addItem ("44100 Hz (CD)", 2);
        sampleRateBox.addItem ("48000 Hz (Video)", 3);
        sampleRateBox.addItem ("96000 Hz (Hi-Res)", 4);
        sampleRateBox.setSelectedId (1);  // Default original
        addAndMakeVisible (sampleRateBox);

        // OGG Quality slider (only for OGG)
        oggQualityLabel.setText ("Quality:", juce::dontSendNotification);
        oggQualityLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        addAndMakeVisible (oggQualityLabel);

        oggQualitySlider.setRange (0.0, 1.0, 0.1);
        oggQualitySlider.setValue (0.8);
        oggQualitySlider.setTextValueSuffix (" (~" + juce::String ((int) (0.8 * 320)) + " kbps)");
        oggQualitySlider.onValueChange = [this]
        {
            float q = (float) oggQualitySlider.getValue();
            int approxKbps = (int) (q * 320);
            oggQualitySlider.setTextValueSuffix (" (~" + juce::String (approxKbps) + " kbps)");
        };
        addAndMakeVisible (oggQualitySlider);

        // File name
        fileNameLabel.setText ("File Name:", juce::dontSendNotification);
        fileNameLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        addAndMakeVisible (fileNameLabel);

        fileNameEditor.setText (defaultFileName);
        fileNameEditor.setColour (juce::TextEditor::backgroundColourId, PremiumLookAndFeel::Colours::bgPanel);
        fileNameEditor.setColour (juce::TextEditor::textColourId, PremiumLookAndFeel::Colours::textBright);
        fileNameEditor.setColour (juce::TextEditor::outlineColourId, PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        addAndMakeVisible (fileNameEditor);

        // Browse button
        browseButton.setButtonText ("...");
        browseButton.onClick = [this, defaultFolder]
        {
            fileChooser = std::make_unique<juce::FileChooser> (
                "Select export folder",
                exportFolder.exists() ? exportFolder : defaultFolder,
                "", true);

            fileChooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories,
                [this] (const juce::FileChooser& fc)
                {
                    auto folder = fc.getResult();
                    if (folder.isDirectory())
                        exportFolder = folder;
                });
        };
        addAndMakeVisible (browseButton);

        exportFolder = defaultFolder;

        // Cancel button
        cancelButton.setButtonText ("Cancel");
        cancelButton.onClick = [this] { closeDialog(); };
        addAndMakeVisible (cancelButton);

        // Export button
        exportButton.setButtonText ("Export");
        exportButton.setColour (juce::TextButton::buttonColourId, PremiumLookAndFeel::Colours::active.darker (0.2f));
        exportButton.onClick = [this] { doExport(); };
        addAndMakeVisible (exportButton);

        // Initial visibility
        updateOptionsVisibility();
    }

    void paint (juce::Graphics& g) override
    {
        g.fillAll (PremiumLookAndFeel::Colours::bgMid);
    }

    void resized() override
    {
        auto b = getLocalBounds().reduced (20);

        titleLabel.setBounds (b.removeFromTop (30));
        b.removeFromTop (15);

        auto rowH = 28;
        auto labelW = 90;
        auto gap = 8;

        // Format row
        auto row = b.removeFromTop (rowH);
        formatLabel.setBounds (row.removeFromLeft (labelW));
        formatBox.setBounds (row);
        b.removeFromTop (gap);

        // Bit depth row
        row = b.removeFromTop (rowH);
        bitDepthLabel.setBounds (row.removeFromLeft (labelW));
        bitDepthBox.setBounds (row);
        b.removeFromTop (gap);

        // Sample rate row
        row = b.removeFromTop (rowH);
        sampleRateLabel.setBounds (row.removeFromLeft (labelW));
        sampleRateBox.setBounds (row);
        b.removeFromTop (gap);

        // OGG Quality row
        row = b.removeFromTop (rowH);
        oggQualityLabel.setBounds (row.removeFromLeft (labelW));
        oggQualitySlider.setBounds (row);
        b.removeFromTop (gap);

        // File name row
        row = b.removeFromTop (rowH);
        fileNameLabel.setBounds (row.removeFromLeft (labelW));
        browseButton.setBounds (row.removeFromRight (30));
        row.removeFromRight (5);
        fileNameEditor.setBounds (row);
        b.removeFromTop (15);

        // Buttons at bottom
        auto buttonRow = b.removeFromBottom (32);
        exportButton.setBounds (buttonRow.removeFromRight (100));
        buttonRow.removeFromRight (10);
        cancelButton.setBounds (buttonRow.removeFromRight (80));
    }

    // Show as modal overlay on parent
    static void show (juce::Component* parent, const juce::String& defaultFileName,
                      const juce::File& defaultFolder, double originalSampleRate,
                      std::function<void (const ExportSettings&, const juce::File&)> callback)
    {
        auto* dialog = new ExportOptionsDialog (defaultFileName, defaultFolder, originalSampleRate);
        dialog->onExport = std::move (callback);
        dialog->parentComponent = parent;

        // Create overlay
        auto* overlay = new juce::Component();
        overlay->setSize (parent->getWidth(), parent->getHeight());
        overlay->addAndMakeVisible (dialog);

        // Center dialog
        dialog->setCentrePosition (overlay->getWidth() / 2, overlay->getHeight() / 2);

        parent->addAndMakeVisible (overlay);
        overlay->toFront (true);

        dialog->overlayComponent = overlay;
    }

private:
    juce::Label titleLabel;
    juce::Label formatLabel, bitDepthLabel, sampleRateLabel, oggQualityLabel, fileNameLabel;
    juce::ComboBox formatBox, bitDepthBox, sampleRateBox;
    juce::Slider oggQualitySlider { juce::Slider::LinearHorizontal, juce::Slider::TextBoxRight };
    juce::TextEditor fileNameEditor;
    juce::TextButton browseButton, cancelButton, exportButton;

    juce::File exportFolder;
    double originalRate;
    std::unique_ptr<juce::FileChooser> fileChooser;

    juce::Component* parentComponent = nullptr;
    juce::Component* overlayComponent = nullptr;

    void updateOptionsVisibility()
    {
        int formatId = formatBox.getSelectedId();
        bool isOgg = (formatId == 3);
        bool isWavOrFlac = (formatId == 1 || formatId == 2);

        bitDepthLabel.setVisible (isWavOrFlac);
        bitDepthBox.setVisible (isWavOrFlac);
        oggQualityLabel.setVisible (isOgg);
        oggQualitySlider.setVisible (isOgg);
    }

    void closeDialog()
    {
        if (overlayComponent && parentComponent)
        {
            parentComponent->removeChildComponent (overlayComponent);
            delete overlayComponent;  // This also deletes us
        }
    }

    void doExport()
    {
        ExportSettings settings;

        // Format
        switch (formatBox.getSelectedId())
        {
            case 1: settings.format = "WAV"; break;
            case 2: settings.format = "FLAC"; break;
            case 3: settings.format = "OGG"; break;
        }

        // Bit depth
        switch (bitDepthBox.getSelectedId())
        {
            case 1: settings.bitDepth = 16; break;
            case 2: settings.bitDepth = 24; break;
            case 3: settings.bitDepth = 32; break;
        }

        // Sample rate
        switch (sampleRateBox.getSelectedId())
        {
            case 1: settings.sampleRate = 0; break;  // Original
            case 2: settings.sampleRate = 44100; break;
            case 3: settings.sampleRate = 48000; break;
            case 4: settings.sampleRate = 96000; break;
        }

        // OGG quality
        settings.oggQuality = (float) oggQualitySlider.getValue();

        // Build file path
        juce::String fileName = fileNameEditor.getText();
        if (fileName.isEmpty())
            fileName = "export";

        // Add extension based on format
        juce::String ext = settings.format.toLowerCase();
        if (! fileName.endsWithIgnoreCase ("." + ext))
            fileName += "." + ext;

        juce::File outputFile = exportFolder.getChildFile (fileName);

        if (onExport)
            onExport (settings, outputFile);

        closeDialog();
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (ExportOptionsDialog)
};
