#pragma once

#include <JuceHeader.h>

/**
 * ModelLoader - Manages AI model files
 *
 * Handles:
 * - Finding model files in standard locations
 * - Downloading models from repository
 * - Model version management
 */
class ModelLoader
{
public:
    struct ModelInfo
    {
        juce::String name;
        juce::String version;
        juce::File path;
        int64_t sizeBytes;
        bool isDownloaded;
    };

    static juce::Array<ModelInfo> getAvailableModels();
    static juce::File getModelsDirectory();
    static bool downloadModel (const juce::String& modelName, std::function<void(float)> progressCallback = nullptr);
};
