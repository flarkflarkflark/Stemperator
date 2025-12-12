# AGENTS.md - STEMperator Development Guide

> **For AI Assistants & Developers**: This file provides essential context for understanding and contributing to STEMperator.

## What is STEMperator?

STEMperator is a REAPER DAW integration for AI-powered stem separation using Meta's Demucs. It lets users separate audio into individual stems (vocals, drums, bass, other, guitar, piano) directly within REAPER without exporting to external tools.

## Project Type

**REAPER Lua Scripting Project** with Python backend, NOT a traditional software project.

- ✅ **Is**: Collection of Lua scripts for REAPER DAW + Python processing wrapper
- ❌ **Not**: Standalone application, plugin, or library with formal build system

## Quick Context

### Main Technologies
- **Lua 5.3** (REAPER's embedded interpreter) - All UI and integration
- **Python 3.9+** - AI processing backend (Demucs via audio-separator)
- **ReaPack** - Distribution mechanism (package manager for REAPER scripts)

### Key Architecture Point
The Lua scripts provide the UI and REAPER integration. They shell out to Python for the actual AI processing. Results are imported back into REAPER as new media items.

## Critical Knowledge for AI Assistants

### 1. REAPER Lua Is Different

**REAPER Lua is NOT standard Lua**. Critical differences:

```lua
-- ❌ WRONG - These don't exist in REAPER Lua:
result = math.pow(x, 3)        -- math.pow doesn't exist
gfx.set(r, g, b, global_alpha)  -- No global alpha support

-- ✅ CORRECT - Use these instead:
result = x^3                    -- Use power operator
-- For alpha, draw overlay rectangle:
gfx.set(bg_r, bg_g, bg_b, alpha)
gfx.rect(x, y, w, h, 1)
```

**When suggesting Lua code changes**: Always verify compatibility with Lua 5.3 and REAPER's specific gfx/reaper APIs.

### 2. No Build System or Tests

**There is no build step** for the main REAPER scripts:
- Scripts are interpreted directly by REAPER
- No compilation, no bundling, no webpack
- Distribution is via ReaPack (XML manifest + raw Lua files)

**There are no automated tests**:
- Testing is manual in REAPER
- When suggesting changes, understand they must be manually verified
- Don't suggest adding test frameworks unless explicitly requested

### 3. Version Management Is Manual

Version appears in **4 places** and must be synchronized:

1. `Stemperator_AI_Separate.lua` line 197: `APP_VERSION = "1.5.0"`
2. Same file, header `@version` tag
3. Same file, header `@changelog` section  
4. `index.xml` package manifest

**When bumping version**: Update all 4 locations consistently.

### 4. The Code Is Large

The main script (`Stemperator_AI_Separate.lua`) is ~10,500 lines:
- ~3000 lines: Procedural art system (100 patterns × 10 variations)
- ~2000 lines: Main dialog UI
- ~2500 lines: Processing window UI
- ~2000 lines: Help system (5 tabs)
- ~1000 lines: Core logic, settings, i18n

**When making changes**: Be surgical. The file is large but well-organized. See `CLAUDE.md` for specific line number references.

## File Importance Guide

### 🔴 Critical - Touch with Care
- `scripts/reaper/Stemperator_AI_Separate.lua` - Main script, 10K+ lines
- `scripts/reaper/audio_separator_process.py` - Python backend
- `scripts/reaper/index.xml` - ReaPack package manifest
- `index.xml` - Root package manifest (symlink or duplicate?)

### 🟡 Important - Test Thoroughly  
- `scripts/reaper/lang/i18n.lua` - Translations (EN, NL, DE)
- `scripts/install.sh` - Linux/macOS installer
- `scripts/install.ps1` - Windows installer
- Other `Stemperator_*.lua` preset scripts

### 🟢 Safe to Modify
- `README.md` - User documentation
- `CLAUDE.md` - Developer notes
- `AGENTS.md` - This file
- `docs/` - Documentation and images

### ⚪ Legacy - Rarely Touch
- `legacy/` - Old JUCE/VST plugin code (moved to STEMdropper project)
- `.github/workflows/build.yml` - Only for legacy plugin

## Common Tasks

### Task: Add a new i18n translation key

1. Edit `scripts/reaper/lang/i18n.lua`
2. Add key to all three language tables (EN, NL, DE)
3. Use in code via `T("key_name")`
4. Test in REAPER with language switching

### Task: Fix a UI bug

1. Locate code section in `CLAUDE.md` (has line numbers)
2. Edit `Stemperator_AI_Separate.lua`
3. Test in REAPER (Actions → Load ReaScript → Run)
4. Verify on different DPI/scaling settings
5. No formal build or test step needed

### Task: Update dependencies

1. Edit `scripts/install.sh` and `scripts/install.ps1`
2. Update `README.md` requirements section
3. Test installation on all platforms (Windows, macOS, Linux)
4. Verify Python package compatibility (pip install works)

### Task: Add a new preset script

1. Create `scripts/reaper/Stemperator_NewPreset.lua`
2. Copy header from existing preset script
3. Add ReaPack metadata (`@version`, `@changelog`, `@author`)
4. Add entry to `scripts/reaper/index.xml`
5. Test via ReaPack installation
6. Update `README.md` with new script

## Development Workflow

```bash
# 1. Make changes to Lua files
vim scripts/reaper/Stemperator_AI_Separate.lua

# 2. Test in REAPER
# - Open REAPER
# - Actions → Show action list
# - ReaScript: Load → Select your .lua file
# - Test functionality manually

# 3. Update version if needed (4 places!)
# - Line 197 in main script
# - @version in header
# - @changelog in header  
# - index.xml

# 4. Commit
git add scripts/reaper/
git commit -m "fix: Description of change"
git push
```

## Platform Testing Matrix

STEMperator must work on:

| Platform | Python Locations | GPU Support | Priority |
|----------|-----------------|-------------|----------|
| Windows 10/11 | `C:\Python3X\`, `%LOCALAPPDATA%\Programs\Python\` | NVIDIA CUDA | HIGH |
| macOS (Intel) | `/usr/local/bin/python3` | CPU only | MEDIUM |
| macOS (Apple Silicon) | `/opt/homebrew/bin/python3` | MPS (Metal) | HIGH |
| Linux (Ubuntu/Debian) | `/usr/bin/python3` | NVIDIA CUDA, AMD ROCm | MEDIUM |
| Linux (Arch) | `/usr/bin/python3` | NVIDIA CUDA, AMD ROCm | LOW |

**When changing Python detection logic**: Test on at least Windows + macOS or Linux.

## Code Style Philosophy

### Lua Scripts
- Descriptive names over short names (`controlsOpacity` not `co`)
- Comments for complex logic only (not every line)
- Follow existing patterns in the file
- Maintain visual consistency (the art patterns are part of the brand)

### Python Scripts
- PEP 8 compliance
- Handle errors gracefully (don't crash, inform user)
- Cross-platform paths (`pathlib` or `os.path`)
- GPU detection fallback chain (CUDA → ROCm → MPS → CPU)

### Documentation
- User-facing: Simple, example-driven (README.md)
- Developer-facing: Detailed, with line numbers (CLAUDE.md)
- Code comments: Explain WHY not WHAT

## What Success Looks Like

A good change to STEMperator:
- ✅ Works in REAPER on Windows, macOS, and Linux
- ✅ Doesn't break existing functionality
- ✅ Follows existing code patterns
- ✅ Updates all 4 version locations if version changed
- ✅ Updates ReaPack manifest if script added/removed
- ✅ Manually tested in REAPER
- ✅ Documented if user-facing change

## Red Flags 🚩

Watch out for these common mistakes:

- Using `math.pow()` in Lua (doesn't exist in REAPER Lua)
- Forgetting to update all 4 version locations
- Breaking ReaPack compatibility
- Adding dependencies without testing on all platforms
- Assuming standard Lua libraries exist in REAPER
- Not testing with different audio formats
- Breaking GPU detection fallback chain
- Modifying legacy/ folder (not maintained)

## Dependencies and Installation

### End User Needs
- REAPER DAW (any recent version)
- Python 3.9+ 
- ffmpeg
- ~2GB disk space (for AI models)
- Optional: NVIDIA/AMD GPU for acceleration

### Developer Needs (Same as user, plus)
- Git
- Text editor with Lua syntax support
- Ability to test on multiple platforms (VM, dual-boot, etc.)
- Familiarity with REAPER's Action List and ReaScript system

### Python Packages (Auto-installed by install scripts)
- `audio-separator[gpu]` - Main processing package
- `torch` - PyTorch with GPU support
- Implicit deps: `demucs`, `numpy`, `soundfile`, etc.

## Architecture Diagram

```
User selects audio in REAPER
         ↓
[Stemperator_AI_Separate.lua]  ← Main UI (Lua/gfx)
         ↓
    Lua calls Python via os.execute()
         ↓
[audio_separator_process.py]  ← Python wrapper
         ↓
    Calls audio-separator library
         ↓
    [Demucs model] ← AI separation
         ↓
    Writes WAV files to disk
         ↓
[Lua imports WAVs back into REAPER]
         ↓
    User has stems on new tracks ✨
```

## Visual Design Notes

STEMperator includes **1000 procedural art patterns** (100 base × 10 variations):
- Inspired by MilkDrop/Winamp visualizations
- Crossfade transitions with zoom effects
- Toggle via visual FX button (all pages)
- Deterministic based on seed value

**When modifying art system**: Preserve determinism, maintain 100×10 structure, keep performance smooth.

## Distribution Model

**Primary**: ReaPack package manager for REAPER
- Users add repository URL
- Scripts auto-update via ReaPack
- Versioning in `index.xml`

**Secondary**: Manual installation
- Users download `.lua` files directly
- Place in REAPER Scripts folder
- No auto-update

**Legacy**: Plugin/Standalone (moved to STEMdropper project)

## Support Strategy

This is an open-source project with single maintainer:
- Issues on GitHub
- No dedicated support channels
- Community-driven troubleshooting
- Focus on good documentation over hand-holding

**When writing error messages**: Be clear, actionable, and include what to check/install.

## Future Direction

The REAPER script version (this repo) is the maintained version. The plugin/standalone moved to a separate project (STEMdropper). Focus development on:
- REAPER integration improvements
- Additional stem types if Demucs adds them
- UI/UX polish
- Cross-platform compatibility
- Performance optimization

**Don't**: Add features that require rebuilding the plugin architecture.

## License

MIT License - permissive, commercial use allowed.

## Questions for AI Assistants?

**Q: Can I add a new npm/pip package?**  
A: Python packages yes (via install scripts), but test on all platforms. No npm (this isn't a Node.js project).

**Q: Should I add unit tests?**  
A: Only if requested. The project doesn't have a test framework currently.

**Q: Can I refactor the 10K line Lua file?**  
A: Only with explicit approval. It works, and breaking it up may hurt REAPER compatibility.

**Q: How do I test my changes?**  
A: Manually in REAPER. Load the script via Actions → Show action list → ReaScript: Load.

**Q: What Python version should I target?**  
A: 3.9+ for compatibility, 3.10-3.12 is the sweet spot for PyTorch.

**Q: Can I use async/await in Lua?**  
A: No. REAPER Lua is Lua 5.3 without coroutine libraries commonly used for async patterns.

## Quick Reference

- **Main script**: `scripts/reaper/Stemperator_AI_Separate.lua` (10.5K lines)
- **Version**: Line 197 of main script (+ 3 other locations)
- **i18n**: `scripts/reaper/lang/i18n.lua`
- **Python**: `scripts/reaper/audio_separator_process.py`
- **Install**: `scripts/install.sh` (Unix) or `scripts/install.ps1` (Windows)
- **Package**: `scripts/reaper/index.xml`
- **Docs**: `README.md` (users), `CLAUDE.md` (developers), `AGENTS.md` (this file)

---

**Remember**: This is a REAPER Lua scripting project, not a traditional application. When in doubt, preserve existing patterns and test in REAPER.
