#include "SpectralSeparator.h"

SpectralSeparator::SpectralSeparator() = default;

void SpectralSeparator::prepare (double sr, int)
{
    sampleRate = sr;
}

void SpectralSeparator::process (const juce::AudioBuffer<float>& input,
                                 juce::AudioBuffer<float>& vocals,
                                 juce::AudioBuffer<float>& drums,
                                 juce::AudioBuffer<float>& bass,
                                 juce::AudioBuffer<float>& other)
{
    // TODO: Implement full spectral separation
    // For now, just copy input to other
    other.makeCopyOf (input);
    vocals.clear();
    drums.clear();
    bass.clear();
}
