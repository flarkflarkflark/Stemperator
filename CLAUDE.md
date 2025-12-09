# CLAUDE.md - Stemperator

## REAPER Script Implementation (ACTIVE DEVELOPMENT)

### Quick Start for Claude
**Read `docs/Stemperator_Session_Notes.md` for full development context!**

### Current State (2025-12-08)
- **Status**: WORKING - Multi-track parallel processing with GPU acceleration
- **Debug mode**: ENABLED (`DEBUG_MODE = true` in Lua script line 65)
- **Hardware tested**: AMD Ryzen 7840HS + RX 9070 eGPU (16GB) via DirectML

### Key Files
| File | Location | Purpose |
|------|----------|---------|
| `Stemperator_AI_Separate.lua` | `scripts/reaper/` | Main REAPER script with GUI |
| `audio_separator_process.py` | `scripts/reaper/` | Python backend for AI separation |
| `Stemperator_Session_Notes.md` | `docs/` | Detailed development notes |

### Recent Fixes (This Session)
1. Multi-track parallel processing - all items on all tracks
2. Dynamic segment size: 30 (single), 40 (sequential), 25 (parallel)
3. Mute/Delete selection split fix (re-query bounds after first split)
4. Window flickering fix (`execHidden()` function)
5. AMD DirectML GPU detection and display
6. User-selectable Parallel/Sequential processing mode
7. Enhanced progress window with real-time stats (CPU, GPU, RAM, ETA)
8. Benchmark timing in completion dialog
9. STEMperate button with colored stem letters

### Benchmark: RX 9070 16GB (~5.5s audio per track)

**Fast Model (htdemucs):**
| Tracks | Sequential | Parallel | Speedup |
|--------|-----------|----------|---------|
| 1 | 0:15 | 0:16 | 1.0x |
| 2 | 0:47 | 0:19 | 2.5x |
| 3 | 1:11 | 0:26 | 2.7x |
| 4 | 1:32 | 0:36 | 2.6x |
| 5 | 1:59 | 0:50 | 2.4x |

**Quality Model (htdemucs_ft):**
| Tracks | Sequential | Parallel | Speedup |
|--------|-----------|----------|---------|
| 1 | 0:37 | 0:37 | 1.0x |
| 2 | 1:58 | 0:44 | 2.7x |
| 3 | 2:59 | 1:19 | 2.3x |
| 4 | 3:53 | 1:34 | 2.5x |
| 5 | 4:58 | 2:08 | 2.3x |

**Summary:**
- Fast model is **~2.5x faster** than quality model
- Parallel mode is **2.3-2.7x faster** than sequential
- **Best case:** 5 tracks fast parallel = 50s (vs 4:58 quality sequential = 6x faster)
- **Default: Parallel + htdemucs** (needs 12GB+ VRAM)

### Installation
```bash
# Windows - Copy to REAPER Scripts folder
cp scripts/reaper/*.lua scripts/reaper/*.py \
   "$APPDATA/REAPER/Scripts/Stemperator - AI Stem Separation/AI/Stem Separation/"

# Linux
cp scripts/reaper/*.lua scripts/reaper/*.py \
   ~/.config/REAPER/Scripts/Stemperator/

# Test Python backend
python scripts/reaper/audio_separator_process.py --check
```

### Dependencies
- Python 3.9+ with `pip install audio-separator[gpu]`
- `pip install torch-directml` (Windows AMD GPU)
- ffmpeg in PATH
- REAPER with js_ReaScriptAPI and SWS extensions

---

## VST3 Plugin (FUTURE)

**Stemperator** is an AI-powered stem separation VST3 plugin and standalone application by flarkAUDIO. It separates audio into 4 stems:
- **Vocals** - Lead and backing vocals
- **Drums** - Percussion and drums
- **Bass** - Bass guitar and low-frequency instruments
- **Other** - Everything else (guitars, synths, keys, etc.)

## Current Implementation Status

| Feature | Status | Implementation |
|---------|--------|----------------|
| Multi-output VST3 | ✅ Done | 4 stereo outputs routable in DAW |
| Premium Scalable GUI | ✅ Done | FabFilter-style, 600x400 to 1600x1000 |
| GPU Spectral Separation | ✅ Done | cuFFT (NVIDIA), rocFFT (AMD), OpenCL fallback |
| Demucs AI Integration | ✅ Done | Python subprocess, PyTorch backend |
| Real-time Demucs | ❌ Future | Complex, requires streaming inference |

## Building

### Prerequisites

```bash
# JUCE is included as submodule
git submodule update --init --recursive

# Optional: GPU acceleration (AMD)
sudo pacman -S rocm-hip-sdk rocfft  # Arch Linux

# Optional: AI separation
./scripts/setup_demucs.sh  # Installs PyTorch + Demucs
```

### Build Commands

```bash
mkdir build && cd build
cmake ..  # Auto-detects GPU backend
cmake --build . --config Release -j8
```

### Build Options

```bash
cmake -DGPU_BACKEND=CUDA ..     # Force NVIDIA CUDA
cmake -DGPU_BACKEND=HIP ..      # Force AMD ROCm
cmake -DGPU_BACKEND=OPENCL ..   # Force OpenCL (universal)
cmake -DGPU_BACKEND=NONE ..     # CPU only
cmake -DENABLE_GPU=OFF ..       # Disable GPU detection
```

## Architecture

```
Stemperator/
├── Source/
│   ├── PluginProcessor.cpp/h     # Main processor (StemSeparatorImpl alias)
│   ├── PluginEditor.cpp/h        # Premium scalable GUI
│   ├── DSP/
│   │   ├── StemSeparator.cpp/h       # CPU spectral separation (fallback)
│   │   └── SpectralProcessor.cpp/h   # FFT utilities
│   ├── GPU/
│   │   └── GPUStemSeparator.cpp/h    # rocFFT-accelerated separation
│   ├── AI/
│   │   ├── DemucsProcessor.cpp/h     # C++ wrapper for Demucs
│   │   └── demucs_process.py         # Python processing script
│   └── GUI/
│       ├── StemChannel.cpp/h         # Individual stem controls
│       ├── Visualizer.cpp/h          # Spectrum/level display
│       └── PremiumLookAndFeel.h      # FabFilter-style theme
├── scripts/
│   └── setup_demucs.sh           # Dependency installer
└── build/
    └── Stemperator_artefacts/    # Build outputs
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
