#include "SeparationWizard.h"
#include "PremiumLookAndFeel.h"

//==============================================================================
// GoalButton implementation
//==============================================================================
void SeparationWizard::GoalButton::paint (juce::Graphics& g)
{
    auto bounds = getLocalBounds().reduced (4);

    // Background
    if (selected)
    {
        g.setColour (PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        g.fillRoundedRectangle (bounds.toFloat(), 8.0f);
        g.setColour (PremiumLookAndFeel::Colours::accent);
        g.drawRoundedRectangle (bounds.toFloat(), 8.0f, 2.0f);
    }
    else
    {
        g.setColour (PremiumLookAndFeel::Colours::bgPanel);
        g.fillRoundedRectangle (bounds.toFloat(), 8.0f);
        g.setColour (PremiumLookAndFeel::Colours::textDim);
        g.drawRoundedRectangle (bounds.toFloat(), 8.0f, 1.0f);
    }

    bounds.reduce (12, 8);

    // Title
    g.setColour (selected ? PremiumLookAndFeel::Colours::textBright : PremiumLookAndFeel::Colours::textMid);
    g.setFont (juce::FontOptions (14.0f).withStyle ("Bold"));
    g.drawText (info.name, bounds.removeFromTop (20), juce::Justification::centredLeft);

    // Description
    g.setColour (PremiumLookAndFeel::Colours::textDim);
    g.setFont (juce::FontOptions (11.0f));
    g.drawText (info.description, bounds.removeFromTop (16), juce::Justification::centredLeft);

    // Use case
    bounds.removeFromTop (4);
    g.setColour (PremiumLookAndFeel::Colours::textDim.withAlpha (0.7f));
    g.setFont (juce::FontOptions (10.0f).withStyle ("Italic"));
    g.drawText ("Use for: " + info.useCase, bounds.removeFromTop (14), juce::Justification::centredLeft);

    // Output info
    g.setColour (selected ? PremiumLookAndFeel::Colours::accent : PremiumLookAndFeel::Colours::textDim);
    g.setFont (juce::FontOptions (10.0f));
    g.drawText (info.outputDescription, bounds.removeFromTop (14), juce::Justification::centredLeft);
}

//==============================================================================
// QualityOption implementation
//==============================================================================
void SeparationWizard::QualityOption::paint (juce::Graphics& g)
{
    auto bounds = getLocalBounds().reduced (4);

    if (selected)
    {
        g.setColour (PremiumLookAndFeel::Colours::accent.withAlpha (0.3f));
        g.fillRoundedRectangle (bounds.toFloat(), 8.0f);
        g.setColour (PremiumLookAndFeel::Colours::accent);
        g.drawRoundedRectangle (bounds.toFloat(), 8.0f, 2.0f);
    }
    else
    {
        g.setColour (PremiumLookAndFeel::Colours::bgPanel);
        g.fillRoundedRectangle (bounds.toFloat(), 8.0f);
    }

    bounds.reduce (16, 12);

    g.setColour (selected ? PremiumLookAndFeel::Colours::textBright : PremiumLookAndFeel::Colours::textMid);
    g.setFont (juce::FontOptions (14.0f).withStyle ("Bold"));
    g.drawText (info.name, bounds.removeFromTop (20), juce::Justification::centredLeft);

    g.setColour (PremiumLookAndFeel::Colours::textDim);
    g.setFont (juce::FontOptions (11.0f));
    g.drawText (info.description, bounds, juce::Justification::centredLeft);
}

//==============================================================================
// OutputFilesModel implementation
//==============================================================================
void SeparationWizard::OutputFilesModel::paintListBoxItem (int row, juce::Graphics& g, int w, int h, bool selected)
{
    if (row >= files.size())
        return;

    if (selected)
        g.fillAll (PremiumLookAndFeel::Colours::accent.withAlpha (0.2f));

    juce::File file (files[row]);
    g.setColour (PremiumLookAndFeel::Colours::textMid);
    g.setFont (juce::FontOptions (12.0f));
    g.drawText (file.getFileName(), 10, 0, w - 20, h, juce::Justification::centredLeft);
}

//==============================================================================
// SeparationWizard implementation
//==============================================================================
SeparationWizard::SeparationWizard()
{
    // Header setup
    titleLabel.setFont (juce::FontOptions (24.0f).withStyle ("Bold"));
    titleLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textBright);
    addAndMakeVisible (titleLabel);

    subtitleLabel.setFont (juce::FontOptions (12.0f));
    subtitleLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
    addAndMakeVisible (subtitleLabel);

    backButton.onClick = [this]()
    {
        if (currentStep == Step::SelectQuality)
            goToStep (Step::SelectGoal);
        else if (currentStep == Step::SelectFile)
            goToStep (Step::SelectQuality);
    };
    addAndMakeVisible (backButton);

    closeButton.onClick = [this]() { if (onClose) onClose(); };
    addAndMakeVisible (closeButton);

    // Setup goal buttons
    setupGoalButtons();

    // Setup quality options
    setupQualityOptions();

    // File selection
    browseButton.onClick = [this]() { selectFile(); };
    addAndMakeVisible (browseButton);
    addAndMakeVisible (dropZoneLabel);
    addAndMakeVisible (selectedFileLabel);

    // Processing
    addAndMakeVisible (progressBar);
    addAndMakeVisible (progressStatusLabel);
    cancelButton.onClick = [this]() { workflow.cancel(); };
    addAndMakeVisible (cancelButton);

    // Complete
    addAndMakeVisible (completeLabel);
    openFolderButton.onClick = [this]() { outputDir.startAsProcess(); };
    addAndMakeVisible (openFolderButton);
    processAnotherButton.onClick = [this]() { goToStep (Step::SelectGoal); };
    addAndMakeVisible (processAnotherButton);

    outputFilesList.setModel (&outputFilesModel);
    addAndMakeVisible (outputFilesList);

    // Navigation
    nextButton.onClick = [this]()
    {
        if (currentStep == Step::SelectGoal)
            goToStep (Step::SelectQuality);
        else if (currentStep == Step::SelectQuality)
            goToStep (Step::SelectFile);
        else if (currentStep == Step::SelectFile)
            startProcessing();
    };
    addAndMakeVisible (nextButton);

    // Estimated time label
    estimatedTimeLabel.setFont (juce::FontOptions (11.0f));
    estimatedTimeLabel.setColour (juce::Label::textColourId, PremiumLookAndFeel::Colours::textDim);
    addAndMakeVisible (estimatedTimeLabel);

    goToStep (Step::SelectGoal);
    startTimerHz (10);
}

