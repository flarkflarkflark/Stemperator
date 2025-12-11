# CLAUDE.md - Stemperator

## Project Overview

**Stemperator** is a real-time stem separation VST3 plugin that uses AI/ML models (Demucs, Spleeter) to separate audio into stems:
- **Vocals** - Lead and backing vocals
- **Drums** - Percussion and drums
- **Bass** - Bass guitar and low-frequency instruments
- **Other** - Everything else (guitars, synths, keys, etc.)

The plugin can operate in real-time within a DAW or process files in the standalone application.

## Building

### Prerequisites

```bash
# Install JUCE (submodule)
git submodule add https://github.com/juce-framework/JUCE.git JUCE
git submodule update --init --recursive

# Install LibTorch (optional, for Demucs models)
# Download from https://pytorch.org/get-started/locally/
# Extract to /opt/libtorch or set TORCH_DIR

# Or use ONNX Runtime (lighter weight)
# sudo apt install libonnxruntime-dev
```

### Build Commands

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

### Build Options

```bash
cmake -DUSE_LIBTORCH=ON ..   # Enable Demucs (default)
cmake -DUSE_ONNX=ON ..       # Use ONNX Runtime instead
cmake -DUSE_LIBTORCH=OFF -DUSE_ONNX=OFF ..  # Spectral-only (no AI)
```

## Architecture

```
Stemperator/
├── Source/
│   ├── PluginProcessor.cpp/h    # Audio processing engine
│   ├── PluginEditor.cpp/h       # Main GUI
│   ├── DSP/
│   │   ├── StemSeparator.cpp/h      # Main separator (orchestrates)
│   │   ├── SpectralSeparator.cpp/h  # FFT-based fallback separation
│   │   └── DemucsModel.cpp/h        # AI model inference wrapper
│   ├── GUI/
│   │   ├── StemMixer.cpp/h      # 4-channel stem mixer with faders
│   │   └── WaveformView.cpp/h   # Waveform display per stem
│   └── Utils/
│       └── ModelLoader.cpp/h    # Load/manage ML models
├── models/                       # Pre-trained model files
│   ├── demucs_v4.pt             # Demucs v4 PyTorch model
│   └── htdemucs.onnx            # ONNX converted model
└── Resources/
    └── presets/                  # Factory presets
```

## DSP Pipeline

### Real-time Mode (Low Latency)
1. **Input Buffer** → Audio from DAW (stereo)
2. **Spectral Separator** → Quick FFT-based separation (for preview)
3. **Stem Mixer** → Volume/mute/solo per stem
4. **Output Buffer** → Mixed result back to DAW

### Offline/High Quality Mode
1. **Input Buffer** → Full audio file
2. **Demucs Model** → AI-based separation (GPU accelerated)
3. **Stem Storage** → Cache separated stems
4. **Stem Mixer** → Real-time mixing of cached stems
5. **Output** → Export individual stems or mix

## Stem Separation Algorithms

### 1. Spectral Separator (Fallback/Preview)
Fast FFT-based separation using:
- **Center extraction** for vocals (stereo difference)
- **Low-pass filter** for bass (<200Hz)
- **Transient detection** for drums
- **Residual** for other instruments

### 2. Demucs v4 (AI - High Quality)
Facebook/Meta's hybrid transformer model:
- Input: Stereo audio at 44.1kHz
- Output: 4 stems (vocals, drums, bass, other)
- Latency: ~6 seconds for processing
- Quality: State-of-the-art separation

### 3. ONNX Models (Lighter Weight)
Converted models for faster inference:
- Spleeter 4stems ONNX
- Open-Unmix ONNX
- Lighter resource usage

## GUI Components

### StemMixer
- 4 vertical faders (Vocals, Drums, Bass, Other)
- Mute/Solo buttons per stem
- Pan control per stem
- Master output fader
- Waveform display per stem

### Main Controls
- **Mode**: Real-time / Offline
- **Quality**: Fast / Balanced / Best
- **Export**: Save individual stems as WAV/FLAC

## Key Features

1. **Real-time Preview** - Quick spectral separation for live monitoring
2. **Offline Processing** - High-quality AI separation
3. **Stem Export** - Export individual stems to files
4. **GPU Acceleration** - CUDA/ROCm for faster AI inference
5. **Karaoke Mode** - One-click vocal removal
6. **Remix Mode** - Adjust stem levels for remixing

## Model Files

Models are loaded from `models/` directory:

| Model | Size | Quality | Speed |
|-------|------|---------|-------|
| demucs_v4.pt | 80MB | Best | Slow |
| htdemucs.onnx | 40MB | Great | Medium |
| spleeter_4stems.onnx | 30MB | Good | Fast |

## Performance Targets

- **Real-time latency**: <50ms (spectral mode)
- **Offline processing**: 2x-5x real-time (Demucs)
- **Memory usage**: <2GB RAM
- **GPU acceleration**: 10x speedup on modern GPUs

## Development Tasks

