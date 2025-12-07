# Stemperator

**AI-powered stem separation for music production**

![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)
![ReaPack](https://img.shields.io/badge/ReaPack-compatible-green)
![License](https://img.shields.io/badge/license-MIT-blue)

Stemperator uses AI (Demucs/HTDemucs) to separate audio into individual stems. Available as REAPER scripts (via ReaPack) and as a VST3/Standalone plugin.

---

## Quick Start

### REAPER Users (Recommended)

1. **Install AI Backend** (one time, ~5 minutes):

   **Windows** (PowerShell as Admin):
   ```powershell
   # Download and run installer
   Invoke-WebRequest -Uri "https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/install.ps1" -OutFile install.ps1
   .\install.ps1
   ```

   **macOS/Linux** (Terminal):
   ```bash
   curl -sSL https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/install.sh | bash
   ```

2. **Install REAPER Scripts**:
   - Open REAPER → Extensions → ReaPack → Import repositories
   - Paste: `https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/reaper/index.xml`
   - Extensions → ReaPack → Browse packages → Search "Stemperator" → Install

3. **Verify Setup**:
   - Actions → Run: "Stemperator: Setup AI Backend"
   - Should show all green checkmarks ✓

4. **Use It**:
   - Select audio item → Actions → "Stemperator: AI Stem Separation"

---

## Features

### Stem Types

| Model | Stems | Best For |
|-------|-------|----------|
| **htdemucs** (4-stem) | Vocals, Drums, Bass, Other | Fast, general use |
| **htdemucs_ft** (4-stem) | Vocals, Drums, Bass, Other | Highest quality |
| **htdemucs_6s** (6-stem) | Vocals, Drums, Bass, Other, Guitar, Piano | Detailed separation |

### REAPER Scripts

| Script | Description |
|--------|-------------|
| **Stemperator: AI Stem Separation** | Main dialog - full control |
| **Stemperator: Karaoke** | One-click vocal removal |
| **Stemperator: Vocals Only** | Extract vocals |
| **Stemperator: Drums Only** | Extract drums |
| **Stemperator: Bass Only** | Extract bass |
| **Stemperator: All Stems** | Extract all stems to tracks |
| **Stemperator: Setup Toolbar** | Add toolbar buttons |

### Keyboard Shortcuts (in dialog)
- `1-6` - Toggle stems
- `K` - Karaoke preset
- `I` - Instrumental preset
- `A` - All stems
- `Enter` - Start separation
- `Esc` - Cancel

---

## Installation Details

### Requirements

- **Python 3.9+** (3.10-3.12 recommended)
- **ffmpeg** (for audio conversion)
- **~2GB disk space** (for AI models)

### Automatic Installation

The install scripts automatically:
1. Find or install Python
2. Create isolated virtual environment
3. Install PyTorch with GPU support (if available)
4. Install audio-separator package
5. Pre-download AI models

### GPU Acceleration

| GPU | Support | Speed Improvement |
|-----|---------|-------------------|
| NVIDIA (CUDA) | ✓ Full | 10-20x faster |
| AMD (ROCm) | ✓ Linux only | 10-15x faster |
| Apple Silicon (MPS) | ✓ Native | 5-10x faster |
| Intel/AMD (CPU) | ✓ Fallback | Baseline |

### Manual Installation

If automatic installation fails:

**Windows:**
```cmd
python -m pip install audio-separator[gpu]
winget install Gyan.FFmpeg
```

**macOS:**
```bash
pip3 install audio-separator[gpu]
brew install ffmpeg
```

**Linux (Ubuntu/Debian):**
```bash
pip3 install audio-separator[gpu]
sudo apt install ffmpeg
```

**Linux (Arch):**
```bash
pip install audio-separator[gpu]
sudo pacman -S ffmpeg
```

---

## VST3 Plugin

Stemperator is also available as a multi-output VST3 plugin.

### Download Pre-built

Check [Releases](https://github.com/flarkflarkflark/Stemperator/releases) for pre-built binaries.

### Build from Source

```bash
git clone --recursive https://github.com/flarkflarkflark/Stemperator.git
cd Stemperator

# Install AI backend
./scripts/install.sh

# Build plugin
mkdir build && cd build
cmake ..
cmake --build . --config Release -j8
```

### VST3 Features

- Multi-output routing (4-6 stereo buses)
- Real-time spectral preview
- GPU-accelerated FFT processing
- Premium scalable GUI

---

## Processing Time

| Hardware | 3-minute song |
|----------|---------------|
| RTX 3080 / RX 6800 | 15-30 seconds |
| RTX 2070 / RX 5700 | 30-60 seconds |
| Apple M1/M2 | 45-90 seconds |
| Modern CPU (8 core) | 2-5 minutes |
| Older CPU | 5-15 minutes |

---

## Output

Stems are saved as WAV files alongside your original audio (regardless of input format):
```
mysong.mp3           # Your original file (mp3, wav, flac, etc.)
mysong_vocals.wav    # Stems are always high-quality WAV
mysong_drums.wav
mysong_bass.wav
mysong_other.wav
mysong_guitar.wav    # 6-stem only
mysong_piano.wav     # 6-stem only
```

---

## Troubleshooting

### "Python not found"
Run the install script for your platform, or install Python 3.10+ manually.

### "audio-separator not found"
```bash
pip install audio-separator[gpu]
```

### "ffmpeg not found"
- Windows: `winget install Gyan.FFmpeg`
- macOS: `brew install ffmpeg`
- Linux: `sudo apt install ffmpeg` or `sudo pacman -S ffmpeg`

### Slow processing
- Ensure GPU drivers are up to date
- Use `htdemucs` model (faster than `htdemucs_ft`)
- Check GPU is being used (look for CUDA/ROCm/MPS in output)

### Out of memory
- Close other GPU-intensive applications
- Try `htdemucs` instead of `htdemucs_6s`
- Processing in smaller chunks (time selection)

---

## Credits

- **Demucs**: Meta AI Research (MIT License)
- **audio-separator**: Beverly Nguyen (MIT License)
- **JUCE**: RAL/ROLI (Commercial/GPL)

---

## License

MIT License - see [LICENSE](LICENSE)

---

**flarkAUDIO** - Professional Audio Tools