SeparationWizard::~SeparationWizard()
{
    stopTimer();
}

void SeparationWizard::setupGoalButtons()
{
    auto goals = SeparationWorkflow::getAvailableGoals();

    for (const auto& goalInfo : goals)
    {
        auto* btn = goalButtons.add (new GoalButton());
        btn->info = goalInfo;
        btn->onClick = [this, goal = goalInfo.goal]()
        {
            selectedGoal = goal;
            for (auto* b : goalButtons)
                b->selected = (b->info.goal == goal);
            repaint();
        };
        goalContainer.addAndMakeVisible (btn);
    }

    if (! goalButtons.isEmpty())
    {
        goalButtons[0]->selected = true;
        selectedGoal = goalButtons[0]->info.goal;
    }

    goalScrollView.setViewedComponent (&goalContainer, false);
    goalScrollView.setScrollBarsShown (true, false);
    addAndMakeVisible (goalScrollView);
}

void SeparationWizard::setupQualityOptions()
{
    auto qualities = SeparationWorkflow::getQualityOptions();

    for (const auto& qualityInfo : qualities)
    {
        auto* opt = qualityOptions.add (new QualityOption());
        opt->info = qualityInfo;
        opt->onClick = [this, q = qualityInfo.quality]()
        {
            selectedQuality = q;
            for (auto* o : qualityOptions)
                o->selected = (o->info.quality == q);
            repaint();
        };
        addAndMakeVisible (opt);
    }

    // Default to Balanced
    for (auto* opt : qualityOptions)
    {
        if (opt->info.quality == SeparationWorkflow::Quality::Balanced)
            opt->selected = true;
    }
}

void SeparationWizard::goToStep (Step step)
{
    currentStep = step;
    updateStepUI();
    resized();
}