### Phase 1: Core Infrastructure
- [ ] Basic JUCE plugin structure
- [ ] Audio I/O and buffer management
- [ ] Simple GUI with 4 faders

### Phase 2: Spectral Separation
- [ ] FFT-based vocal isolation (center channel)
- [ ] Bass extraction via low-pass
- [ ] Drum detection via transients
- [ ] Residual calculation

### Phase 3: AI Integration
- [ ] LibTorch integration
- [ ] Demucs model loading
- [ ] Batch processing pipeline
- [ ] Stem caching

### Phase 4: GUI Polish
- [ ] Waveform displays
- [ ] Preset management
- [ ] Export functionality
- [ ] Settings dialog

### Phase 5: Optimization
- [ ] GPU acceleration (CUDA/ROCm)
- [ ] Multi-threading
- [ ] Memory optimization
- [ ] Real-time performance

## Design Philosophy

> "Soms is goed gejat beter dan slecht bedacht"
> (Sometimes well-borrowed is better than badly invented)

Study and leverage existing open source implementations rather than reinventing poorly:

### Key Projects to Study

| Project | License | What to Learn |
|---------|---------|---------------|
| **Demucs** | MIT | Model architecture, hybrid transformer approach |
| **Spleeter** | MIT | Production-ready separation, TensorFlow integration |
| **Open-Unmix** | MIT | PyTorch implementation, spectral masking |
| **UVR (Ultimate Vocal Remover)** | MIT | Multi-model ensemble, GUI patterns |
| **audio-separator** | MIT | Python wrapper, model management |
| **Moises.ai** | Commercial | UX/UI inspiration, real-time preview |

### Recommended Approach

1. **Use pre-trained models** - Don't train from scratch
2. **ONNX export** - Convert PyTorch models to ONNX for C++ inference
3. **Study UVR GUI** - Best open source stem separation UI
4. **Spectral fallback** - Simple FFT separation when AI unavailable

### Code to Study

```bash
# Clone reference implementations
git clone https://github.com/facebookresearch/demucs
git clone https://github.com/deezer/spleeter
git clone https://github.com/Anjok07/ultimatevocalremovergui
git clone https://github.com/nomadkaraoke/python-audio-separator
```

## DAW Integration Research

### Integration Strategies

Stemperator moet stems kunnen routeren naar aparte tracks in de DAW. Er zijn meerdere manieren:

| Methode | Complexiteit | DAW Support | Voordelen |
|---------|-------------|-------------|-----------|
| **Multi-Output VST3** | Medium | Alle DAWs | Stems naar mixer channels |
| **ARA2 Extension** | Hoog | Reaper, Cubase, Studio One, Logic | Non-realtime, full file access |
| **Sidechain/Aux Send** | Laag | Alle DAWs | Simpel maar beperkt |
| **Render to Stems** | Laag | Alle DAWs | Offline export |

### Multi-Output VST3 (Primaire Aanpak)

```
Input (Stereo) → Stemperator → Output 1-2: Vocals
                             → Output 3-4: Drums
                             → Output 5-6: Bass
                             → Output 7-8: Other
                             → Output 9-10: Mix (optioneel)
```

**JUCE implementatie:**
```cpp
// In PluginProcessor constructor
AudioProcessor (BusesProperties()
    .withInput  ("Input", AudioChannelSet::stereo(), true)
    .withOutput ("Vocals", AudioChannelSet::stereo(), true)
    .withOutput ("Drums", AudioChannelSet::stereo(), true)
    .withOutput ("Bass", AudioChannelSet::stereo(), true)
    .withOutput ("Other", AudioChannelSet::stereo(), true))
```

### DAW-Specifieke Workflows

#### Reaper
- **Multi-output routing**: Insert plugin → Right-click → "Build multichannel routing for outputs"
- **Render stems**: File → Render → "Stems (selected tracks)"
- **ReaInsert**: Route stems via hardware outputs for external processing
- **Takes**: Explode stems to takes voor A/B vergelijking

```lua
-- Reaper ReaScript: Create tracks from Stemperator outputs
for i = 1, 4 do
    reaper.InsertTrackAtIndex(i, true)
    -- Route Stemperator output i to new track
end
```

#### Bitwig Studio
- **Multi-out chains**: Click double-arrow icon → Add chains automatically
- **Audio Receiver device**: Route stems to any track via SOURCE menu
- **Modular Grid**: Process stems in The Grid with CV/audio routing
- **Clip launcher**: Each stem as separate clip

#### Ableton Live
- **External Audio Effect**: Route stems via plugin's second output
- **Audio tracks**: Create receives from Stemperator aux sends
- **Max for Live**: Custom device for stem routing
- **Native (Live 12.3+)**: Built-in stem separation (concurrent!)

#### FL Studio
- **Patcher**: Multi-output routing within Patcher environment
- **Mixer routing**: Route plugin outputs to separate mixer tracks
- **Edison**: Export stems for editing
- **Native (FL 21.2+)**: Built-in AI stem separator

