#include "PluginProcessor.h"
#include "PluginEditor.h"

StemperatorProcessor::StemperatorProcessor()
    : AudioProcessor (BusesProperties()
                      .withInput  ("Input",  juce::AudioChannelSet::stereo(), true)
                      .withOutput ("Output", juce::AudioChannelSet::stereo(), true))
{
}

StemperatorProcessor::~StemperatorProcessor() = default;

void StemperatorProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    separator.prepare (sampleRate, samplesPerBlock);
}

void StemperatorProcessor::releaseResources()
{
    separator.reset();
}

bool StemperatorProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
    return layouts.getMainOutputChannelSet() == juce::AudioChannelSet::stereo()
        && layouts.getMainInputChannelSet() == juce::AudioChannelSet::stereo();
}

void StemperatorProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer&)
{
    juce::ScopedNoDenormals noDenormals;

    // Process through separator
    separator.process (buffer);

    // Apply stem mixing
    bool anySolo = std::any_of (stemSolos.begin(), stemSolos.end(), [](bool s) { return s; });

    auto& stems = separator.getStems();
    buffer.clear();

    for (int stem = 0; stem < NumStems; ++stem)
    {
        bool shouldPlay = anySolo ? stemSolos[stem] : !stemMutes[stem];

        if (shouldPlay && stems[stem].getNumSamples() >= buffer.getNumSamples())
        {
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                buffer.addFrom (ch, 0, stems[stem], ch, 0, buffer.getNumSamples(), stemLevels[stem]);
        }
    }
}

juce::AudioProcessorEditor* StemperatorProcessor::createEditor()
{
    return new StemperatorEditor (*this);
}

void StemperatorProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    juce::MemoryOutputStream stream (destData, true);
    for (int i = 0; i < NumStems; ++i)
    {
        stream.writeFloat (stemLevels[i]);
        stream.writeBool (stemMutes[i]);
        stream.writeBool (stemSolos[i]);
    }
}

void StemperatorProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    juce::MemoryInputStream stream (data, static_cast<size_t> (sizeInBytes), false);
    for (int i = 0; i < NumStems; ++i)
    {
        if (stream.getNumBytesRemaining() >= sizeof(float) + 2)
        {
            stemLevels[i] = stream.readFloat();
            stemMutes[i] = stream.readBool();
            stemSolos[i] = stream.readBool();
        }
    }
}

juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new StemperatorProcessor();
}
