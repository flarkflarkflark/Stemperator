#include "StemSeparator.h"
#include <cmath>

StemSeparator::StemSeparator()
{
    // Initialize buffers
    fftBuffer.resize (fftSize * 2, 0.0f);
    spectrumL.resize (numBins);
    spectrumR.resize (numBins);
    spectrumMid.resize (numBins);
    spectrumSide.resize (numBins);
    prevMagnitude.resize (numBins, 0.0f);

    for (int stem = 0; stem < NumStems; ++stem)
    {
        stemSpectraL[stem].resize (numBins);
        stemSpectraR[stem].resize (numBins);
    }

    for (int ch = 0; ch < 2; ++ch)
    {
        inputBuffer[ch].resize (fftSize, 0.0f);
        for (int stem = 0; stem < NumStems; ++stem)
            outputBuffers[stem][ch].resize (fftSize, 0.0f);
    }
}

StemSeparator::~StemSeparator() = default;

void StemSeparator::prepare (double sr, int blockSz)
{
    sampleRate = sr;
    blockSize = blockSz;

    // Resize output stems
    for (auto& stem : stems)
        stem.setSize (2, blockSz);

    reset();
}

void StemSeparator::reset()
{
    inputWritePos = 0;
    outputReadPos = 0;

    for (int ch = 0; ch < 2; ++ch)
    {
        std::fill (inputBuffer[ch].begin(), inputBuffer[ch].end(), 0.0f);
        for (int stem = 0; stem < NumStems; ++stem)
            std::fill (outputBuffers[stem][ch].begin(), outputBuffers[stem][ch].end(), 0.0f);
    }

    std::fill (prevMagnitude.begin(), prevMagnitude.end(), 0.0f);

    for (auto& stem : stems)
        stem.clear();
}

void StemSeparator::process (juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = std::min (buffer.getNumChannels(), 2);

    // Ensure stems are sized correctly
    for (auto& stem : stems)
    {
        if (stem.getNumSamples() != numSamples)
            stem.setSize (2, numSamples, false, false, true);
        stem.clear();
    }

    // Process sample by sample with overlap-add
    for (int i = 0; i < numSamples; ++i)
    {
        // Push input samples to circular buffer
        for (int ch = 0; ch < numChannels; ++ch)
            inputBuffer[ch][inputWritePos] = buffer.getSample (ch, i);

        // Pop output samples from circular buffer
        for (int stem = 0; stem < NumStems; ++stem)
        {
            for (int ch = 0; ch < numChannels; ++ch)
            {
                stems[stem].setSample (ch, i, outputBuffers[stem][ch][outputReadPos]);
                outputBuffers[stem][ch][outputReadPos] = 0.0f;  // Clear after reading
            }
        }

        inputWritePos = (inputWritePos + 1) % fftSize;
        outputReadPos = (outputReadPos + 1) % fftSize;

        // Process FFT frame every hopSize samples
        if (inputWritePos % hopSize == 0)
        {
            // Process each channel
            for (int ch = 0; ch < numChannels; ++ch)
                processFFTFrame (ch);

            // Perform stem separation in frequency domain
            separateStems();

            // Reconstruct each stem
            for (int ch = 0; ch < numChannels; ++ch)
                reconstructStems (ch);
        }
    }
}

void StemSeparator::processFFTFrame (int channel)
{
    // Copy input to FFT buffer (from circular buffer)
    int readPos = (inputWritePos - fftSize + fftSize) % fftSize;
    for (int i = 0; i < fftSize; ++i)
    {
        fftBuffer[i] = inputBuffer[channel][(readPos + i) % fftSize];
        fftBuffer[fftSize + i] = 0.0f;  // Clear imaginary part
    }

    // Apply window
    window.multiplyWithWindowingTable (fftBuffer.data(), fftSize);

    // Forward FFT
    fft.performRealOnlyForwardTransform (fftBuffer.data());

    // Extract spectrum
    auto& spectrum = (channel == 0) ? spectrumL : spectrumR;
    for (int bin = 0; bin < numBins; ++bin)
    {
        float real = fftBuffer[bin * 2];
        float imag = fftBuffer[bin * 2 + 1];
        spectrum[bin] = std::complex<float> (real, imag);
    }
}

