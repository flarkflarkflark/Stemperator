# CLAUDE.md - STEMperator REAPER Lua Script

## Project Overview

**STEMperator** is a REAPER Lua script for AI-powered stem separation using Meta's Demucs. Created by flarkAUDIO.

- **GitHub:** https://github.com/flarkflarkflark/Stemperator
- **ReaPack URL:** https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/index.xml
- **Current Version:** 1.5.0 (defined in `APP_VERSION` constant, line 197)

## Features

- 4 or 6 stem separation (Vocals, Drums, Bass, Other, Guitar, Piano)
- Multiple quality modes (Fast/htdemucs, Quality/htdemucs_ft, 6-Stem/htdemucs_6s)
- In-place or new tracks output
- Multi-track parallel processing
- **1000 MilkDrop-inspired procedural art animations** (100 patterns × 10 variations)
- Crossfade transitions with zoom effect (1.5s)
- Help window with 5 tabs (Welcome, Quick Start, Stems, Gallery, About)
- Multilingual support (EN, NL, DE)
- Dark/Light mode toggle
- Visual FX toggle (on all pages)

## Key Files

### Main Script
`Stemperator_AI_Separate.lua` (~10500 lines)

### Language File
`lang/i18n.lua` - Translations for EN, NL, DE

### Python Backend
`audio_separator_process.py` - Demucs processing wrapper

### ReaPack Index
`index.xml` - Package manifest for ReaPack distribution

## Important Code Locations

### Version
- **Line 197:** `APP_VERSION = "1.5.0"` - Single source of truth for version

### Procedural Art System (Lines 1100-3300)
- `drawProceduralArtInternal()` (1105-3244): 100 patterns × 10 variations = 1000 styles
  - Style calculation: `basePattern = ((style-1) % 100) + 1`, `variation = floor((style-1) / 100) + 1`
- `drawProceduralArt()` (3247-3302): Crossfade wrapper + FX check
  - FX check (3248-3260): `if not SETTINGS.visualFX then` early return
  - Crossfade: OLD zoom-out (1→1.2), NEW zoom-in (1.15→1.0), ease-in-out
- `generateNewArt()` (1021-1097): Saves oldSeed/Style/Elements/Time, transitionProgress=0

### 100 Pattern Categories
- 1-15: Original (Cosmic Waves, Neural Network, Crystal, etc.)
- 16-25: MilkDrop Classic (Plasma Field, Starfield, Tunnel Warp, etc.)
- 26-35: Hypnotic (Spiral, Pulsing Rings, Moiré, etc.)
- 36-45: Fractal-like (Sierpinski, Koch, Julia Set, etc.)
- 46-55: Particles (Fireflies, Stars, Confetti, etc.)
- 56-65: Geometric (Hexagon Grid, Voronoi, etc.)
- 66-75: Waveforms (Spectrum Bars, Oscilloscope, etc.)
- 76-100: Mixed batch (5 pattern types × basePattern modifier)

### Processing Windows
- Window title: "AI STEMperator - Processing..." (lines 8549, 9347)
- STEM letters + "perator" = "STEMperator" branding (8746-8759)
- ESC handler single track (9236)
- ESC handler multi-track (11185)

### Gallery Controls Fade
- State in helpState (715-717): controlsOpacity, targetControlsOpacity
- Fade logic (3644-3666): asymmetric fadeSpeed (0.25 in / 0.08 out)

### FX Toggle Icon (5 pages)
- Gallery (3808-3854): with controlsOpacity fade
- Processing single (8809-8844)
- Processing multi-track (10973-11008)
- Message/Start window (6142-6191)
- Main Dialog (7457-7491)

### Settings
- `SETTINGS.visualFX` - Enable/disable visual effects
- Default: true (line 216)
- Load/save via ExtState (404-405, 453)

## REAPER Lua Gotchas

### math.pow doesn't exist in REAPER Lua 5.3
Use `x^n` operator or manual multiplication:
```lua
-- BAD: math.pow(x, 3)
-- GOOD: x^3 or x*x*x
```

### No global alpha in gfx library
Workaround: Draw fade overlay rectangle over content:
```lua
gfx.set(bg_r, bg_g, bg_b, alpha)
gfx.rect(x, y, w, h, 1)
```

### PS() and UI() functions are local
These scaling functions are defined locally in specific draw functions. Don't use them in `drawProceduralArtInternal()` - use `sizeMult` parameter instead.

## Git Workflow

```bash
cd "C:\Users\Administrator\AppData\Roaming\REAPER\Scripts\Stemperator - AI Stem Separation\AI\Stem Separation"

# Status
git status

# Commit
git add Stemperator_AI_Separate.lua lang/i18n.lua index.xml
git commit -m "feat: Description"
git push
```

## Version Update Checklist

When updating version:
1. Edit `APP_VERSION` on line 197 in Stemperator_AI_Separate.lua
2. Update `@version` in header (line 3)
3. Update `@changelog` section (lines 4-24)
4. Update `index.xml` version and changelog
5. Commit and push

## Testing

Test on:
- Windows (primary dev machine)
- macOS (Homebrew Python paths)
- Linux (system Python paths)

## MilkDrop Algorithm Notes (from geisswerks.com)

- **Zoom:** `zoom = zoom + 0.1*sin(time)`
- **Perspective:** `zoom + rad*0.1` where rad=distance to center [0..1]
- **RGB cycling:** Staggered sine frequencies (1.13, 1.23, 1.33)
- **Smooth fade:** `(ret - 0.002)*0.99`
- **Audio-reactive zoom:** `zoom + 0.1*(bass - 1)`
- **Crossfade:** Old pattern zooms OUT, new zooms IN
- **Ease-in-out:** `t < 0.5 ? 2*t*t : 1 - (-2*t+2)^2/2`

## i18n Keys for FX Toggle

```lua
fx_enable = "Enable visual effects"
fx_disable = "Disable visual effects"
fx_off_indicator = "Visual FX Off - Click FX icon to enable"
```

## Dependencies

- REAPER with JS extension (for JS_Window_* APIs)
- Python 3.8+ with:
  - audio-separator
  - torch (with CUDA/ROCm for GPU acceleration)
  - demucs

## Author

flarkAUDIO - https://github.com/flarkflarkflark
