# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flarksiesis v2.0 is a cross-platform audio plugin built with JUCE 7.x that provides LFO-modulated filtering effects. It compiles to VST3, Standalone, and LV2 (Linux only) formats.

## Build Commands

### Standard Build
```bash
# Initial setup (if JUCE submodule not initialized)
git submodule update --init --recursive

# Configure and build
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release

# Output location: build/Flarksiesis_artefacts/
```

### Platform-Specific Builds
```bash
# Windows (Visual Studio)
cmake .. -G "Visual Studio 17 2022" -A x64
cmake --build . --config Release

# macOS (Xcode)
cmake .. -G Xcode
cmake --build . --config Release

# Linux - Install dependencies first on Arch:
sudo pacman -S base-devel cmake git webkit2gtk freetype2 libx11 libxext libxrandr libxinerama libxcursor
```

## Architecture Overview

### Core DSP Architecture

The plugin follows a standard JUCE plugin architecture with these key processing components:

**PluginProcessor** (`Source/PluginProcessor.h/cpp`)
- Manages all audio processing via `processBlock()`
- LFO generates modulation values at audio rate (5 waveforms: Sine, Triangle, Square, Saw, Random)
- Filter processing applies State Variable Filters with 8 types (lowpass/highpass/bandpass/notch/allpass at 12dB or 24dB slopes)
- Per-channel filter state maintains `std::array<FilterState, 2>` for true stereo processing
- Parameters managed through JUCE's `AudioProcessorValueTreeState` (APVTS)

**Processing Flow**:
1. LFO generates modulation value from phase (updated per-sample)
2. Base filter frequency modulated by LFO: `frequency * pow(2, lfoValue * depth * 4)`
3. Filter coefficients calculated per-sample using biquad formulas
4. Filter state updated via Direct Form II transposed structure
5. Feedback circuit applies previous sample: `output += previous * feedback`
6. Dry/wet mixing controlled by `mix` parameter

**Critical Implementation Details**:
- Random waveform uses smooth interpolation between random values (stored in `lastRandomValue`/`nextRandomValue`)
- Tempo sync mode converts rate parameter to musical divisions based on host BPM
- Static `smoothedFreq` variable provides one-pole smoothing to prevent zipper noise
- Stereo width adjusts LFO phase offset between L/R channels: `phase + (1 - stereoWidth) * 0.5`

### UI Architecture

**PluginEditor** (`Source/PluginEditor.h/cpp`)
- Orange-on-black themed UI (brand color: `0xFFFF6600`)
- Resizable from 600x450 to 1200x900
- `LFOVisualizer` component runs at 30Hz via `Timer`, redraws waveform path on each tick
- All controls use JUCE attachments to APVTS for automatic parameter binding
- No preset system currently implemented

### Parameter System

All parameters live in APVTS (`apvts` member) created via `createParameterLayout()`:

**LFO Section**:
- `rate`: 0.01-20 Hz (or tempo divisions when synced)
- `depth`: 0-1 (modulation amount)
- `waveform`: Choice (0-4)
- `temposync`: Bool

**Filter Section**:
- `frequency`: 20-20000 Hz with 0.3 skew (logarithmic)
- `resonance`: 0.1-10
- `filtertype`: Choice (0-7)

**Mix Section**:
- `mix`: 0-1 (dry/wet)
- `stereowidth`: 0-2 (mono to super-wide)
- `feedback`: 0-0.95

### State Management

- Filter states persist in `std::array<FilterState, 2> filterStates`
- Each `FilterState` has 4 state variables (`z[4]`) for biquad implementation
- LFO phase tracked globally in `lfoPhase`, advanced by `rate/sampleRate` per sample
- State save/load via XML serialization of APVTS

## Development Notes

### Adding New Filter Types

Add new case to `processFilter()` in PluginProcessor.cpp:223, calculate biquad coefficients (b0, b1, b2, a0, a1, a2), update filter type combo box in PluginEditor and parameter layout.

### Adding New LFO Waveforms

Add enum value to `LFOWaveform` in PluginProcessor.h:52, implement generation logic in `generateLFO()` at PluginProcessor.cpp:169, add visualization case in LFOVisualizer::paint() at PluginEditor.h:32, update waveform combo box parameter.

### Modifying DSP Processing

Filter processing happens per-sample within the channel loop (PluginProcessor.cpp:384-432). The coefficient calculation is intentionally inside the sample loop to allow dynamic modulation. Moving it outside would break LFO modulation.

### GitHub Actions CI/CD

Three workflow files in `.github/workflows/` build for all platforms:
- `linux.yml`: Builds VST3, LV2, Standalone
- `windows.yml`: Builds VST3, Standalone
- `macos.yml`: Builds VST3, Standalone (Universal Binary)

Workflows trigger on push to `main` or on release tags.

## Plugin Format Notes

- VST3: Cross-platform, primary distribution format
- LV2: Linux-only, enabled automatically on Unix systems (see CMakeLists.txt:18-21)
- Standalone: Useful for testing without DAW

## JUCE Framework

This project uses JUCE 7.x as a git submodule at `JUCE/`. Must be initialized with `git submodule update --init --recursive` before building.

Key JUCE modules used:
- `juce::juce_audio_utils`: Plugin wrapper, APVTS
- `juce::juce_dsp`: DSP utilities (though filters are custom implemented)

## Brand Identity

flarkAUDIO brand uses orange (`#FF6600`) on black (`#000000`/`#1A1A1A`) throughout UI. Maintain this aesthetic in any UI modifications.
