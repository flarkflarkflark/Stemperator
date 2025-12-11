#include "ModelLoader.h"

juce::File ModelLoader::getModelsDirectory()
{
    auto appData = juce::File::getSpecialLocation (juce::File::userApplicationDataDirectory);
    auto modelsDir = appData.getChildFile ("Stemperator").getChildFile ("models");
    modelsDir.createDirectory();
    return modelsDir;
}

juce::Array<ModelLoader::ModelInfo> ModelLoader::getAvailableModels()
{
    juce::Array<ModelInfo> models;

    auto modelsDir = getModelsDirectory();

    // Check for Demucs models
    auto demucsV4 = modelsDir.getChildFile ("htdemucs.onnx");
    models.add ({ "HTDemucs", "v4", demucsV4, demucsV4.getSize(), demucsV4.existsAsFile() });

    auto spleeter = modelsDir.getChildFile ("spleeter_4stems.onnx");
    models.add ({ "Spleeter 4stems", "v2", spleeter, spleeter.getSize(), spleeter.existsAsFile() });

    return models;
}

bool ModelLoader::downloadModel (const juce::String& modelName, std::function<void(float)> progressCallback)
{
    // TODO: Implement model download from repository
    // For now, users need to manually download models

    if (progressCallback)
        progressCallback (0.0f);

    DBG ("Model download not yet implemented: " + modelName);
    return false;
}
