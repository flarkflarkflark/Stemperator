# Device Selection Testing Checklist

## Manual Testing Guide

### Prerequisites
- REAPER installed
- STEMperator scripts installed via ReaPack
- Python with audio-separator installed

### Test 1: Device Detection (Python)
```bash
# Run device detection test
python3 test_device_detection.py
# Expected: All tests pass

# List available devices
python scripts/reaper/audio_separator_process.py --list-devices
# Expected: Shows CPU + any detected GPUs
```

### Test 2: Device Selection UI (REAPER)
1. Open REAPER
2. Select a media item or make time selection
3. Run: Actions → "STEMperator: AI Stem Separation"
4. Verify:
   - [ ] "Device:" label appears under "Model:" section
   - [ ] Device button shows current selection (default: "Auto")
   - [ ] Clicking device button cycles through available options
   - [ ] Tooltip shows device description on hover
   - [ ] Multi-language support (EN/NL/DE) works

### Test 3: Device Persistence
1. Open STEMperator dialog
2. Change device from "Auto" to "CPU"
3. Click STEMperate button (or ESC to cancel)
4. Close REAPER completely
5. Reopen REAPER
6. Open STEMperator dialog again
7. Verify:
   - [ ] Device selection is still "CPU" (persisted via ExtState)

### Test 4: Command Construction
Check batch files created during processing:

**Windows:**
```cmd
# After starting a separation, check:
%TEMP%\stemperator_*\run_separation.bat
# Should contain: --device auto (or selected device)
```

**macOS/Linux:**
```bash
# Check stdout for command line
cat /tmp/stemperator_*/separation_log.txt
# Should show: "Requested device: auto" or selected device
```

### Test 5: Single Track Processing
1. Select one media item
2. Open STEMperator dialog
3. Set device to "CPU" (for predictable testing)
4. Select "Vocals" only
5. Click STEMperate
6. Verify:
   - [ ] Processing starts
   - [ ] Progress window shows separation in progress
   - [ ] Log shows correct device being used
   - [ ] Stems are created successfully

### Test 6: Multi-Track Processing (Parallel)
1. Select 2-3 media items on different tracks
2. Open STEMperator dialog
3. Set device to your preferred GPU
4. Enable "Parallel" processing mode
5. Click STEMperate
6. Verify:
   - [ ] Multiple tracks process simultaneously
   - [ ] Each uses the selected device
   - [ ] All complete successfully

### Test 7: Multi-Track Processing (Sequential)
1. Select 2-3 media items on different tracks
2. Open STEMperator dialog
3. Set device to your preferred GPU
4. Disable parallel (click to change to "Sequential")
5. Click STEMperate
6. Verify:
   - [ ] Tracks process one at a time
   - [ ] Each uses the selected device
   - [ ] All complete successfully

### Test 8: Device Fallback (CPU)
1. Set device to "cuda:5" (non-existent GPU)
2. Process an item
3. Check separation_log.txt
4. Verify:
   - [ ] Warning about CUDA not available
   - [ ] Fallback to CPU occurs
   - [ ] Processing completes (just slower)

### Test 9: Platform-Specific Tests

#### Windows AMD (DirectML)
1. Install: `pip install torch-directml`
2. Run: `python scripts/reaper/audio_separator_process.py --list-devices`
3. Verify:
   - [ ] DirectML devices are listed
   - [ ] Can select directml:0, directml:1, etc.
   - [ ] Processing works with DirectML

#### Linux AMD (ROCm)
1. Install PyTorch with ROCm from pytorch.org
2. Run: `python scripts/reaper/audio_separator_process.py --list-devices`
3. Verify:
   - [ ] CUDA devices are listed (ROCm uses cuda names)
   - [ ] Can select cuda:0, cuda:1, etc.
   - [ ] Processing works with ROCm

#### macOS Apple Silicon (MPS)
1. Standard PyTorch installation on M1/M2/M3
2. Run: `python scripts/reaper/audio_separator_process.py --list-devices`
3. Verify:
   - [ ] MPS device is listed
   - [ ] Can select "mps"
   - [ ] Processing works with MPS acceleration

### Test 10: Stress Testing
1. Set device to GPU
2. Process 5-10 tracks in parallel mode
3. Monitor GPU memory usage
4. Verify:
   - [ ] Doesn't crash with OOM errors
   - [ ] All tracks complete
   - [ ] Or: Graceful error message if insufficient memory

### Test 11: Language Support
Switch language in STEMperator settings:
1. English:
   - [ ] "Device:" label appears
   - [ ] Device button shows proper names
2. Dutch:
   - [ ] "Apparaat:" label appears
   - [ ] Device button shows proper names
3. German:
   - [ ] "Gerät:" label appears
   - [ ] Device button shows proper names

## Automated Testing

### Python Unit Tests
```bash
python3 test_device_detection.py
```
Expected output:
```
Testing parse_device_string()...
✓ parse_device_string tests passed

Testing detect_available_devices()...
✓ detect_available_devices tests passed

✅ All tests passed!
```

## Known Limitations

1. **DirectML on Windows**: Requires `torch-directml` package
2. **ROCm on Linux**: Requires PyTorch built with ROCm support
3. **Device detection**: Requires Python to be callable from shell
4. **First run**: Device list is cached, restart REAPER if you install new drivers

## Troubleshooting

### Device not detected
```bash
# Check Python can detect devices
python scripts/reaper/audio_separator_process.py --list-devices

# Check torch installation
python -c "import torch; print(torch.cuda.is_available())"
```

### Device selection not persisting
```bash
# Check ExtState in REAPER
reaper.GetExtState("Stemperator", "device")
# Should return current device string
```

### Processing fails with selected device
1. Check separation_log.txt for error messages
2. Try falling back to CPU device
3. Verify GPU drivers are up to date
4. Check GPU memory is sufficient (need ~2-4GB free)

## Performance Validation

Track processing times for 3-minute song:

| Device | Expected Time | Your Result |
|--------|---------------|-------------|
| CPU (8-core) | 6-10 min | ______ min |
| AMD DirectML | 1-2 min | ______ min |
| NVIDIA CUDA | 1-2 min | ______ min |
| Apple MPS | 2-3 min | ______ min |

## Bug Reports

If you find issues, please report with:
- OS and version
- GPU model
- Python version (`python --version`)
- PyTorch version (`python -c "import torch; print(torch.__version__)"`)
- Output of `--list-devices`
- Contents of separation_log.txt
- REAPER version