void SeparationWizard::updateStepUI()
{
    // Hide all step-specific components
    goalScrollView.setVisible (false);
    for (auto* opt : qualityOptions)
        opt->setVisible (false);
    estimatedTimeLabel.setVisible (false);
    browseButton.setVisible (false);
    dropZoneLabel.setVisible (false);
    selectedFileLabel.setVisible (false);
    progressBar.setVisible (false);
    progressStatusLabel.setVisible (false);
    cancelButton.setVisible (false);
    completeLabel.setVisible (false);
    openFolderButton.setVisible (false);
    processAnotherButton.setVisible (false);
    outputFilesList.setVisible (false);

    backButton.setVisible (currentStep != Step::SelectGoal && currentStep != Step::Processing);
    nextButton.setVisible (currentStep != Step::Processing && currentStep != Step::Complete);

    switch (currentStep)
    {
        case Step::SelectGoal:
            titleLabel.setText ("What do you want to do?", juce::dontSendNotification);
            subtitleLabel.setText ("Select your goal and we'll use the best settings automatically", juce::dontSendNotification);
            goalScrollView.setVisible (true);
            nextButton.setButtonText ("Next: Choose Quality >");
            break;

        case Step::SelectQuality:
            titleLabel.setText ("Quality vs Speed", juce::dontSendNotification);
            subtitleLabel.setText ("Higher quality takes longer to process", juce::dontSendNotification);
            for (auto* opt : qualityOptions)
                opt->setVisible (true);
            estimatedTimeLabel.setVisible (true);
            nextButton.setButtonText ("Next: Select File >");
            break;

        case Step::SelectFile:
            titleLabel.setText ("Select Audio File", juce::dontSendNotification);
            subtitleLabel.setText ("Drag and drop or browse for your audio file", juce::dontSendNotification);
            browseButton.setVisible (true);
            dropZoneLabel.setVisible (true);
            if (selectedFile.existsAsFile())
            {
                selectedFileLabel.setText ("Selected: " + selectedFile.getFileName(), juce::dontSendNotification);
                selectedFileLabel.setVisible (true);
                nextButton.setButtonText ("Start Processing >");
                nextButton.setEnabled (true);
            }
            else
            {
                nextButton.setButtonText ("Select a file first");
                nextButton.setEnabled (false);
            }
            break;

        case Step::Processing:
            titleLabel.setText ("Processing...", juce::dontSendNotification);
            subtitleLabel.setText ("Please wait while we separate your audio", juce::dontSendNotification);
            progressBar.setVisible (true);
            progressStatusLabel.setVisible (true);
            cancelButton.setVisible (true);
            break;

        case Step::Complete:
            titleLabel.setText ("Complete!", juce::dontSendNotification);
            subtitleLabel.setText ("Your stems are ready", juce::dontSendNotification);
            completeLabel.setVisible (true);
            openFolderButton.setVisible (true);
            processAnotherButton.setVisible (true);
            outputFilesList.setVisible (true);
            break;
    }
}

void SeparationWizard::paint (juce::Graphics& g)
{
    g.fillAll (PremiumLookAndFeel::Colours::bgDark);

    // Header background
    g.setColour (PremiumLookAndFeel::Colours::bgPanel);
    g.fillRect (0, 0, getWidth(), 80);

    // Drop zone in file selection step
    if (currentStep == Step::SelectFile)
    {
        auto dropZone = getLocalBounds().reduced (40).withTrimmedTop (100);
        g.setColour (PremiumLookAndFeel::Colours::bgPanel);
        g.fillRoundedRectangle (dropZone.toFloat(), 12.0f);

        g.setColour (PremiumLookAndFeel::Colours::accent.withAlpha (0.5f));
        float dashLengths[] = { 8.0f, 4.0f };
        g.drawDashedLine (juce::Line<float> (dropZone.toFloat().getTopLeft(), dropZone.toFloat().getTopRight()), dashLengths, 2, 2.0f);
        g.drawDashedLine (juce::Line<float> (dropZone.toFloat().getBottomLeft(), dropZone.toFloat().getBottomRight()), dashLengths, 2, 2.0f);
        g.drawDashedLine (juce::Line<float> (dropZone.toFloat().getTopLeft(), dropZone.toFloat().getBottomLeft()), dashLengths, 2, 2.0f);
        g.drawDashedLine (juce::Line<float> (dropZone.toFloat().getTopRight(), dropZone.toFloat().getBottomRight()), dashLengths, 2, 2.0f);
    }
}

void SeparationWizard::resized()
{
    auto bounds = getLocalBounds();

    // Header
    auto header = bounds.removeFromTop (80).reduced (20, 15);
    closeButton.setBounds (header.removeFromRight (30).removeFromTop (30));
    header.removeFromRight (10);
    backButton.setBounds (header.removeFromLeft (80).removeFromTop (30));

    titleLabel.setBounds (header.removeFromTop (30));
    subtitleLabel.setBounds (header);

    // Footer with navigation
    auto footer = bounds.removeFromBottom (60).reduced (20, 10);
    nextButton.setBounds (footer.removeFromRight (200));

    // Content area
    auto content = bounds.reduced (20);

    switch (currentStep)
    {
        case Step::SelectGoal:
        {
            goalScrollView.setBounds (content);

            int buttonHeight = 85;
            int y = 0;
            for (auto* btn : goalButtons)
            {
                btn->setBounds (0, y, content.getWidth() - 20, buttonHeight);
                y += buttonHeight + 8;
            }
            goalContainer.setSize (content.getWidth() - 20, y);
            break;
        }

        case Step::SelectQuality:
        {
            int optionHeight = 60;
            int y = 0;
            for (auto* opt : qualityOptions)
            {
                opt->setBounds (content.getX(), content.getY() + y, content.getWidth(), optionHeight);
                y += optionHeight + 8;
            }
            estimatedTimeLabel.setBounds (content.getX(), content.getY() + y + 20, content.getWidth(), 24);
            break;
        }

        case Step::SelectFile:
        {
            auto dropZone = content.reduced (20);
            dropZoneLabel.setBounds (dropZone.withSizeKeepingCentre (300, 40));
            browseButton.setBounds (dropZone.withSizeKeepingCentre (150, 36).translated (0, 50));
            selectedFileLabel.setBounds (dropZone.removeFromBottom (30));
            break;
        }

        case Step::Processing:
        {
            auto progressArea = content.withSizeKeepingCentre (400, 100);
            progressBar.setBounds (progressArea.removeFromTop (24));
            progressArea.removeFromTop (10);
            progressStatusLabel.setBounds (progressArea.removeFromTop (24));
            progressArea.removeFromTop (20);
            cancelButton.setBounds (progressArea.withSizeKeepingCentre (100, 30));
            break;
        }

        case Step::Complete:
        {
            completeLabel.setBounds (content.removeFromTop (40));
            content.removeFromTop (20);
            outputFilesList.setBounds (content.removeFromTop (150));
            content.removeFromTop (20);
            auto buttons = content.removeFromTop (36);
            openFolderButton.setBounds (buttons.removeFromLeft (180));
            buttons.removeFromLeft (20);
            processAnotherButton.setBounds (buttons.removeFromLeft (180));
            break;
        }
    }
}

