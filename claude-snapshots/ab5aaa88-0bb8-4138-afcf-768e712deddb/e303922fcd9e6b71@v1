#include "MatrixFilterVST_processor.h"
#include "pluginterfaces/vst/ivstparameterchanges.h"
#include "pluginterfaces/base/ibstream.h"
#include "base/source/fstreamer.h"
#include <algorithm>
#include <cmath>

namespace Steinberg {
namespace MatrixFilterVST {

//------------------------------------------------------------------------
// MatrixFilterProcessor
//------------------------------------------------------------------------
MatrixFilterProcessor::MatrixFilterProcessor()
    : currentFilterType(FILTER_TYPE_LOWPASS)
    , currentCutoff(1000.0f)
    , currentResonance(0.707f)
    , currentGain(1.0f)
{
    setControllerClass(ControllerUID);
}

//------------------------------------------------------------------------
MatrixFilterProcessor::~MatrixFilterProcessor()
{
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::initialize(FUnknown* context)
{
    tresult result = AudioEffect::initialize(context);
    if (result != kResultOk) {
        return result;
    }

    // Add stereo audio input/output
    addAudioInput(STR16("Stereo In"), Vst::SpeakerArr::kStereo);
    addAudioOutput(STR16("Stereo Out"), Vst::SpeakerArr::kStereo);

    return kResultOk;
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::terminate()
{
    return AudioEffect::terminate();
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::setActive(TBool state)
{
    if (state) {
        // Initialize filters when activated
        filter_init(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain, (float)processSetup.sampleRate);
        filter_init(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain, (float)processSetup.sampleRate);
    } else {
        // Reset filters when deactivated
        filter_reset(&filterL);
        filter_reset(&filterR);
    }

    return AudioEffect::setActive(state);
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::process(Vst::ProcessData& data)
{
    // Process parameter changes
    if (data.inputParameterChanges) {
        int32 numParamsChanged = data.inputParameterChanges->getParameterCount();
        for (int32 i = 0; i < numParamsChanged; i++) {
            Vst::IParamValueQueue* paramQueue = data.inputParameterChanges->getParameterData(i);
            if (paramQueue) {
                Vst::ParamValue value;
                int32 sampleOffset;
                int32 numPoints = paramQueue->getPointCount();

                if (paramQueue->getPoint(numPoints - 1, sampleOffset, value) == kResultTrue) {
                    switch (paramQueue->getParameterId()) {
                        case kParamFilterType:
                            currentFilterType = (filter_type_t)((int)(value * 6.999f)); // 0-6 for 7 types
                            filter_set_parameters(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain);
                            filter_set_parameters(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain);
                            break;

                        case kParamCutoffFreq:
                            // Map 0-1 to 20Hz-20kHz logarithmically
                            currentCutoff = 20.0f * powf(1000.0f, (float)value);
                            filter_set_parameters(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain);
                            filter_set_parameters(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain);
                            break;

                        case kParamResonance:
                            // Map 0-1 to 0.1-10.0
                            currentResonance = 0.1f + (float)value * 9.9f;
                            filter_set_parameters(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain);
                            filter_set_parameters(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain);
                            break;

                        case kParamGain:
                            // Map 0-1 to -24dB to +24dB
                            currentGain = db_to_gain(-24.0f + (float)value * 48.0f);
                            filter_set_parameters(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain);
                            filter_set_parameters(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain);
                            break;
                    }
                }
            }
        }
    }

    // Process audio
    if (data.numInputs == 0 || data.numOutputs == 0) {
        return kResultOk;
    }

    // Get audio buffers
    Vst::AudioBusBuffers& input = data.inputs[0];
    Vst::AudioBusBuffers& output = data.outputs[0];

    int32 numChannels = input.numChannels;
    int32 numSamples = data.numSamples;

    // Process stereo
    if (numChannels >= 2 && input.channelBuffers32 && output.channelBuffers32) {
        float* inL = input.channelBuffers32[0];
        float* inR = input.channelBuffers32[1];
        float* outL = output.channelBuffers32[0];
        float* outR = output.channelBuffers32[1];

        // Process left channel
        filter_process_block(&filterL, inL, outL, numSamples);

        // Process right channel
        filter_process_block(&filterR, inR, outR, numSamples);
    }

    return kResultOk;
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::setupProcessing(Vst::ProcessSetup& newSetup)
{
    tresult result = AudioEffect::setupProcessing(newSetup);
    if (result == kResultOk) {
        // Update filter sample rates
        filter_set_sample_rate(&filterL, (float)newSetup.sampleRate);
        filter_set_sample_rate(&filterR, (float)newSetup.sampleRate);
    }
    return result;
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::canProcessSampleSize(int32 symbolicSampleSize)
{
    if (symbolicSampleSize == Vst::kSample32) {
        return kResultTrue;
    }
    return kResultFalse;
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::setState(IBStream* state)
{
    if (!state) {
        return kResultFalse;
    }

    IBStreamer streamer(state, kLittleEndian);

    int32 savedFilterType = 0;
    if (!streamer.readInt32(savedFilterType)) {
        return kResultFalse;
    }
    currentFilterType = (filter_type_t)savedFilterType;

    if (!streamer.readFloat(currentCutoff)) {
        return kResultFalse;
    }

    if (!streamer.readFloat(currentResonance)) {
        return kResultFalse;
    }

    if (!streamer.readFloat(currentGain)) {
        return kResultFalse;
    }

    // Update filters with loaded state
    filter_set_parameters(&filterL, currentFilterType, currentCutoff, currentResonance, currentGain);
    filter_set_parameters(&filterR, currentFilterType, currentCutoff, currentResonance, currentGain);

    return kResultOk;
}

//------------------------------------------------------------------------
tresult PLUGIN_API MatrixFilterProcessor::getState(IBStream* state)
{
    if (!state) {
        return kResultFalse;
    }

    IBStreamer streamer(state, kLittleEndian);

    streamer.writeInt32((int32)currentFilterType);
    streamer.writeFloat(currentCutoff);
    streamer.writeFloat(currentResonance);
    streamer.writeFloat(currentGain);

    return kResultOk;
}

} // namespace MatrixFilterVST
} // namespace Steinberg
