#include "WaveformView.h"

WaveformView::WaveformView() = default;

void WaveformView::setBuffer (const juce::AudioBuffer<float>* buffer)
{
    audioBuffer = buffer;
    repaint();
}

void WaveformView::paint (juce::Graphics& g)
{
    g.fillAll (juce::Colours::black);

    if (audioBuffer == nullptr || audioBuffer->getNumSamples() == 0)
        return;

    const float width = (float) getWidth();
    const float height = (float) getHeight();
    const float midY = height * 0.5f;

    g.setColour (colour);

    juce::Path waveform;
    const int numSamples = audioBuffer->getNumSamples();
    const float* data = audioBuffer->getReadPointer (0);

    waveform.startNewSubPath (0, midY);

    for (int i = 0; i < numSamples; ++i)
    {
        float x = (float) i / (float) numSamples * width;
        float y = midY - data[i] * midY * 0.9f;
        waveform.lineTo (x, y);
    }

    g.strokePath (waveform, juce::PathStrokeType (1.0f));
}
