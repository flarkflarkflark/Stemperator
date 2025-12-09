#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "GUI/StemChannel.h"
#include "GUI/PremiumLookAndFeel.h"
#include "GUI/StyledDialogWindow.h"
#include "GUI/BatchEditorWindow.h"
#include "GUI/TransportBar.h"
#include "GUI/ExportOptionsDialog.h"
#include "GUI/UISettingsDialog.h"

//==============================================================================
// Colorful Mode Label - draws "STEMS" or "LIVE" with colored letters, clickable to toggle
class ColorfulModeLabel : public juce::Label
{
public:
    ColorfulModeLabel() { setOpaque (false); }

    void paint (juce::Graphics& g) override;
    void mouseEnter (const juce::MouseEvent&) override;
    void mouseExit (const juce::MouseEvent&) override;
    void mouseUp (const juce::MouseEvent& e) override;

    void setCanToggle (bool toggle)
    {
        canToggle = toggle;
        if (canToggle)
            setTooltip ("Click to switch between LIVE and STEMS mode");
        else
            setTooltip ("");
        repaint();
    }

    std::function<void()> onClick;

private:
    bool canToggle = false;
};

/**
 * StemperatorEditor - Premium plugin GUI with scalable layout
 *
 * FabFilter-inspired design with famous scalable tweaks:
 * - Proportional scaling for all elements
 * - Font sizes adapt to window size
 * - Works great from 600x400 to 1600x1000
 * - Maintains visual balance at any size
 *
 * Standalone mode adds:
 * - File menu for loading audio files
 * - Export menu for saving separated stems
 * - Transport controls for playback
 */
