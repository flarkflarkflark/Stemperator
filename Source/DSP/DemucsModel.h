#pragma once

#include <JuceHeader.h>

/**
 * DemucsModel - Wrapper for Demucs AI model inference
 *
 * Supports:
 * - LibTorch (PyTorch) backend
 * - ONNX Runtime backend
 * - GPU acceleration (CUDA/ROCm)
 */
class DemucsModel
{
public:
    DemucsModel();
    ~DemucsModel();

    bool loadModel (const juce::File& modelFile);
    bool isLoaded() const { return modelLoaded; }

    void process (const juce::AudioBuffer<float>& input,
                  juce::AudioBuffer<float>& vocals,
                  juce::AudioBuffer<float>& drums,
                  juce::AudioBuffer<float>& bass,
                  juce::AudioBuffer<float>& other);

    juce::String getModelInfo() const { return modelInfo; }
    bool isUsingGPU() const { return gpuEnabled; }

private:
    bool modelLoaded = false;
    bool gpuEnabled = false;
    juce::String modelInfo = "No model loaded";

    // LibTorch or ONNX Runtime handles would go here
    // #if USE_LIBTORCH
    // torch::jit::script::Module model;
    // #endif

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DemucsModel)
};
