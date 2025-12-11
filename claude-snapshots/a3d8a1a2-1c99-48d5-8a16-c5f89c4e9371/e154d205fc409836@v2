#!/bin/bash
#
# Stemperator UVR Setup Script
# Installs Ultimate Vocal Remover dependencies for AI stem separation
#
# Usage: ./setup_uvr.sh [--cpu|--gpu|--amd]
#

set -e

echo "========================================"
echo "Stemperator UVR Setup"
echo "========================================"
echo ""

# Parse arguments
GPU_TYPE="auto"
while [[ $# -gt 0 ]]; do
    case $1 in
        --cpu)
            GPU_TYPE="cpu"
            shift
            ;;
        --gpu|--nvidia|--cuda)
            GPU_TYPE="cuda"
            shift
            ;;
        --amd|--rocm)
            GPU_TYPE="rocm"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--cpu|--gpu|--amd]"
            exit 1
            ;;
    esac
done

# Check Python
echo "Checking Python..."
if command -v python3 &> /dev/null; then
    PYTHON=python3
elif command -v python &> /dev/null; then
    PYTHON=python
else
    echo "ERROR: Python not found. Please install Python 3.10 or later."
    exit 1
fi

PYTHON_VERSION=$($PYTHON -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "Found Python $PYTHON_VERSION"

# Check if version is 3.10+
PYTHON_MAJOR=$($PYTHON -c "import sys; print(sys.version_info.major)")
PYTHON_MINOR=$($PYTHON -c "import sys; print(sys.version_info.minor)")

if [[ $PYTHON_MAJOR -lt 3 ]] || [[ $PYTHON_MAJOR -eq 3 && $PYTHON_MINOR -lt 10 ]]; then
    echo "WARNING: Python 3.10+ recommended for best compatibility"
fi

# Auto-detect GPU if not specified
if [[ "$GPU_TYPE" == "auto" ]]; then
    echo ""
    echo "Detecting GPU..."

    if command -v nvidia-smi &> /dev/null; then
        GPU_TYPE="cuda"
        echo "Detected NVIDIA GPU"
        nvidia-smi --query-gpu=name --format=csv,noheader | head -1
    elif command -v rocm-smi &> /dev/null; then
        GPU_TYPE="rocm"
        echo "Detected AMD GPU with ROCm"
    else
        GPU_TYPE="cpu"
        echo "No GPU detected, using CPU mode"
    fi
fi

echo ""
echo "Installation mode: $GPU_TYPE"
echo ""

# Create virtual environment (optional but recommended)
read -p "Create virtual environment? (recommended) [Y/n]: " CREATE_VENV
CREATE_VENV=${CREATE_VENV:-Y}

if [[ "$CREATE_VENV" =~ ^[Yy]$ ]]; then
    VENV_DIR="$HOME/.stemperator-venv"
    echo "Creating virtual environment at $VENV_DIR..."
    $PYTHON -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    PYTHON="$VENV_DIR/bin/python"
    PIP="$VENV_DIR/bin/pip"
else
    PIP="$PYTHON -m pip"
fi

# Upgrade pip
echo ""
echo "Upgrading pip..."
$PIP install --upgrade pip

# Install PyTorch based on GPU type
echo ""
echo "Installing PyTorch..."

case $GPU_TYPE in
    cuda)
        # CUDA 12.1 (latest stable)
        $PIP install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
        ;;
    rocm)
        # ROCm 5.7 (AMD GPUs)
        $PIP install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm5.7
        ;;
    cpu)
        $PIP install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
        ;;
esac

# Install audio-separator (lightweight UVR)
echo ""
echo "Installing audio-separator (UVR core)..."

if [[ "$GPU_TYPE" == "cpu" ]]; then
    $PIP install "audio-separator[cpu]"
else
    $PIP install "audio-separator[gpu]"
fi

# Install additional dependencies
echo ""
echo "Installing additional dependencies..."
$PIP install onnxruntime librosa soundfile

# For GPU, install onnxruntime-gpu
if [[ "$GPU_TYPE" != "cpu" ]]; then
    $PIP install onnxruntime-gpu
fi

# Verify installation
echo ""
echo "Verifying installation..."
echo ""

$PYTHON << 'EOF'
import sys

print("Checking imports...")

try:
    import torch
    print(f"  PyTorch: {torch.__version__}")
    print(f"  CUDA available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"  GPU: {torch.cuda.get_device_name(0)}")
except ImportError as e:
    print(f"  PyTorch: FAILED - {e}")
    sys.exit(1)

try:
    import audio_separator
    print(f"  audio-separator: {audio_separator.__version__}")
except ImportError as e:
    print(f"  audio-separator: FAILED - {e}")
    sys.exit(1)

try:
    import onnxruntime
    print(f"  ONNX Runtime: {onnxruntime.__version__}")
except ImportError as e:
    print(f"  ONNX Runtime: FAILED - {e}")

print("")
print("All dependencies installed successfully!")
EOF

# Download default models
echo ""
read -p "Download recommended models? (requires ~2GB disk space) [Y/n]: " DOWNLOAD_MODELS
DOWNLOAD_MODELS=${DOWNLOAD_MODELS:-Y}

if [[ "$DOWNLOAD_MODELS" =~ ^[Yy]$ ]]; then
    echo "Downloading models..."
    $PYTHON << 'EOF'
from audio_separator.separator import Separator

separator = Separator()

# Download key models
models = [
    "htdemucs",           # 4-stem separation (best all-round)
    "Kim_Vocal_2.onnx",   # Excellent vocal isolation
    "UVR-MDX-NET-Inst_HQ_3.onnx"  # High-quality instrumentals
]

for model in models:
    print(f"Downloading {model}...")
    try:
        separator.download_model_files(model)
        print(f"  Done: {model}")
    except Exception as e:
        print(f"  Warning: Could not download {model}: {e}")

print("")
print("Model download complete!")
EOF
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""

if [[ "$CREATE_VENV" =~ ^[Yy]$ ]]; then
    echo "Virtual environment created at: $VENV_DIR"
    echo ""
    echo "To use with Stemperator, either:"
    echo "  1. Run Stemperator from an activated venv:"
    echo "     source $VENV_DIR/bin/activate"
    echo ""
    echo "  2. Or add Python to your PATH:"
    echo "     export PATH=\"$VENV_DIR/bin:\$PATH\""
fi

echo ""
echo "Installed components:"
echo "  - PyTorch ($GPU_TYPE)"
echo "  - audio-separator (UVR core)"
echo "  - ONNX Runtime"
echo ""
echo "Stemperator will auto-detect the installation."
echo ""
