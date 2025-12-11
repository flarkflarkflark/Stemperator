# Stemperator Code Audit - December 2025

## Fixes Applied (Session 7 Dec 2025)

### Hardcoded Paths - FIXED
Created `findPythonEnvironment()` utility function that searches for Python environment in order:
1. Relative to executable (build directory structure)
2. `STEMPERATOR_ROOT` environment variable
3. `~/.config/stemperator/python_path` config file
4. Common installation paths (`/usr/share/stemperator`, `/opt/stemperator`, etc.)

All 6 hardcoded `/home/flark/GIT/Stemperator` references replaced.

### Dead Code Removed
Removed unused files from project:
- `Source/AI/UVRProcessor.cpp/h` - Never instantiated
- `Source/AI/SeparationWorkflow.cpp/h` - Never used in main plugin
- `Source/GUI/SeparationWizard.cpp/h` - Never included in main plugin

Updated `CMakeLists.txt` to remove these files and fix the AI script copy command
to use `audio_separator_process.py` (the active script) instead of `demucs_process.py`.

### DemucsProcessor - Retained (Simplified)
`DemucsProcessor` class is still used for:
- Model selection state (4-stem vs 6-stem)
- `is6StemModel()` check
Actual AI processing uses `audio_separator_process.py` via subprocess.

---

## Remaining Technical Debt

### Code Duplication (Lower Priority)
The `findPythonEnvironment()` logic is duplicated in `AboutOverlay::paint()`.
Could be refactored but works correctly as-is.

### Thread Safety (Monitor)
- Atomic flags (`isExporting`, `cancelExport`, `exportProgress`) used without mutex
- Works in practice but could be made more robust with proper locking

### PluginEditor.cpp Size
File is 6,200+ lines. Consider splitting in future:
- UI code -> StemperatorEditor.cpp
- File handling -> AudioFileHandler.cpp
- AI coordination -> AICoordinator.cpp
- Export logic -> ExportManager.cpp

---

## Quick Reference: AI Backend

The AI separation uses:
```
.venv/bin/python Source/AI/audio_separator_process.py
```

This script:
- Uses `audio-separator` library (pip package)
- Wraps Demucs models: htdemucs, htdemucs_ft, htdemucs_6s
- Supports GPU via PyTorch/ROCm/CUDA

---

## Build Status: WORKING
Last successful build: 7 Dec 2025
