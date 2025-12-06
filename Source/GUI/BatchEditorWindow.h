#pragma once

#include <JuceHeader.h>
#include "PremiumLookAndFeel.h"

/**
 * BatchEditorWindow - Reaper-style batch stem processor
 *
 * Minimal, efficient layout:
 * - File list (drag & drop or Add button)
 * - Output next to source files (like Reaper)
 * - Single "Process" button
 */
class BatchEditorWindow : public juce::DocumentWindow,
                          public juce::FileDragAndDropTarget,
                          public juce::ListBoxModel
{
public:
    // Callback when user starts batch processing
    std::function<void (const juce::Array<juce::File>& files, const juce::String& modelName)> onStartBatch;

    BatchEditorWindow (const juce::String& modelName)
        : juce::DocumentWindow ("Batch Process",
                                PremiumLookAndFeel::Colours::bgDark,
                                juce::DocumentWindow::closeButton),
          currentModel (modelName)
    {
        setUsingNativeTitleBar (false);
        setTitleBarHeight (32);
        setResizable (true, true);
        setSize (500, 400);
        centreWithSize (getWidth(), getHeight());

        content = std::make_unique<juce::Component>();
        setContentOwned (content.get(), false);

        // File list
        fileList = std::make_unique<juce::ListBox> ("Files", this);
        fileList->setColour (juce::ListBox::backgroundColourId, PremiumLookAndFeel::Colours::bgPanel);
        fileList->setColour (juce::ListBox::outlineColourId, PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        fileList->setOutlineThickness (1);
        fileList->setRowHeight (24);
        fileList->setMultipleSelectionEnabled (true);
        content->addAndMakeVisible (fileList.get());

        // Button row
        addButton = std::make_unique<juce::TextButton> ("Add Files...");
        addButton->onClick = [this] { addFiles(); };
        content->addAndMakeVisible (addButton.get());

        clearButton = std::make_unique<juce::TextButton> ("Clear");
        clearButton->onClick = [this] { files.clear(); updateUI(); };
        content->addAndMakeVisible (clearButton.get());

        // Status
        statusLabel = std::make_unique<juce::Label> ("", "Drop audio files here");
        statusLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        statusLabel->setFont (juce::FontOptions (12.0f));
        statusLabel->setJustificationType (juce::Justification::centred);
        content->addAndMakeVisible (statusLabel.get());

        // Process button
        processButton = std::make_unique<juce::TextButton> ("Process");
        processButton->setColour (juce::TextButton::buttonColourId, PremiumLookAndFeel::Colours::active.darker (0.2f));
        processButton->onClick = [this] { startProcessing(); };
        processButton->setEnabled (false);
        content->addAndMakeVisible (processButton.get());

        setVisible (true);
    }

    ~BatchEditorWindow() override = default;

    void closeButtonPressed() override { setVisible (false); }

    void resized() override
    {
        juce::DocumentWindow::resized();
        if (content == nullptr) return;

        auto b = content->getLocalBounds().reduced (10);

        // Bottom: Process button
        auto bottomRow = b.removeFromBottom (32);
        processButton->setBounds (bottomRow.removeFromRight (100));

        b.removeFromBottom (8);

        // Status line
        statusLabel->setBounds (b.removeFromBottom (20));
        b.removeFromBottom (6);

        // Button row
        auto buttonRow = b.removeFromBottom (28);
        addButton->setBounds (buttonRow.removeFromLeft (90));
        buttonRow.removeFromLeft (6);
        clearButton->setBounds (buttonRow.removeFromLeft (60));

        b.removeFromBottom (8);

        // File list takes the rest
        fileList->setBounds (b);
    }

    void paint (juce::Graphics& g) override
    {
        juce::DocumentWindow::paint (g);
        if (content != nullptr)
        {
            g.setColour (PremiumLookAndFeel::Colours::bgMid);
            g.fillRect (content->getLocalBounds());
        }
    }

    // FileDragAndDropTarget
    bool isInterestedInFileDrag (const juce::StringArray& draggedFiles) override
    {
        for (const auto& f : draggedFiles)
        {
            juce::File file (f);
            if (file.isDirectory() || isAudioFile (file))
                return true;
        }
        return false;
    }

    void filesDropped (const juce::StringArray& droppedFiles, int, int) override
    {
        for (const auto& f : droppedFiles)
        {
            juce::File file (f);
            if (file.isDirectory())
                addAudioFilesFromFolder (file);
            else if (isAudioFile (file))
                addFile (file);
        }
        updateUI();
    }

    // ListBoxModel
    int getNumRows() override { return files.size(); }

    void paintListBoxItem (int row, juce::Graphics& g, int width, int height, bool selected) override
    {
        if (row >= files.size()) return;

        if (selected)
            g.fillAll (PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        else if (row % 2)
            g.fillAll (PremiumLookAndFeel::Colours::bgDark.withAlpha (0.15f));

        g.setColour (PremiumLookAndFeel::Colours::textBright);
        g.setFont (juce::FontOptions (13.0f));
        g.drawText (files[row].getFileName(), 6, 0, width - 12, height, juce::Justification::centredLeft);
    }

    void deleteKeyPressed (int) override { removeSelected(); }
    void listBoxItemDoubleClicked (int row, const juce::MouseEvent&) override
    {
        if (row >= 0 && row < files.size())
        {
            files.remove (row);
            updateUI();
        }
    }

private:
    juce::Array<juce::File> files;
    juce::String currentModel;

    std::unique_ptr<juce::Component> content;
    std::unique_ptr<juce::ListBox> fileList;
    std::unique_ptr<juce::TextButton> addButton, clearButton, processButton;
    std::unique_ptr<juce::Label> statusLabel;
    std::unique_ptr<juce::FileChooser> fileChooser;

    bool isAudioFile (const juce::File& file)
    {
        auto ext = file.getFileExtension().toLowerCase();
        return ext == ".wav" || ext == ".mp3" || ext == ".flac" ||
               ext == ".aiff" || ext == ".ogg" || ext == ".m4a";
    }

    void addFile (const juce::File& file)
    {
        if (! files.contains (file))
            files.add (file);
    }

    void addAudioFilesFromFolder (const juce::File& folder)
    {
        for (const auto& entry : juce::RangedDirectoryIterator (folder, true, "*.wav;*.mp3;*.flac;*.aiff;*.ogg;*.m4a"))
            if (entry.getFile().existsAsFile())
                addFile (entry.getFile());
    }

    void updateUI()
    {
        fileList->updateContent();
        if (files.isEmpty())
        {
            statusLabel->setText ("Drop audio files here", juce::dontSendNotification);
            processButton->setEnabled (false);
        }
        else
        {
            // Calculate total duration estimate
            juce::int64 totalSize = 0;
            for (const auto& f : files)
                totalSize += f.getSize();

            juce::String info = juce::String (files.size()) + " file" + (files.size() > 1 ? "s" : "");
            if (totalSize > 1024 * 1024)
                info += " (" + juce::String::formatted ("%.1f MB", totalSize / (1024.0 * 1024.0)) + ")";

            statusLabel->setText (info + " \u2192 stems saved next to originals", juce::dontSendNotification);
            processButton->setEnabled (true);
        }
    }

    void addFiles()
    {
        fileChooser = std::make_unique<juce::FileChooser> (
            "Select Audio Files",
            juce::File::getSpecialLocation (juce::File::userMusicDirectory),
            "*.wav;*.mp3;*.flac;*.aiff;*.ogg;*.m4a", true);

        fileChooser->launchAsync (
            juce::FileBrowserComponent::openMode |
            juce::FileBrowserComponent::canSelectFiles |
            juce::FileBrowserComponent::canSelectMultipleItems,
            [this] (const juce::FileChooser& fc)
            {
                for (const auto& f : fc.getResults())
                    addFile (f);
                updateUI();
            });
    }

    void removeSelected()
    {
        auto selected = fileList->getSelectedRows();
        for (int i = selected.size() - 1; i >= 0; --i)
            if (selected[i] < files.size())
                files.remove (selected[i]);
        updateUI();
    }

    void startProcessing()
    {
        if (files.isEmpty() || onStartBatch == nullptr)
            return;

        setVisible (false);
        onStartBatch (files, currentModel);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BatchEditorWindow)
};