#### Cubase
- **Quadro/5.1 outputs**: Use surround configuration for stems
- **SpectraLayers ARA2**: Native stem separation integration
- **Direct Offline Processing**: Apply to stems non-destructively
- **Native (Cubase 15)**: Built-in AI stem separation

#### Logic Pro
- **Aux channels**: Route multi-outputs to aux tracks
- **Track Stacks**: Group stems in summing stack
- **Native**: Built-in Stem Splitter (macOS)

### ARA2 Integration (Advanced)

ARA2 maakt non-realtime processing mogelijk - ideaal voor AI stem separation:

```cpp
// JUCE ARA2 setup
juce_add_plugin(Stemperator
    ...
    IS_ARA_EFFECT TRUE
)

// Implement createARAFactory()
const ARA::ARAFactory* JUCE_CALLTYPE createARAFactory()
{
    return juce::ARADocumentControllerSpecialisation::createARAFactory();
}
```

**Voordelen ARA2:**
- Toegang tot hele audio file (niet alleen realtime buffer)
- DAW toont waveform van stems
- Tempo/key sync met project
- Betere kwaliteit (geen realtime constraint)

**Ondersteunde DAWs:** Reaper, Cubase, Studio One, Logic, Cakewalk

### Competitor Analysis: Peel Stems (zplane)

[Peel Stems](https://products.zplane.de/products/peel-stems) - €59, referentie-implementatie:

| Feature | Peel Stems | Stemperator (Goal) |
|---------|------------|-------------------|
| Real-time | Yes (~400ms latency) | Yes |
| Multi-output | 2 outputs | 4-5 outputs |
| Focus EQ | Yes (spectral rectangle) | TODO |
| AI Model | Proprietary | Demucs/ONNX |
| GPU Accel | No | Yes (OpenCL/CUDA) |
| Price | €59 | Open Source |

### Competitor Analysis: Moises Stems Plugin

[Moises Stems](https://moises.ai/features/stems-vst-plugin/) - Subscription:

- 7 stems (vocals, keys, drums, guitar, bass, strings, other)
- Cloud processing (requires internet)
- Works in all major DAWs

### Competitor Analysis: RipX DAW

[RipX DAW](https://hitnmix.com/ripx-daw/) - €99:

- **RipLink plugin**: Send clips from DAW to RipX
- ARA2 support (Studio One, Cubase, Reaper, Cakewalk)
- Note-level editing (beyond just stems)
- Export stems as WAV

### Export Workflows

```
Stemperator Export Options:
├── Quick Export
│   ├── All stems to folder (WAV/FLAC)
│   ├── Selected stems only
│   └── With/without processing
├── DAW Integration
│   ├── Render in place (stem replaces original)
│   ├── Render to new tracks
│   └── Freeze (cache processed audio)
└── Batch Export
    ├── Multiple files → stems folders
    └── Naming convention: {filename}_{stem}.wav
```

### Reaper-Specific Features (Priority)

Reaper is zeer flexibel - speciale features:

1. **Custom Actions**: ReaScript voor stem-naar-tracks
2. **Region/Marker export**: Stems per region
3. **Track Templates**: Pre-configured stem routing
4. **SWS Extensions**: Batch stem operations
5. **Envelope automation**: Per-stem volume/pan automation

```lua
-- Example: Stemperator ReaScript helper
-- Creates 4 tracks with routing from Stemperator multi-out

function CreateStemTracks()
    local stemNames = {"Vocals", "Drums", "Bass", "Other"}
    local sourceTrack = reaper.GetSelectedTrack(0, 0)

    for i, name in ipairs(stemNames) do
        reaper.InsertTrackAtIndex(i, true)
        local newTrack = reaper.GetTrack(0, i)
        reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", name, true)
        -- TODO: Setup routing from Stemperator output i
    end
end
```

### Implementation Priority

1. **Phase 1**: Multi-output VST3 (works everywhere)
2. **Phase 2**: Render-to-stems button in GUI
3. **Phase 3**: ARA2 for supported DAWs
4. **Phase 4**: DAW-specific scripts/templates
5. **Phase 5**: Cloud processing option (optional)

## References

- Demucs: https://github.com/facebookresearch/demucs
- Spleeter: https://github.com/deezer/spleeter
- Open-Unmix: https://github.com/sigsep/open-unmix-pytorch
- Ultimate Vocal Remover: https://github.com/Anjok07/ultimatevocalremovergui
- Audio Separator (Python): https://github.com/nomadkaraoke/python-audio-separator
- JUCE: https://juce.com/
- JUCE ARA Documentation: https://github.com/juce-framework/JUCE/blob/master/docs/ARA.md
- Celemony JUCE_ARA: https://github.com/Celemony/JUCE_ARA
- Peel Stems: https://products.zplane.de/products/peel-stems
- Moises Stems Plugin: https://moises.ai/features/stems-vst-plugin/
- RipX DAW: https://hitnmix.com/ripx-daw/