void StemSeparator::separateStems()
{
    // Calculate Mid/Side
    for (int bin = 0; bin < numBins; ++bin)
    {
        spectrumMid[bin] = (spectrumL[bin] + spectrumR[bin]) * 0.5f;
        spectrumSide[bin] = (spectrumL[bin] - spectrumR[bin]) * 0.5f;
    }

    // Frequency boundaries
    int bassBin = freqToBin (bassCutoffHz);
    int vocalLowBin = freqToBin (200.0f);
    int vocalHighBin = freqToBin (4000.0f);

    // Separation masks
    std::vector<float> bassMask (numBins, 0.0f);
    std::vector<float> vocalsMask (numBins, 0.0f);
    std::vector<float> drumsMask (numBins, 0.0f);

    for (int bin = 0; bin < numBins; ++bin)
    {
        float freq = binToFreq (bin);
        float midMag = std::abs (spectrumMid[bin]);
        float sideMag = std::abs (spectrumSide[bin]);
        float totalMag = midMag + sideMag + 1e-10f;

        // Bass mask: low-pass with smooth rolloff
        if (bin <= bassBin)
        {
            float rolloff = 1.0f - (float) bin / (float) bassBin * 0.3f;
            bassMask[bin] = rolloff;
        }
        else if (bin < bassBin * 1.5f)
        {
            float t = (float) (bin - bassBin) / (float) (bassBin * 0.5f);
            bassMask[bin] = 1.0f - t;
        }

        // Vocals mask: center-panned content in vocal frequency range
        float centerWeight = midMag / totalMag;  // How centered is this bin?
        if (bin >= vocalLowBin && bin <= vocalHighBin)
        {
            // Vocals are typically centered (high mid, low side)
            float vocalWeight = centerWeight * vocalsFocus + (1.0f - vocalsFocus) * 0.5f;
            vocalsMask[bin] = vocalWeight;
        }

        // Drums mask: transient detection
        float currentMag = std::abs (spectrumL[bin]) + std::abs (spectrumR[bin]);
        float prevMag = prevMagnitude[bin];
        float transient = std::max (0.0f, currentMag - prevMag * 1.2f);
        float steadyState = std::min (currentMag, prevMag);

        // Drums are more transient, less harmonic
        float transientRatio = transient / (currentMag + 1e-10f);
        drumsMask[bin] = transientRatio * drumSensitivity;

        // Update previous magnitude
        prevMagnitude[bin] = currentMag * 0.9f + prevMag * 0.1f;  // Smooth
    }

    // Apply masks and create stem spectra
    for (int bin = 0; bin < numBins; ++bin)
    {
        // Normalize masks to sum to ~1
        float totalMask = bassMask[bin] + vocalsMask[bin] + drumsMask[bin];
        float otherMask = std::max (0.0f, 1.0f - totalMask);

        // Bass (from mid channel mostly - bass is mono)
        float bassGain = bassMask[bin];
        stemSpectraL[Bass][bin] = spectrumMid[bin] * bassGain;
        stemSpectraR[Bass][bin] = spectrumMid[bin] * bassGain;

        // Vocals (from mid channel)
        float vocalsGain = vocalsMask[bin] * (1.0f - bassMask[bin]);
        stemSpectraL[Vocals][bin] = spectrumMid[bin] * vocalsGain;
        stemSpectraR[Vocals][bin] = spectrumMid[bin] * vocalsGain;

        // Drums (transient content from both L+R)
        float drumsGain = drumsMask[bin] * (1.0f - bassMask[bin]) * (1.0f - vocalsMask[bin]);
        stemSpectraL[Drums][bin] = spectrumL[bin] * drumsGain;
        stemSpectraR[Drums][bin] = spectrumR[bin] * drumsGain;

        // Other (residual - everything that's left)
        float otherGain = std::max (0.0f, 1.0f - bassGain - vocalsGain - drumsGain);
        stemSpectraL[Other][bin] = spectrumL[bin] * otherGain + spectrumSide[bin] * (1.0f - vocalsMask[bin]);
        stemSpectraR[Other][bin] = spectrumR[bin] * otherGain - spectrumSide[bin] * (1.0f - vocalsMask[bin]);
    }
}

void StemSeparator::reconstructStems (int channel)
{
    for (int stem = 0; stem < NumStems; ++stem)
    {
        auto& spectrum = (channel == 0) ? stemSpectraL[stem] : stemSpectraR[stem];

        // Pack spectrum into FFT buffer
        for (int bin = 0; bin < numBins; ++bin)
        {
            fftBuffer[bin * 2] = spectrum[bin].real();
            fftBuffer[bin * 2 + 1] = spectrum[bin].imag();
        }

        // Inverse FFT
        fft.performRealOnlyInverseTransform (fftBuffer.data());

        // Apply window and add to output buffer (overlap-add)
        window.multiplyWithWindowingTable (fftBuffer.data(), fftSize);

        int writePos = (outputReadPos) % fftSize;
        float normalization = 1.0f / (float) (fftSize / hopSize) * 0.5f;  // Overlap-add normalization

        for (int i = 0; i < fftSize; ++i)
        {
            int pos = (writePos + i) % fftSize;
            outputBuffers[stem][channel][pos] += fftBuffer[i] * normalization;
        }
    }
}
