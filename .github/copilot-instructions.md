# Copilot Instructions for STEMperator

## Project Overview

STEMperator is a REAPER Lua script for AI-powered stem separation using Meta's Demucs. This repository contains:

- **REAPER Scripts** (primary): Lua scripts that integrate directly into REAPER DAW
- **Python Backend**: Audio processing wrapper using audio-separator and Demucs
- **Legacy Code**: Historical JUCE/VST3 plugin code (moved to separate STEMdropper project)

## Technology Stack

### REAPER Scripts (Primary Focus)
- **Language**: Lua 5.3 (REAPER's embedded Lua environment)
- **GUI**: REAPER's `gfx` library (custom rendering, no standard UI widgets)
- **Distribution**: ReaPack package manager via `index.xml`
- **Main Script**: `scripts/reaper/Stemperator_AI_Separate.lua` (~10,500 lines)

### Python Backend
- **Language**: Python 3.9+ (3.10-3.12 recommended)
- **Dependencies**:
  - `audio-separator` - Stem separation wrapper
  - `torch` - PyTorch with GPU support (CUDA/ROCm/MPS)
  - `demucs` - Meta's AI model for stem separation
  - `ffmpeg` - Audio format conversion

## Key Files and Locations

### Main Scripts
- `scripts/reaper/Stemperator_AI_Separate.lua` - Main dialog with full controls
- `scripts/reaper/audio_separator_process.py` - Python processing backend
- `scripts/reaper/lang/i18n.lua` - Internationalization (EN, NL, DE)
- `index.xml` - ReaPack package manifest

### Quick Actions
- `Stemperator_Karaoke.lua` - One-click vocal removal
- `Stemperator_VocalsOnly.lua` - Extract vocals only
- `Stemperator_AllStems.lua` - Extract all stems to tracks
- And other preset scripts for specific stem types

### Installation
- `scripts/install.sh` - Linux/macOS automated installer
- `scripts/install.ps1` - Windows PowerShell installer

### Documentation
- `README.md` - User-facing documentation
- `CLAUDE.md` - Developer documentation (code locations, gotchas, workflow)
- `FONT_SIZES.md` - UI scaling documentation
- `TODO_AUDIT.md` - Feature tracking and audit notes

## Coding Standards

### Lua (REAPER Scripts)

#### REAPER Lua Gotchas (CRITICAL)
1. **No `math.pow()`**: Use `x^n` operator instead (e.g., `x^3` not `math.pow(x, 3)`)
2. **No global alpha in gfx**: Use overlay rectangles for opacity effects
3. **PS() and UI() are local**: Scaling functions defined locally, use `sizeMult` parameter
4. **Disable pagers**: Always use `git --no-pager` or `less -F` to avoid interactive output

#### Style Guidelines
- Use descriptive variable names (e.g., `controlsOpacity` not `co`)
- Follow existing patterns in the codebase
- Comment only when explaining complex logic (match existing style)
- Maintain consistency with MilkDrop-inspired visual patterns

#### Important Code Patterns
- Version defined once: `APP_VERSION = "1.5.0"` (line 197 in main script)
- Settings persisted via `reaper.SetExtState()` / `reaper.GetExtState()`
- Visual FX toggle: `SETTINGS.visualFX` controls all procedural art
- Procedural art: 100 patterns × 10 variations = 1000 unique styles

### Python (Backend)
- Python 3.9+ compatibility required
- Handle GPU detection (CUDA, ROCm, MPS, CPU fallback)
- Cross-platform paths (Windows, macOS, Linux)
- Error handling for missing dependencies

## Version Management

When updating version:
1. Edit `APP_VERSION` constant in `Stemperator_AI_Separate.lua` (line 197)
2. Update `@version` in script header
3. Update `@changelog` section in script header
4. Update `index.xml` version and changelog
5. Commit and push together

## Build and Test

### No Formal Build Process
- REAPER scripts are interpreted, not compiled
- No unit tests currently exist (manual testing in REAPER)
- Legacy plugin has CMake build (see `.github/workflows/build.yml`)

### Manual Testing Checklist
1. Test on all platforms (Windows, macOS, Linux)
2. Verify Python path detection works
3. Test with different audio formats (WAV, MP3, FLAC)
4. Check all stem separation models (htdemucs, htdemucs_ft, htdemucs_6s)
5. Verify UI scaling on different DPI settings
6. Test multilingual support (EN, NL, DE)

### Distribution
- ReaPack URL: `https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/reaper/index.xml`
- Users install via Extensions → ReaPack → Import repositories

## Common Development Tasks

### Adding a New Script
1. Create `.lua` file in `scripts/reaper/`
2. Add ReaPack header with `@version` and `@changelog`
3. Update `index.xml` with new package entry
4. Test installation via ReaPack

### Modifying UI
- All UI is custom rendered via `gfx` library
- Main dialog: ~7000-8000 lines in main script
- Processing window: ~8500-11000 lines
- Help window: 5 tabs (Welcome, Quick Start, Stems, Gallery, About)

### Adding Translations
- Edit `lang/i18n.lua`
- Add keys to all language tables (EN, NL, DE)
- Use `T()` function to access translations in code

### Updating Dependencies
- Python deps: Update install scripts (`install.sh`, `install.ps1`)
- Document in README.md requirements section
- Test on all platforms

## Platform-Specific Notes

### Windows
- Python typically in `C:\Python3X\` or `%LOCALAPPDATA%\Programs\Python\`
- Use PowerShell for installation
- FFmpeg via `winget install Gyan.FFmpeg`

### macOS
- Python via Homebrew: `/opt/homebrew/bin/python3` or `/usr/local/bin/python3`
- FFmpeg via Homebrew: `brew install ffmpeg`
- Apple Silicon uses MPS (Metal Performance Shaders) for GPU

### Linux
- System Python: `/usr/bin/python3`
- FFmpeg via apt/pacman
- AMD GPUs use ROCm on Linux only

## Architecture Notes

### Processing Flow
1. User selects audio in REAPER
2. Lua script calls Python backend via `os.execute()` or `io.popen()`
3. Python runs Demucs separation via audio-separator
4. Output WAV files created alongside original
5. Lua imports stems back into REAPER

### Visual FX System
- 100 base patterns (MilkDrop-inspired)
- 10 variations per pattern = 1000 unique styles
- Crossfade transitions (1.5s)
- Old pattern zooms out (1.0 → 1.2), new zooms in (1.15 → 1.0)
- Ease-in-out curve for smooth transitions

## Important Constraints

### Do NOT
- Break existing REAPER Lua compatibility
- Use math.pow() or other non-existent functions
- Add heavy dependencies to Python backend
- Modify working code without testing
- Remove or break ReaPack compatibility

### Do
- Test on all three platforms when possible
- Follow existing code patterns
- Update version numbers consistently
- Document breaking changes
- Maintain backward compatibility where possible

## File Organization

```
Stemperator/
├── .github/
│   ├── workflows/          # CI/CD (legacy plugin only)
│   └── copilot-instructions.md  # This file
├── scripts/
│   ├── reaper/             # All REAPER Lua scripts
│   │   ├── Stemperator_AI_Separate.lua  # Main script
│   │   ├── audio_separator_process.py   # Python backend
│   │   ├── lang/i18n.lua   # Translations
│   │   └── index.xml       # ReaPack manifest
│   ├── install.sh          # Linux/macOS installer
│   └── install.ps1         # Windows installer
├── legacy/                 # Historical JUCE/VST code
├── docs/                   # Documentation and images
├── README.md              # User documentation
├── CLAUDE.md              # Developer guide
└── AGENTS.md              # AI assistant guide (create this)
```

## Getting Started (Developer)

1. Clone the repository
2. Review `CLAUDE.md` for detailed code locations
3. Review `README.md` for user perspective
4. Test main script: Open in REAPER Actions → Load ReaScript
5. Make changes to `scripts/reaper/` files
6. Test manually in REAPER
7. Update `index.xml` if adding/modifying scripts
8. Commit and push

## Support and Contact

- **Author**: flarkAUDIO
- **GitHub**: https://github.com/flarkflarkflark/Stemperator
- **License**: MIT