void SeparationWizard::timerCallback()
{
    if (currentStep == Step::Processing)
    {
        progressStatusLabel.setText (currentStatus, juce::dontSendNotification);
        progressBar.repaint();
    }
}

bool SeparationWizard::isInterestedInFileDrag (const juce::StringArray& files)
{
    if (currentStep != Step::SelectFile)
        return false;

    for (const auto& file : files)
    {
        if (file.endsWithIgnoreCase (".wav") ||
            file.endsWithIgnoreCase (".mp3") ||
            file.endsWithIgnoreCase (".flac") ||
            file.endsWithIgnoreCase (".aiff") ||
            file.endsWithIgnoreCase (".ogg"))
            return true;
    }
    return false;
}

void SeparationWizard::filesDropped (const juce::StringArray& files, int, int)
{
    for (const auto& file : files)
    {
        juce::File f (file);
        if (f.existsAsFile())
        {
            selectedFile = f;
            updateStepUI();
            return;
        }
    }
}

void SeparationWizard::selectFile()
{
    auto* chooser = new juce::FileChooser (
        "Select audio file",
        juce::File::getSpecialLocation (juce::File::userMusicDirectory),
        "*.wav;*.mp3;*.flac;*.aiff;*.ogg");

    chooser->launchAsync (juce::FileBrowserComponent::openMode | juce::FileBrowserComponent::canSelectFiles,
        [this, chooser] (const juce::FileChooser& c)
        {
            auto file = c.getResult();
            delete chooser;

            if (file.existsAsFile())
            {
                selectedFile = file;
                updateStepUI();
            }
        });
}

void SeparationWizard::startProcessing()
{
    if (! selectedFile.existsAsFile())
        return;

    // Create output directory
    outputDir = selectedFile.getParentDirectory().getChildFile (
        selectedFile.getFileNameWithoutExtension() + "_stems");

    goToStep (Step::Processing);

    currentProgress = 0.0;
    currentStatus = "Starting...";

    // Use pointers to avoid lambda capture issues
    auto* progressPtr = &currentProgress;
    auto* statusPtr = &currentStatus;

    workflow.startSeparation (
        selectedFile,
        outputDir,
        selectedGoal,
        selectedQuality,
        SeparationWorkflow::OutputFormat::WAV_24bit,
        [progressPtr, statusPtr] (float progress, const juce::String& status)
        {
            *progressPtr = static_cast<double> (progress);
            *statusPtr = status;
        },
        [this] (const SeparationWorkflow::SeparationResult& result)
        {
            juce::MessageManager::callAsync ([this, result]() {
                handleCompletion (result);
            });
        });
}

void SeparationWizard::handleCompletion (const SeparationWorkflow::SeparationResult& result)
{
    lastResult = result;

    if (result.success)
    {
        outputFilesModel.files = result.outputFiles;
        outputFilesList.updateContent();

        juce::String summary = "Created " + juce::String (result.outputFiles.size()) + " stems in "
                               + juce::String (result.processingTimeSeconds, 1) + " seconds";
        completeLabel.setText (summary, juce::dontSendNotification);

        goToStep (Step::Complete);

        if (onComplete)
            onComplete (outputDir);
    }
    else
    {
        juce::AlertWindow::showMessageBoxAsync (
            juce::MessageBoxIconType::WarningIcon,
            "Separation Failed",
            result.errorMessage);

        goToStep (Step::SelectFile);
    }
}
