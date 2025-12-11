# Stemperator

**AI-Powered Stem Separation VST3 Plugin & Standalone Application**

![flarkAUDIO](https://img.shields.io/badge/flarkAUDIO-Stemperator-blue)
![License](https://img.shields.io/badge/license-proprietary-red)
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)

Stemperator is a professional audio stem separation tool that separates music into 4 individual stems:
- **Vocals** - Isolated voice/singing
- **Drums** - Percussion and drums
- **Bass** - Bass guitar and low frequencies
- **Other** - Everything else (guitars, synths, etc.)

## Features

- **Multi-Output VST3**: Route each stem to separate DAW tracks
- **GPU Acceleration**: ROCm/HIP for AMD, OpenCL for all GPUs
- **Real-time Preview**: Fast spectral separation for live use
- **AI Processing**: Demucs integration for studio-quality offline separation
- **Scalable UI**: Works on small laptops to large monitors
- **Premium Look**: FabFilter-inspired professional design

## Requirements

### Build Requirements
- CMake 3.22+
- C++17 compiler (GCC 10+, Clang 12+)
- JUCE framework (included as submodule)

### Optional (for GPU acceleration)
- **AMD GPU**: ROCm 5.0+ with rocFFT
- **Any GPU**: OpenCL runtime

### Optional (for AI separation)
- Python 3.10+
- PyTorch with ROCm/CUDA support
- Demucs

## Building

```bash
# Clone with submodules
git clone --recursive https://github.com/flarkflarkflark/Stemperator.git
cd Stemperator

# Create build directory
mkdir build && cd build

# Configure (auto-detects GPU)
cmake ..

# Build
cmake --build . --config Release -j8
```

### Build Outputs
- **VST3**: `build/Stemperator_artefacts/VST3/Stemperator.vst3`
- **Standalone**: `build/Stemperator_artefacts/Standalone/Stemperator`

The VST3 is automatically installed to `~/.vst3/` on Linux.

## GPU Acceleration

Stemperator auto-detects your GPU and uses the best available backend:

| Backend | GPUs | Performance |
|---------|------|-------------|
| HIP/ROCm | AMD Radeon | 3-5x faster |
| OpenCL | Any GPU | 2-3x faster |
| CPU | Fallback | Baseline |

### Force a Specific Backend
```bash
cmake -DGPU_BACKEND=HIP ..    # AMD only
cmake -DGPU_BACKEND=OPENCL .. # Universal
cmake -DGPU_BACKEND=NONE ..   # CPU only
```

## AI Separation (Demucs)

For studio-quality separation, Stemperator integrates Meta's Demucs model.

### Setup (Arch Linux)
```bash
# Install PyTorch with ROCm
sudo pacman -S python-pytorch-opt-rocm python-torchaudio

# Install Demucs
pip install --user --break-system-packages demucs

# Or use the setup script
./scripts/setup_demucs.sh
```

### Setup (Other Distros)
```bash
# Install PyTorch (choose your GPU)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0  # AMD
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121   # NVIDIA
pip install torch torchvision torchaudio  # CPU only

# Install Demucs
pip install demucs
```

### Quality Modes

| Mode | Engine | Latency | Quality |
|------|--------|---------|---------|
| Fast | GPU Spectral | ~5ms | Good |
| Balanced | GPU Spectral | ~10ms | Better |
| Best | Demucs AI | ~30s/song | Excellent |

## Usage in DAW

1. Insert Stemperator on your master bus or audio track
2. Enable multi-output routing in your DAW
3. Create 4 aux tracks for: Vocals, Drums, Bass, Other
4. Route Stemperator outputs to the aux tracks
5. Adjust individual stem gains and apply effects per-stem

## Architecture

```
Source/
├── PluginProcessor.cpp/h   # Main audio processor
├── PluginEditor.cpp/h      # Premium GUI
├── DSP/
│   ├── StemSeparator.cpp/h    # CPU spectral separation
│   └── SpectralProcessor.cpp/h # FFT utilities
├── GPU/
│   └── GPUStemSeparator.cpp/h # GPU-accelerated separation
├── AI/
│   ├── DemucsProcessor.cpp/h  # Demucs C++ wrapper
│   └── demucs_process.py      # Python processing script
└── GUI/
    ├── StemChannel.cpp/h      # Individual stem controls
    ├── Visualizer.cpp/h       # Spectrum/stem display
    └── PremiumLookAndFeel.h   # FabFilter-style theme
```

## Development

```bash
# Debug build
cmake --build . --config Debug

# Run standalone
./build/Stemperator_artefacts/Debug/Standalone/Stemperator

# Test VST3 in DAW
cp -r build/Stemperator_artefacts/Release/VST3/*.vst3 ~/.vst3/
```

## License

Copyright (c) 2024 flarkAUDIO. All rights reserved.

This is proprietary software. Contact flarkAUDIO for licensing.

## Credits

- **Demucs**: Meta AI Research (MIT License)
- **JUCE**: JUCE Framework (commercial license)
- **ROCm**: AMD (MIT License)

---

**flarkAUDIO** - Professional Audio Tools
