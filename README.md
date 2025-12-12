# STEMperator (REAPER scripts)

**AI-powered stem separation for REAPER**

![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)
![ReaPack](https://img.shields.io/badge/ReaPack-compatible-green)
![License](https://img.shields.io/badge/license-MIT-blue)

![Stemperator Hero](docs/images/stemperator-hero.png)

STEMperator uses AI (Demucs/HTDemucs) to separate audio into individual stems. This repo focuses on REAPER scripts (via ReaPack). The former plugin/standalone is developed separately as STEMdropper; historical JUCE/VST files live in `legacy/`.

---

## Why STEMperator?

**Stay in your DAW.** No more exporting, switching to external tools, and re-importing.

![Before and After](docs/images/stemperator-before-after.png)

STEMperator integrates directly into REAPER, letting you:

- **Process time selections** - Select a 4-bar section and extract just the drums from that part
- **Edit in place** - Replace a media item with its separated stems instantly
- **Work non-destructively** - Original files are preserved, stems are created alongside
- **Be surgical** - Found a sample with an unwanted vocal bleed? Extract only what you need
- **Stay creative** - Remix, mashup, or repair audio without leaving your project

### Real-World Workflows

| Scenario | Traditional Approach | With STEMperator |
|----------|---------------------|------------------|
| Remove vocal from a loop | Export → External tool → Re-import → Align | Select item → Karaoke → Done |
| Extract drums from reference track | Export → Separate → Import 4 files → Create tracks | Select → All Stems → Auto-routed tracks |
| Fix a sample with unwanted bass | Find alternate sample or EQ compromise | Select → Bass Only → Delete original bass |
| Create acapella from full mix | External software, manual export/import | Select → Vocals Only → New track |
| Isolate guitar solo for analysis | Complex EQ/phase tricks | Select region → Guitar Only |

---

## Quick Start (REAPER)

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
   - Extensions → ReaPack → Browse packages → Search "STEMperator" → Install

3. **Verify Setup**:
   - Actions → Run: "STEMperator: Installation & Setup"
   - Should show all green checkmarks ✓

4. **Use It**:
   - Select audio item → Actions → "STEMperator: AI Stem Separation"

---

## Features

### Stem Types

| Model | Stems | Best For |
|-------|-------|----------|
| **htdemucs** (4-stem) | Vocals, Drums, Bass, Other | Fast, general use |
| **htdemucs_ft** (4-stem) | Vocals, Drums, Bass, Other | Highest quality |
| **htdemucs_6s** (6-stem) | Vocals, Drums, Bass, Other, Guitar, Piano | Detailed separation |

![6-Stem Model](docs/images/stemperator-6stem.png)

### Flexible Input Selection

STEMperator works with whatever you have selected:

![Time Selection Feature](docs/images/stemperator-time-selection.png)

| Selection Type | What Gets Processed |
|----------------|---------------------|
| **Media item(s)** | Full item(s) - stems replace or appear alongside original |
| **Time selection** | Only the selected time range - perfect for surgical edits |
| **Time selection + item** | Intersection of both - maximum precision |

This means you can:
- Process an entire song by selecting the media item
- Extract stems from just a chorus by making a time selection
- Work on a specific 2-bar section without affecting the rest

### REAPER Scripts

![Stemperator Dialog](docs/images/stemperator-dialog.png)

| Script | Description |
|--------|-------------|
| **STEMperator: AI Stem Separation** | Main dialog - full control over model, stems, and options |
| **STEMperator: Karaoke** | One-click vocal removal (keeps drums, bass, other) |
| **STEMperator: Vocals Only** | Extract vocals to new track |
| **STEMperator: Drums Only** | Extract drums to new track |
| **STEMperator: Bass Only** | Extract bass to new track |
| **STEMperator: All Stems** | Extract all stems to separate tracks |
| **STEMperator: Explode Stems** | Route stems to individual tracks |
| **STEMperator: Setup Toolbar** | Add quick-access toolbar buttons |

![Toolbar Icons](docs/images/stemperator-toolbar.png)

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

## Legacy plugin/standalone

The VST3/standalone implementation has moved to the **STEMdropper** project. Historical JUCE/VST code and resources remain in `legacy/` for reference.

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

![REAPER with Stems](docs/images/reaper-stems.png)

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

## Contributing

Contributions are welcome! For development setup and guidelines:

1. See [AGENTS.md](AGENTS.md) for project overview and AI assistant guidance
2. See [CLAUDE.md](CLAUDE.md) for detailed code locations and developer notes
3. See [.github/copilot-instructions.md](.github/copilot-instructions.md) for coding standards

**Quick Start for Developers**:
- Clone the repository
- Main code is in `scripts/reaper/Stemperator_AI_Separate.lua` (~10.5K lines Lua)
- No build step - scripts are interpreted by REAPER
- Testing is manual via REAPER's Actions → Load ReaScript
- Distribution via ReaPack (see `scripts/reaper/index.xml`)

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
