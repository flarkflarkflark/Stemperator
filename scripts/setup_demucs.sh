#!/bin/bash
#
# Stemperator - Demucs AI Setup Script
# Installs PyTorch with ROCm support and Demucs for AI stem separation
#

set -e

echo "=============================================="
echo " Stemperator - Demucs AI Setup"
echo "=============================================="
echo ""

# Detect distro
if [ -f /etc/arch-release ]; then
    DISTRO="arch"
elif [ -f /etc/debian_version ]; then
    DISTRO="debian"
elif [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
else
    DISTRO="unknown"
fi

echo "Detected distro: $DISTRO"
echo ""

# Check for AMD GPU
if command -v rocminfo &> /dev/null; then
    echo "✓ ROCm detected - Will install GPU-accelerated PyTorch"
    HAS_ROCM=true
else
    echo "✗ ROCm not detected - Will use CPU-only PyTorch"
    echo "  For GPU acceleration, install ROCm first:"
    echo "  Arch: sudo pacman -S rocm-hip-sdk"
    HAS_ROCM=false
fi
echo ""

# Install based on distro
case $DISTRO in
    arch)
        echo "Installing PyTorch for Arch Linux..."
        if [ "$HAS_ROCM" = true ]; then
            echo "→ sudo pacman -S python-pytorch-opt-rocm python-torchaudio"
            sudo pacman -S --needed python-pytorch-opt-rocm python-torchaudio
        else
            echo "→ sudo pacman -S python-pytorch-opt python-torchaudio"
            sudo pacman -S --needed python-pytorch-opt python-torchaudio
        fi

        echo ""
        echo "Installing Demucs..."
        echo "→ pip install --user demucs"
        pip install --user --break-system-packages demucs
        ;;

    debian)
        echo "Installing PyTorch for Debian/Ubuntu..."
        echo "Using pip (system packages may be outdated)"

        if [ "$HAS_ROCM" = true ]; then
            pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
        else
            pip3 install torch torchvision torchaudio
        fi

        pip3 install demucs
        ;;

    fedora)
        echo "Installing PyTorch for Fedora..."
        pip3 install torch torchvision torchaudio demucs
        ;;

    *)
        echo "Unknown distro - attempting generic pip install"
        pip3 install torch torchvision torchaudio demucs
        ;;
esac

echo ""
echo "=============================================="
echo " Verifying installation..."
echo "=============================================="

python3 -c "
import torch
print(f'✓ PyTorch {torch.__version__}')
print(f'  CUDA/ROCm available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'  GPU: {torch.cuda.get_device_name(0)}')
"

python3 -c "import demucs; print('✓ Demucs installed')"

echo ""
echo "=============================================="
echo " Setup Complete!"
echo "=============================================="
echo ""
echo "You can now use 'Best' quality mode in Stemperator for AI-powered"
echo "stem separation. First run will download model weights (~150MB)."
echo ""
