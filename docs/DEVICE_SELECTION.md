# Device Selection for GPU Acceleration

## Overview

STEMperator now supports selecting between different compute devices for AI processing, allowing users to choose which GPU to use or fall back to CPU.

## Supported Devices

### Auto (Default)
Automatically selects the best available device in this order:
1. CUDA (NVIDIA GPU or AMD GPU with ROCm on Linux)
2. DirectML (AMD/Intel GPU on Windows)
3. MPS (Apple Silicon GPU on macOS)
4. CPU (fallback)

### CPU
Uses CPU only. Slower but works on all systems.

### CUDA Devices (cuda:0, cuda:1, etc.)
- **NVIDIA GPUs**: Works with standard PyTorch + CUDA installation
- **AMD GPUs on Linux**: Works with PyTorch built with ROCm support
  - Note: ROCm PyTorch uses `cuda` device names even for AMD GPUs

### DirectML Devices (directml:0, directml:1, etc.)
- **Windows only**: AMD and Intel GPUs
- Requires: `pip install torch-directml`
- Best option for AMD GPUs on Windows (RX 9070, Radeon 780M, etc.)

### MPS (Apple Silicon)
- **macOS only**: M1, M2, M3, etc.
- Automatically detected on Apple Silicon Macs
- Much faster than CPU

## Installation

### Windows (AMD GPU)
```bash
pip install torch-directml
pip install audio-separator[gpu]
```

### Linux (AMD GPU with ROCm)
```bash
# Install PyTorch with ROCm support from pytorch.org
# Example for ROCm 6.0:
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
pip install audio-separator
```

### NVIDIA (All Platforms)
```bash
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
pip install audio-separator
```

### macOS (Apple Silicon)
```bash
pip install torch torchvision torchaudio
pip install audio-separator
```

## Usage

### In REAPER GUI
1. Open STEMperator dialog
2. Under "Model:" section, you'll see a "Device:" button
3. Click the device button to cycle through available devices
4. Hover over the button to see device details
5. Selection is saved between sessions

### Command Line
```bash
# Auto-select best device
python audio_separator_process.py input.wav output/ --model htdemucs --device auto

# Use CPU
python audio_separator_process.py input.wav output/ --model htdemucs --device cpu

# Use first CUDA GPU (NVIDIA or AMD with ROCm)
python audio_separator_process.py input.wav output/ --model htdemucs --device cuda:0

# Use second CUDA GPU
python audio_separator_process.py input.wav output/ --model htdemucs --device cuda:1

# Use DirectML (Windows AMD)
python audio_separator_process.py input.wav output/ --model htdemucs --device directml:0

# Use Apple Silicon GPU
python audio_separator_process.py input.wav output/ --model htdemucs --device mps
```

### List Available Devices
```bash
python audio_separator_process.py --list-devices
```

Output example:
```
Available devices (3):
  cpu: CPU
  directml:0: AMD Radeon RX 9070
  directml:1: AMD Radeon 780M Graphics
```

## Technical Details

### Device Detection
The Python script detects available devices at runtime:
- CUDA: `torch.cuda.is_available()` and `torch.cuda.get_device_name()`
- DirectML: `torch_directml.device_count()` (Windows only)
- MPS: `torch.backends.mps.is_available()` (macOS only)

### Graceful Fallback
If a requested device is unavailable, the system automatically falls back to CPU with a warning.

### Multi-GPU Support
- **Parallel Processing**: Each track can use a different GPU when processing multiple tracks
- **Sequential Processing**: All tracks use the same selected GPU

### Memory Considerations
- GPU memory usage depends on model and audio length
- For parallel processing of multiple tracks, ensure sufficient GPU memory
- Use sequential processing mode to reduce memory usage

## Troubleshooting

### "DirectML not available" on Windows AMD
Install DirectML support:
```bash
pip install torch-directml
```

### "CUDA not available" on Linux AMD
Install PyTorch with ROCm support from [pytorch.org](https://pytorch.org/get-started/locally/)

### GPU not detected
1. Run `python audio_separator_process.py --list-devices` to see detected devices
2. Check GPU drivers are installed and up to date
3. Verify PyTorch installation: `python -c "import torch; print(torch.cuda.is_available())"`

### Out of memory errors
- Switch to CPU device
- Use sequential processing instead of parallel
- Process shorter audio segments
- Use a smaller model (htdemucs instead of htdemucs_ft)

## Performance Comparison

Typical processing speeds for a 3-minute song:

| Device Type | Processing Time | Speed |
|-------------|----------------|-------|
| CPU (8 cores) | ~6-10 minutes | 2-3x realtime |
| AMD RX 9070 (DirectML) | ~1-2 minutes | 0.3-0.5x realtime |
| NVIDIA RTX 3090 (CUDA) | ~1-2 minutes | 0.3-0.5x realtime |
| Apple M2 (MPS) | ~2-3 minutes | 0.5-1x realtime |

*Times vary based on model complexity and audio duration*
