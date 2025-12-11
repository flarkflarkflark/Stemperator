/**
 * Custom Standalone Plugin Host
 *
 * Overrides JUCE's default StandaloneFilterWindow to intercept
 * the window close button and show the "unsaved changes" dialog.
 *
 * This file must be compiled when building the Standalone target.
 * CMakeLists.txt must define JUCE_USE_CUSTOM_PLUGIN_STANDALONE_APP=1
 */

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "PluginEditor.h"
#include "BinaryData.h"

// Include the standalone filter window header
#include <juce_audio_plugin_client/Standalone/juce_StandaloneFilterWindow.h>

//==============================================================================
/**
 * Custom StandaloneFilterWindow that intercepts the close button
 */
class StemperatorFilterWindow : public juce::StandaloneFilterWindow
{
public:
    StemperatorFilterWindow (const juce::String& title,
                              juce::Colour backgroundColour,
                              juce::PropertySet* settingsToUse,
                              bool takeOwnershipOfSettings,
                              const juce::String& preferredDefaultDeviceName = juce::String(),
                              const juce::AudioDeviceManager::AudioDeviceSetup* preferredSetupOptions = nullptr,
                              const juce::Array<juce::StandalonePluginHolder::PluginInOuts>& constrainToConfiguration = {},
                              bool autoOpenMidiDevices = false)
        : StandaloneFilterWindow (title, backgroundColour, settingsToUse,
                                   takeOwnershipOfSettings, preferredDefaultDeviceName,
                                   preferredSetupOptions, constrainToConfiguration,
                                   autoOpenMidiDevices)
    {
    }

    void closeButtonPressed() override
    {
        // Try to get the editor and let it handle the quit
        if (auto* holder = getPluginHolder())
        {
            if (auto* processor = holder->processor.get())
            {
                if (auto* editor = dynamic_cast<StemperatorEditor*> (processor->getActiveEditor()))
                {
                    // Invoke the quit command - this will show save dialog if needed
                    juce::ApplicationCommandTarget::InvocationInfo info (StemperatorEditor::cmdQuit);
                    info.invocationMethod = juce::ApplicationCommandTarget::InvocationInfo::direct;
                    editor->perform (info);
                    return;  // Don't proceed with default close - let the command handle it
                }
            }
        }

        // Fallback: use default behavior
        StandaloneFilterWindow::closeButtonPressed();
    }

private:
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorFilterWindow)
};

//==============================================================================
/**
 * Custom StandaloneFilterApp using our custom window
 */
class StemperatorStandaloneFilterApp : public juce::JUCEApplication
{
public:
    StemperatorStandaloneFilterApp() = default;

    const juce::String getApplicationName() override       { return "Stemperator"; }
    const juce::String getApplicationVersion() override    { return "1.0.0"; }
    bool moreThanOneInstanceAllowed() override             { return true; }

    void initialise (const juce::String&) override
    {
        mainWindow = std::make_unique<StemperatorFilterWindow> (
            getApplicationName(),
            juce::LookAndFeel::getDefaultLookAndFeel().findColour (juce::ResizableWindow::backgroundColourId),
            appProperties.getUserSettings(),
            false,  // Don't take ownership of settings
            juce::String(),  // preferredDefaultDeviceName
            nullptr, // preferredSetupOptions
            juce::Array<juce::StandalonePluginHolder::PluginInOuts>(),
            false   // autoOpenMidiDevices
        );

        // Set application icon
        auto iconImage = juce::ImageFileFormat::loadFrom (
            BinaryData::stemperator_256_png, BinaryData::stemperator_256_pngSize);
        if (iconImage.isValid())
            mainWindow->setIcon (iconImage);

        mainWindow->setVisible (true);
    }

    void shutdown() override
    {
        mainWindow = nullptr;
    }

    void systemRequestedQuit() override
    {
        // This is called by the command handler after user confirms quit
        quit();
    }

    void anotherInstanceStarted (const juce::String&) override
    {
        if (mainWindow != nullptr)
            mainWindow->toFront (true);
    }

private:
    juce::ApplicationProperties appProperties;
    std::unique_ptr<StemperatorFilterWindow> mainWindow;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (StemperatorStandaloneFilterApp)
};

//==============================================================================
START_JUCE_APPLICATION (StemperatorStandaloneFilterApp)
