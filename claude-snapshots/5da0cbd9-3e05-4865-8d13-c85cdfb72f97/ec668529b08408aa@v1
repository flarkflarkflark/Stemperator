# Stemperator

**An AI-powered stem separator by flarkAUDIO**

![flarkAUDIO](https://img.shields.io/badge/flarkAUDIO-Stemperator-blue)
![ReaPack](https://img.shields.io/badge/ReaPack-compatible-green)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)

Stemperator uses AI (Demucs/HTDemucs) to separate audio into individual stems directly in REAPER. Perfect for remixing, karaoke, transcription, and music production.

## What You Get

### REAPER Scripts (via ReaPack)

| Script | Description |
|--------|-------------|
| **Stemperator: AI Stem Separation** | Main dialog with all options - select stems, choose model, configure output |
| **Stemperator: Karaoke** | One-click vocal removal (instrumental) |
| **Stemperator: Vocals Only** | Extract isolated vocals |
| **Stemperator: Drums Only** | Extract drums and percussion |
| **Stemperator: Bass Only** | Extract bass |
| **Stemperator: Other Only** | Extract other instruments (guitars, synths, keys) |
| **Stemperator: All 4 Stems** | Extract all 4 stems at once |
| **Stemperator: 6-Stem All** | Extract 6 stems including Guitar & Piano |
| **Stemperator: Guitar Only** | Extract guitar (6-stem model) |
| **Stemperator: Piano Only** | Extract piano/keys (6-stem model) |
| **Stemperator: Explode to Tracks** | Separate stems to individual REAPER tracks |
| **Stemperator: Setup Toolbar** | Install toolbar icons for quick access |

### Stem Types

**4-Stem Model (htdemucs):**
- Vocals - Singing and spoken voice
- Drums - Percussion and drums
- Bass - Bass guitar and low frequencies
- Other - Guitars, synths, keys, etc.

**6-Stem Model (htdemucs_6s):**
- All of the above, plus:
- Guitar - Isolated guitar
- Piano - Isolated piano/keys

## Installation via ReaPack

1. Open REAPER
2. Go to **Extensions > ReaPack > Import repositories...**
3. Paste this URL:
   ```
   https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/reaper/index.xml
   ```
4. Go to **Extensions > ReaPack > Browse packages**
5. Search for "Stemperator" and install the scripts you want
6. Run **Stemperator: Setup Toolbar** to add toolbar icons

## Requirements

- **Python 3.10+** with pip
- **audio-separator** package (auto-installed on first run, or install manually):
  ```bash
  pip install audio-separator[gpu]  # For GPU acceleration
  # or
  pip install audio-separator       # CPU only
  ```

### Optional: GPU Acceleration

For faster processing:

**AMD GPU (ROCm):**
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
```

**NVIDIA GPU (CUDA):**
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

## Usage

### Quick Actions (One-Click)
1. Select an audio item in REAPER
2. Run any quick action script (Karaoke, Vocals Only, etc.)
3. Stems are created in the same folder as your audio file

### Main Dialog
1. Select an audio item
2. Run **Stemperator: AI Stem Separation**
3. Check which stems you want
4. Choose model (4-stem or 6-stem)
5. Click **Separate**

### Keyboard Shortcuts (in main dialog)
- `1-4` - Toggle Vocals/Drums/Bass/Other
- `5-6` - Toggle Guitar/Piano (6-stem mode)
- `K` - Karaoke preset
- `I` - Instrumental preset
- `A` - All stems

### Toolbar
Run **Stemperator: Setup Toolbar** once, then restart REAPER. Go to **View > Toolbars > Toolbar 2 (Stemperator)** to show the toolbar with quick-action buttons.

## Output

Stems are saved alongside your original audio file:
```
mysong.wav
mysong_vocals.wav
mysong_drums.wav
mysong_bass.wav
mysong_other.wav
mysong_guitar.wav    # 6-stem only
mysong_piano.wav     # 6-stem only
```

## Processing Time

| Hardware | Approximate Time (3-min song) |
|----------|-------------------------------|
| GPU (CUDA/ROCm) | 30-60 seconds |
| CPU (modern) | 2-5 minutes |
| CPU (older) | 5-15 minutes |

---

## Also Available: VST3 Plugin

Stemperator is also available as a multi-output VST3 plugin for real-time stem routing in any DAW.

### Building the VST3

```bash
git clone --recursive https://github.com/flarkflarkflark/Stemperator.git
cd Stemperator
mkdir build && cd build
cmake ..
cmake --build . --config Release -j8
```

See [CLAUDE.md](CLAUDE.md) for detailed build instructions and architecture documentation.

---

## Credits

- **Demucs/HTDemucs**: Meta AI Research (MIT License)
- **audio-separator**: Python wrapper for stem separation models
- **JUCE**: Framework for VST3 plugin (commercial license)

---

**flarkAUDIO** - Professional Audio Tools
