#pragma once

#include <JuceHeader.h>
#include "PremiumLookAndFeel.h"

/**
 * BatchEditorWindow - Reaper-style batch stem processor
 *
 * Simple, efficient layout like Reaper's batch converter:
 * - File list at top (ListBox with simple filename display)
 * - Add/Remove buttons below list
 * - Output settings at bottom
 * - Start button
 */
class BatchEditorWindow : public juce::DocumentWindow,
                          public juce::FileDragAndDropTarget,
                          public juce::ListBoxModel
{
public:
    // Callback when user starts batch processing
    std::function<void (const juce::Array<juce::File>& files,
                        const juce::File& outputFolder,
                        const juce::String& modelName)> onStartBatch;

    BatchEditorWindow (const juce::File& defaultOutputFolder, int currentQuality, bool is6StemModel)
        : juce::DocumentWindow ("Batch Stem Processor",
                                PremiumLookAndFeel::Colours::bgDark,
                                juce::DocumentWindow::closeButton),
          outputFolder (defaultOutputFolder),
          quality (currentQuality),
          use6Stems (is6StemModel)
    {
        setUsingNativeTitleBar (false);
        setTitleBarHeight (40);  // Taller title bar
        setResizable (true, true);
        setSize (700, 500);
        centreWithSize (getWidth(), getHeight());

        // Main content
        content = std::make_unique<juce::Component>();
        setContentOwned (content.get(), false);

        // Title label
        titleLabel = std::make_unique<juce::Label> ("", "Source Files:");
        titleLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
        titleLabel->setFont (juce::FontOptions (15.0f).withStyle ("Bold"));
        content->addAndMakeVisible (titleLabel.get());

        // File list (simple ListBox like Reaper)
        fileList = std::make_unique<juce::ListBox> ("Files", this);
        fileList->setColour (juce::ListBox::backgroundColourId, PremiumLookAndFeel::Colours::bgPanel);
        fileList->setColour (juce::ListBox::outlineColourId, PremiumLookAndFeel::Colours::accent.withAlpha (0.4f));
        fileList->setOutlineThickness (1);
        fileList->setRowHeight (22);
        fileList->setMultipleSelectionEnabled (true);
        content->addAndMakeVisible (fileList.get());

        // Add/Remove buttons (Reaper style - side by side)
        addButton = std::make_unique<juce::TextButton> ("Add...");
        addButton->onClick = [this] { addFiles(); };
        content->addAndMakeVisible (addButton.get());

        addFolderButton = std::make_unique<juce::TextButton> ("Add Folder...");
        addFolderButton->onClick = [this] { addFolder(); };
        content->addAndMakeVisible (addFolderButton.get());

        removeButton = std::make_unique<juce::TextButton> ("Remove");
        removeButton->onClick = [this] { removeSelected(); };
        removeButton->setEnabled (false);
        content->addAndMakeVisible (removeButton.get());

        clearButton = std::make_unique<juce::TextButton> ("Clear");
        clearButton->onClick = [this] { clearAll(); };
        content->addAndMakeVisible (clearButton.get());

        // Separator line (visual)
        separatorLabel = std::make_unique<juce::Label> ("");
        content->addAndMakeVisible (separatorLabel.get());

        // Output section
        outputTitleLabel = std::make_unique<juce::Label> ("", "Output:");
        outputTitleLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
        outputTitleLabel->setFont (juce::FontOptions (15.0f).withStyle ("Bold"));
        content->addAndMakeVisible (outputTitleLabel.get());

        outputPathLabel = std::make_unique<juce::Label> ("", outputFolder.getFullPathName());
        outputPathLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textMid);
        outputPathLabel->setColour (juce::Label::backgroundColourId, PremiumLookAndFeel::Colours::bgDark);
        outputPathLabel->setJustificationType (juce::Justification::centredLeft);
        content->addAndMakeVisible (outputPathLabel.get());

        browseButton = std::make_unique<juce::TextButton> ("...");
        browseButton->onClick = [this] { browseOutputFolder(); };
        content->addAndMakeVisible (browseButton.get());

        // Settings row
        qualityLabel = std::make_unique<juce::Label> ("", "Quality:");
        qualityLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textMid);
        content->addAndMakeVisible (qualityLabel.get());

        qualityBox = std::make_unique<juce::ComboBox>();
        qualityBox->addItem ("Fast", 1);
        qualityBox->addItem ("Balanced", 2);
        qualityBox->addItem ("Best", 3);
        qualityBox->setSelectedId (quality + 1);
        content->addAndMakeVisible (qualityBox.get());

        modelLabel = std::make_unique<juce::Label> ("", "Model:");
        modelLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textMid);
        content->addAndMakeVisible (modelLabel.get());

        modelBox = std::make_unique<juce::ComboBox>();
        modelBox->addItem ("4 Stems", 1);
        modelBox->addItem ("6 Stems", 2);
        modelBox->setSelectedId (use6Stems ? 2 : 1);
        content->addAndMakeVisible (modelBox.get());

        // Status/count label
        statusLabel = std::make_unique<juce::Label> ("", "Drop files here or click Add...");
        statusLabel->setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
        statusLabel->setFont (juce::FontOptions (13.0f));
        content->addAndMakeVisible (statusLabel.get());

        // Action buttons
        cancelButton = std::make_unique<juce::TextButton> ("Cancel");
        cancelButton->onClick = [this] { closeButtonPressed(); };
        content->addAndMakeVisible (cancelButton.get());

        startButton = std::make_unique<juce::TextButton> ("Start");
        startButton->setColour (juce::TextButton::buttonColourId, PremiumLookAndFeel::Colours::active.darker (0.2f));
        startButton->onClick = [this] { startBatch(); };
        startButton->setEnabled (false);
        content->addAndMakeVisible (startButton.get());

        setVisible (true);
    }

    ~BatchEditorWindow() override = default;

    void closeButtonPressed() override
    {
        setVisible (false);
    }

    void resized() override
    {
        juce::DocumentWindow::resized();

        if (content == nullptr)
            return;

        auto bounds = content->getLocalBounds().reduced (12);
        int buttonHeight = 28;
        int rowSpacing = 8;

        // Title
        titleLabel->setBounds (bounds.removeFromTop (22));
        bounds.removeFromTop (4);

        // File list (main area - takes most space)
        auto listHeight = bounds.getHeight() - 180;
        fileList->setBounds (bounds.removeFromTop (listHeight));
        bounds.removeFromTop (rowSpacing);

        // Add/Remove button row
        auto buttonRow = bounds.removeFromTop (buttonHeight);
        addButton->setBounds (buttonRow.removeFromLeft (70));
        buttonRow.removeFromLeft (6);
        addFolderButton->setBounds (buttonRow.removeFromLeft (90));
        buttonRow.removeFromLeft (12);
        removeButton->setBounds (buttonRow.removeFromLeft (70));
        buttonRow.removeFromLeft (6);
        clearButton->setBounds (buttonRow.removeFromLeft (60));

        bounds.removeFromTop (rowSpacing + 4);

        // Separator (just spacing)
        bounds.removeFromTop (1);

        // Output title
        outputTitleLabel->setBounds (bounds.removeFromTop (22));
        bounds.removeFromTop (4);

        // Output path row
        auto outputRow = bounds.removeFromTop (buttonHeight);
        browseButton->setBounds (outputRow.removeFromRight (36));
        outputRow.removeFromRight (6);
        outputPathLabel->setBounds (outputRow);

        bounds.removeFromTop (rowSpacing);

        // Settings row
        auto settingsRow = bounds.removeFromTop (buttonHeight);
        qualityLabel->setBounds (settingsRow.removeFromLeft (55));
        qualityBox->setBounds (settingsRow.removeFromLeft (95));
        settingsRow.removeFromLeft (16);
        modelLabel->setBounds (settingsRow.removeFromLeft (50));
        modelBox->setBounds (settingsRow.removeFromLeft (90));

        bounds.removeFromTop (rowSpacing);

        // Status label
        statusLabel->setBounds (bounds.removeFromTop (20));

        // Action buttons at very bottom
        bounds.removeFromTop (rowSpacing);
        auto actionRow = bounds.removeFromTop (34);
        startButton->setBounds (actionRow.removeFromRight (90));
        actionRow.removeFromRight (8);
        cancelButton->setBounds (actionRow.removeFromRight (80));
    }

    void paint (juce::Graphics& g) override
    {
        juce::DocumentWindow::paint (g);

        if (content != nullptr)
        {
            auto bounds = content->getLocalBounds();
            g.setColour (PremiumLookAndFeel::Colours::bgMid);
            g.fillRect (bounds);
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
        updateStatus();
        fileList->updateContent();
    }

    // ListBoxModel
    int getNumRows() override { return files.size(); }

    void paintListBoxItem (int rowNumber, juce::Graphics& g, int width, int height, bool rowIsSelected) override
    {
        if (rowNumber >= files.size())
            return;

        if (rowIsSelected)
            g.fillAll (PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        else if (rowNumber % 2)
            g.fillAll (PremiumLookAndFeel::Colours::bgDark.withAlpha (0.2f));

        g.setColour (PremiumLookAndFeel::Colours::textBright);
        g.setFont (juce::FontOptions (13.0f));
        g.drawText (files[rowNumber].getFileName(), 8, 0, width - 16, height, juce::Justification::centredLeft);
    }

    void selectedRowsChanged (int) override
    {
        removeButton->setEnabled (fileList->getNumSelectedRows() > 0);
    }

    void listBoxItemDoubleClicked (int row, const juce::MouseEvent&) override
    {
        // Remove on double-click (like Reaper)
        if (row >= 0 && row < files.size())
        {
            files.remove (row);
            updateStatus();
            fileList->updateContent();
        }
    }

private:
    juce::Array<juce::File> files;
    juce::File outputFolder;
    int quality;
    bool use6Stems;

    std::unique_ptr<juce::Component> content;
    std::unique_ptr<juce::Label> titleLabel;
    std::unique_ptr<juce::ListBox> fileList;
    std::unique_ptr<juce::TextButton> addButton, addFolderButton, removeButton, clearButton;
    std::unique_ptr<juce::Label> separatorLabel;
    std::unique_ptr<juce::Label> outputTitleLabel, outputPathLabel;
    std::unique_ptr<juce::TextButton> browseButton;
    std::unique_ptr<juce::Label> qualityLabel, modelLabel;
    std::unique_ptr<juce::ComboBox> qualityBox, modelBox;
    std::unique_ptr<juce::Label> statusLabel;
    std::unique_ptr<juce::TextButton> cancelButton, startButton;
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
        {
            if (entry.getFile().existsAsFile())
                addFile (entry.getFile());
        }
    }

    void updateStatus()
    {
        if (files.isEmpty())
        {
            statusLabel->setText ("Drop files here or click Add...", juce::dontSendNotification);
            startButton->setEnabled (false);
        }
        else
        {
            juce::int64 totalSize = 0;
            for (const auto& f : files)
                totalSize += f.getSize();

            juce::String sizeStr;
            if (totalSize < 1024 * 1024)
                sizeStr = juce::String (totalSize / 1024) + " KB";
            else
                sizeStr = juce::String::formatted ("%.1f MB", totalSize / (1024.0 * 1024.0));

            statusLabel->setText (juce::String (files.size()) + " file(s), " + sizeStr + " total",
                                  juce::dontSendNotification);
            startButton->setEnabled (true);
        }
    }

    void addFiles()
    {
        fileChooser = std::make_unique<juce::FileChooser> (
            "Add Audio Files",
            juce::File::getSpecialLocation (juce::File::userMusicDirectory),
            "*.wav;*.mp3;*.flac;*.aiff;*.ogg;*.m4a",
            true);

        fileChooser->launchAsync (
            juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles |
            juce::FileBrowserComponent::canSelectMultipleItems,
            [this] (const juce::FileChooser& fc)
            {
                for (const auto& f : fc.getResults())
                    addFile (f);
                updateStatus();
                fileList->updateContent();
            });
    }

    void addFolder()
    {
        fileChooser = std::make_unique<juce::FileChooser> (
            "Add Folder",
            juce::File::getSpecialLocation (juce::File::userMusicDirectory),
            "",
            true);

        fileChooser->launchAsync (
            juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories,
            [this] (const juce::FileChooser& fc)
            {
                auto folder = fc.getResult();
                if (folder.isDirectory())
                    addAudioFilesFromFolder (folder);
                updateStatus();
                fileList->updateContent();
            });
    }

    void removeSelected()
    {
        auto selectedRows = fileList->getSelectedRows();
        for (int i = selectedRows.size() - 1; i >= 0; --i)
        {
            int row = selectedRows[i];
            if (row < files.size())
                files.remove (row);
        }
        updateStatus();
        fileList->updateContent();
    }

    void clearAll()
    {
        files.clear();
        updateStatus();
        fileList->updateContent();
    }

    void browseOutputFolder()
    {
        fileChooser = std::make_unique<juce::FileChooser> (
            "Select Output Folder",
            outputFolder,
            "",
            true);

        fileChooser->launchAsync (
            juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectDirectories,
            [this] (const juce::FileChooser& fc)
            {
                auto folder = fc.getResult();
                if (folder.isDirectory())
                {
                    outputFolder = folder;
                    outputPathLabel->setText (folder.getFullPathName(), juce::dontSendNotification);
                }
            });
    }

    void startBatch()
    {
        if (files.isEmpty() || onStartBatch == nullptr)
            return;

        // Get model name
        int qualityIndex = qualityBox->getSelectedId() - 1;
        bool is6Stem = modelBox->getSelectedId() == 2;

        juce::String modelName;
        if (is6Stem)
            modelName = "htdemucs_6s";
        else if (qualityIndex >= 2)
            modelName = "htdemucs_ft";
        else
            modelName = "htdemucs";

        // Close and start
        setVisible (false);
        onStartBatch (files, outputFolder, modelName);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BatchEditorWindow)
};