class StemperatorEditor : public juce::AudioProcessorEditor,
                          public juce::Timer,
                          public juce::MenuBarModel,
                          public juce::ApplicationCommandTarget,
                          public juce::KeyListener,
                          public juce::FileDragAndDropTarget
{
public:
    explicit StemperatorEditor (StemperatorProcessor&);
    ~StemperatorEditor() override;

    void paint (juce::Graphics&) override;
    void resized() override;
    void timerCallback() override;
    void parentHierarchyChanged() override;
    void visibilityChanged() override;

    // KeyListener - for Escape to cancel
    bool keyPressed (const juce::KeyPress& key, juce::Component* originatingComponent) override;

    // Mouse click to grab keyboard focus
    void mouseDown (const juce::MouseEvent& event) override;

    // FileDragAndDropTarget - for drag & drop audio files
    bool isInterestedInFileDrag (const juce::StringArray& files) override;
    void filesDropped (const juce::StringArray& files, int x, int y) override;

    // MenuBarModel interface
    juce::StringArray getMenuBarNames() override;
    juce::PopupMenu getMenuForIndex (int menuIndex, const juce::String& menuName) override;
    void menuItemSelected (int menuItemID, int topLevelMenuIndex) override;

    // ApplicationCommandTarget interface
    juce::ApplicationCommandTarget* getNextCommandTarget() override { return nullptr; }
    void getAllCommands (juce::Array<juce::CommandID>& commands) override;
    void getCommandInfo (juce::CommandID commandID, juce::ApplicationCommandInfo& result) override;
    bool perform (const juce::ApplicationCommandTarget::InvocationInfo& info) override;

    // Check if running as standalone (not in a DAW)
    bool isStandalone() const;

    // Grab keyboard focus when mouse enters the window
    void mouseEnter (const juce::MouseEvent&) override { grabKeyboardFocus(); }

    // Command IDs for menu actions (public for StandaloneFilterApp access)
    enum CommandIDs
    {
        cmdLoadFile = 1,
        cmdSeparate,         // Separate file into stems (load into memory for playback)
        cmdLoadStems,        // Load previously exported stems
        cmdBatchProcess,     // Batch process multiple files
        cmdSaveProject,      // Quick save to current project file
        cmdSaveProjectAs,    // Save project as new .stemperator file
        cmdLoadProject,      // Load .stemperator project file
        cmdExportAllStems,
        cmdExportVocals,
        cmdExportDrums,
        cmdExportBass,
        cmdExportOther,
        cmdExportGuitar,     // Guitar stem (6-stem model only)
        cmdExportPiano,      // Piano stem (6-stem model only)
        cmdExportMix,        // Export mixed stems with current volume/mute settings
        cmdPlay,             // Play (stems if available, otherwise original)
        cmdStop,
        cmdSetDefaultStemFolder,  // Set default folder for stem export
        cmdResetStems,       // Reset all stem faders to 0 dB
        cmdDeleteStems,      // Delete separated stems from memory and disk
        cmdUndo,             // Undo last action
        cmdRedo,             // Redo last undone action
        cmdAbout,
        cmdHelpPage,         // Open Help page with documentation
        cmdUISettings,       // Open UI Settings dialog
        cmdQuit              // Exit the application
    };

private:
    StemperatorProcessor& processor;
    PremiumLookAndFeel premiumLookAndFeel;
    juce::TooltipWindow tooltipWindow { this, 500 };  // 500ms delay before showing

    // Base dimensions for scaling calculations (100% = 1440x810, was 75% of 1920x1080)
    static constexpr int baseWidth = 1440;
    static constexpr int baseHeight = 810;

    // Get current scale factor
    float getScaleFactor() const
    {
        float scaleX = (float) getWidth() / baseWidth;
        float scaleY = (float) getHeight() / baseHeight;
        return juce::jmin (scaleX, scaleY);  // Use smaller to maintain aspect
    }

    // Scale a value based on current size
    int scaled (int value) const { return juce::roundToInt (value * getScaleFactor()); }
    float scaled (float value) const { return value * getScaleFactor(); }

    // Stem channels (supports up to 6 for htdemucs_6s model)
    std::array<std::unique_ptr<StemChannel>, 6> stemChannels;

    // Master section
    juce::Slider masterSlider;
    juce::Label masterLabel { {}, "MASTER" };
    juce::TextButton masterMuteButton { "M" };
    juce::TextButton masterSoloButton { "S" };
    juce::TextButton resetAllButton { "RESET" };  // Reset all stem faders to 0 dB
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

    // Quality selector (three-way toggle button: Fast/Balanced/Best)
    juce::TextButton qualityButton { "Balanced" };
    juce::Label qualityLabel { {}, "QUALITY/MODEL" };  // Combined label
    int currentQuality = 1;  // 0=Fast, 1=Balanced, 2=Best
    void onQualityButtonClicked();

    // Model selector (4-stem vs 6-stem)
    juce::ComboBox modelBox;
    void onModelChanged();

    // Scale selector (25% to 400%) - ComboBox
    juce::ComboBox scaleBox;
    juce::Label scaleLabel { {}, "SCALE UI" };
    void onScaleChanged();

    // Header components
    juce::Label titleLabel { {}, "STEMPERATOR" };
    juce::Label subtitleLabel { {}, "AI-POWERED STEM SEPARATION" };
    juce::Label brandLabel { {}, "flarkAUDIO" };

    // Colours (6 colors for 6-stem model support)
    const std::array<juce::Colour, 6> stemColours = {
        PremiumLookAndFeel::Colours::vocals,
        PremiumLookAndFeel::Colours::drums,
        PremiumLookAndFeel::Colours::bass,
        PremiumLookAndFeel::Colours::other,
        PremiumLookAndFeel::Colours::guitar,
        PremiumLookAndFeel::Colours::piano
    };

    void setupSlider (juce::Slider& slider, juce::Colour colour);
    void setupKnob (juce::Slider& slider, juce::Label& label, const juce::String& text, juce::Colour colour);
    void updateFontSizes();

    // File menu functionality
    void loadAudioFile();
    void loadAudioFile (const juce::File& file);  // Load specific file
    void exportStems (int stemIndex = -1);  // -1 = all stems
    void exportMixedStems();  // Export stems merged with current volume/mute settings
    void showExportProgress (const juce::String& message);
    void batchProcessFiles();  // Process multiple audio files
    void loadStemsAfterExport (const juce::File& folder);  // Load stems into playback after export
    void saveProject();        // Quick save to current project file (or Save As if no file)
    void saveProjectAs();      // Save project as new .stemperator file
    void saveProjectToFile (const juce::File& file);  // Internal: write project to file
    void loadProject();        // Load .stemperator project file
    void loadProject (const juce::File& file);  // Load specific project file

    // Standalone-specific components
    std::unique_ptr<juce::MenuBarComponent> menuBar;
    juce::ApplicationCommandManager commandManager;

    // Audio file handling for standalone
    std::unique_ptr<juce::AudioFormatManager> formatManager;
    std::unique_ptr<juce::AudioFormatReaderSource> readerSource;
    std::unique_ptr<juce::FileChooser> fileChooser;  // Keep alive during async operation
    juce::AudioTransportSource transportSource;
    juce::File currentAudioFile;
    juce::AudioBuffer<float> loadedAudioBuffer;
    double loadedSampleRate = 44100.0;
    bool hasLoadedFile = false;

    // Loudness normalization
    float normalizeGain = 1.0f;           // Gain to apply for normalization
    float measuredLUFS = -14.0f;          // Measured integrated loudness
    static constexpr float targetLUFS = -14.0f;  // Target loudness (Spotify/YouTube standard)
    static constexpr float maxNormalizeGain = 12.0f;  // Max +12 dB boost for quiet tracks
    void calculateNormalizationGain();    // Measure loudness and calculate gain

    // Separated stem playback (supports up to 6 stems)
    std::array<juce::AudioBuffer<float>, 6> separatedStems;  // Vocals, Drums, Bass, Other, Guitar, Piano
    bool hasSeparatedStems = false;
    bool playingStemsMode = false;  // true = playing stems, false = playing original (LIVE mode)
    juce::File lastStemFolder;  // Remember where stems were exported
    juce::File lastAudioFolder;  // Remember where audio files were loaded from
    juce::File defaultStemFolder;  // User-configurable default folder for stem export
    juce::File defaultProjectFolder;  // User-configurable default folder for project save
    juce::File defaultBatchFolder;  // User-configurable default folder for batch output
    juce::File currentProjectFile;  // Current .stemperator project file (for quick save)
    bool projectNeedsSave = false;  // Track if project has unsaved changes
    juce::StringArray recentStemFolders;  // Recently stemmed folders (max 10)
    juce::StringArray recentProjects;     // Recently saved/loaded project files (max 10)
    juce::StringArray recentBatchOutputFolders;  // Recently used batch output folders (max 10)
    static constexpr int maxRecentFolders = 10;

    // Persistent settings
    std::unique_ptr<juce::PropertiesFile> appSettings;
    juce::Rectangle<int> savedWindowBounds;  // Saved window position/size for multi-monitor support
    bool windowPositionApplied = false;      // Flag to apply position only once
    void loadSettings();
    void saveSettings();
    void addToRecentStems (const juce::File& folder);  // Add folder to recent list
    void addToRecentProjects (const juce::File& projectFile);  // Add project to recent list
    void addToRecentBatchOutputFolders (const juce::File& folder);  // Add batch output folder to recent list

    // Stem mixer for playback
    class StemMixerSource;
    std::unique_ptr<StemMixerSource> stemMixerSource;

    void separateCurrentFile();  // Separate without exporting
    void loadStemsFromFolder (const juce::File& folder);  // Load previously exported stems
    void loadStemsWithPrefix (const juce::File& folder, const juce::String& prefix);  // Load specific song stems
    void updateStemPlayback();  // Apply mute/solo/volume to playback

    // Export state
    std::atomic<bool> isExporting { false };
    std::atomic<bool> cancelExport { false };
    std::atomic<float> exportProgress { 0.0f };
    std::array<std::atomic<float>, 6> exportStemLevels;  // For visual feedback (6-stem support)

    // Quit after save flag (for Save on quit flow)
    bool quitAfterSave = false;

    // Transport controls (standalone only)
    std::unique_ptr<TransportBar> transportBar;
    std::unique_ptr<juce::Label> fileNameLabel;
    std::unique_ptr<ColorfulModeLabel> modeLabel;  // Shows "STEMS" or "LIVE" mode, clickable toggle
    std::unique_ptr<juce::TextButton> deleteStemsButton;  // Delete STEMS button (red, only visible in STEMS mode)
    bool wasPlayingBeforeSeek = false;
    double previousMasterGain = 0.0;  // For mute/unmute restoration

    // Master VU meter
    float masterCurrentLevel = 0.0f;
    float masterDisplayLevel = 0.0f;
    float masterPeakLevel = 0.0f;
    int masterPeakHoldCount = 0;
    static constexpr int masterPeakHoldTime = 30;  // ~1 second at 30fps

    void setupTransportControls();
    void updateTransportDisplay();
    void updateModeIndicator();  // Update mode label based on current playback mode
    void togglePlaybackMode();   // Toggle between STEMS and LIVE mode
    void deleteStems();          // Delete separated stems from memory and disk
    void refreshWindowTitle();   // Update window title with current state (file, [STEMMED], unsaved*)
    void resetFileNameLabel();   // Reset to standard label for progress messages
    void setStemsLoadedMessage();  // Set colorful "STEMS" message
    void setLiveLoadedMessage();  // Set colorful "LIVE" message

    // Undo/Redo support - simple single-action undo for Delete STEMS
    juce::UndoManager undoManager { 10000, 30 };  // 10KB max, 30 actions max
    std::array<juce::AudioBuffer<float>, 6> undoStemBackup;  // Backup for undo
    juce::File undoStemFolder;           // Folder where stems were
    bool undoWasPlayingStemsMode = false;
    bool hasUndoableAction = false;
    juce::String undoActionName;

    void performUndo();
    void performRedo();

    // Python environment finding utility
    struct PythonEnvironment
    {
        juce::File projectRoot;
        juce::File pythonExe;
        juce::File separatorScript;
        bool isValid() const { return pythonExe.existsAsFile() && separatorScript.existsAsFile(); }
    };
    PythonEnvironment findPythonEnvironment() const;

    // Batch processing window (reused, just shown/hidden)
    std::unique_ptr<BatchEditorWindow> batchEditorWindow;
    void showBatchWindow();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorEditor)
};
