#!/bin/bash
#
# STEMperator - Cross-Platform Installation Script
# Installs Python environment and audio-separator for AI stem separation
#
# Usage: ./install.sh [--no-gpu]
#
# Works on: Linux, macOS, Windows (Git Bash/MSYS2)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$PROJECT_ROOT/.venv"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo " STEMperator - AI Stem Separation Setup"
    echo "==============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}! $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}→ $1${NC}"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="macos";;
        CYGWIN*|MINGW*|MSYS*) OS="windows";;
        *)          OS="unknown";;
    esac
    echo "$OS"
}

# Detect GPU
detect_gpu() {
    # Check for NVIDIA
    if command -v nvidia-smi &> /dev/null; then
        echo "nvidia"
        return
    fi

    # Check for AMD ROCm
    if command -v rocminfo &> /dev/null; then
        echo "amd"
        return
    fi

    # Check for AMD on macOS (Metal)
    if [ "$OS" = "macos" ]; then
        if system_profiler SPDisplaysDataType 2>/dev/null | grep -q "AMD"; then
            echo "amd-metal"
            return
        fi
        # Apple Silicon uses MPS (Metal Performance Shaders)
        if sysctl -n machdep.cpu.brand_string 2>/dev/null | grep -q "Apple"; then
            echo "apple-mps"
            return
        fi
    fi

    echo "cpu"
}

# Find Python 3
find_python() {
    local python_cmd=""

    # Try python3 first
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        # Check if python is Python 3
        if python --version 2>&1 | grep -q "Python 3"; then
            python_cmd="python"
        fi
    fi

    # On Windows, try py launcher
    if [ -z "$python_cmd" ] && [ "$OS" = "windows" ]; then
        if command -v py &> /dev/null; then
            python_cmd="py -3"
        fi
    fi

    echo "$python_cmd"
}

# Install Python if needed (platform-specific)
install_python() {
    print_info "Python 3.10+ not found. Attempting to install..."

    case "$OS" in
        linux)
            if command -v apt-get &> /dev/null; then
                print_info "Installing Python via apt..."
                sudo apt-get update
                sudo apt-get install -y python3 python3-pip python3-venv
            elif command -v dnf &> /dev/null; then
                print_info "Installing Python via dnf..."
                sudo dnf install -y python3 python3-pip
            elif command -v pacman &> /dev/null; then
                print_info "Installing Python via pacman..."
                sudo pacman -S --needed python python-pip
            else
                print_error "Could not detect package manager. Please install Python 3.10+ manually."
                exit 1
            fi
            ;;
        macos)
            if command -v brew &> /dev/null; then
                print_info "Installing Python via Homebrew..."
                brew install python@3.12
            else
                print_error "Homebrew not found. Please install Python 3.10+ from https://www.python.org/downloads/"
                exit 1
            fi
            ;;
        windows)
            print_error "Python not found. Please install Python 3.10+ from https://www.python.org/downloads/"
            print_info "Make sure to check 'Add Python to PATH' during installation."
            exit 1
            ;;
    esac
}

# Install ffmpeg if needed
install_ffmpeg() {
    if command -v ffmpeg &> /dev/null; then
        print_success "ffmpeg already installed"
        return
    fi

    print_info "Installing ffmpeg..."

    case "$OS" in
        linux)
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y ffmpeg
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y ffmpeg
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --needed ffmpeg
            fi
            ;;
        macos)
            if command -v brew &> /dev/null; then
                brew install ffmpeg
            fi
            ;;
        windows)
            print_warning "Please install ffmpeg manually:"
            print_info "  1. Download from https://ffmpeg.org/download.html"
            print_info "  2. Extract and add to PATH"
            ;;
    esac
}

# Create virtual environment
create_venv() {
    print_info "Creating Python virtual environment..."

    if [ -d "$VENV_DIR" ]; then
        print_warning "Existing virtual environment found. Removing..."
        rm -rf "$VENV_DIR"
    fi

    $PYTHON_CMD -m venv "$VENV_DIR"
    print_success "Virtual environment created at $VENV_DIR"
}

# Get pip command for venv
get_pip() {
    if [ "$OS" = "windows" ]; then
        echo "$VENV_DIR/Scripts/pip"
    else
        echo "$VENV_DIR/bin/pip"
    fi
}

# Get python command for venv
get_venv_python() {
    if [ "$OS" = "windows" ]; then
        echo "$VENV_DIR/Scripts/python"
    else
        echo "$VENV_DIR/bin/python"
    fi
}

# Install PyTorch with appropriate backend
install_pytorch() {
    local pip_cmd=$(get_pip)
    local gpu_type="$1"

    print_info "Installing PyTorch for $gpu_type..."

    case "$gpu_type" in
        nvidia)
            print_info "Installing PyTorch with CUDA support..."
            $pip_cmd install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
            ;;
        amd)
            print_info "Installing PyTorch with ROCm support..."
            $pip_cmd install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0
            ;;
        apple-mps)
            print_info "Installing PyTorch with MPS (Metal) support..."
            # Standard PyTorch includes MPS support on macOS
            $pip_cmd install torch torchvision torchaudio
            ;;
        *)
            print_info "Installing PyTorch (CPU only)..."
            $pip_cmd install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
            ;;
    esac
}

# Install audio-separator
install_audio_separator() {
    local pip_cmd=$(get_pip)

    print_info "Installing audio-separator..."
    $pip_cmd install audio-separator

    print_success "audio-separator installed"
}

# Verify installation
verify_installation() {
    local venv_python=$(get_venv_python)

    print_info "Verifying installation..."

    # Check Python
    $venv_python --version

    # Check PyTorch
    $venv_python -c "
import torch
print(f'PyTorch version: {torch.__version__}')
if torch.cuda.is_available():
    print(f'CUDA available: {torch.cuda.get_device_name(0)}')
elif hasattr(torch.backends, 'mps') and torch.backends.mps.is_available():
    print('MPS (Apple Metal) available')
elif hasattr(torch, 'hip') or 'rocm' in torch.__config__.show().lower():
    print('ROCm available')
else:
    print('Using CPU (no GPU acceleration)')
"

    # Check audio-separator
    $venv_python -c "
from audio_separator.separator import Separator
print('audio-separator is ready')
"

    print_success "All components verified!"
}

# Download models
download_models() {
    local venv_python=$(get_venv_python)

    print_info "Pre-downloading AI models (this may take a few minutes)..."

    # Create a simple test to trigger model download
    $venv_python -c "
from audio_separator.separator import Separator
import os
import tempfile

# This will trigger model download
try:
    sep = Separator()
    sep.load_model('htdemucs')
    print('htdemucs model ready')
except Exception as e:
    print(f'Model download will happen on first use: {e}')
"
}

# Main installation
main() {
    print_header

    # Parse arguments
    NO_GPU=false
    for arg in "$@"; do
        case $arg in
            --no-gpu)
                NO_GPU=true
                ;;
        esac
    done

    # Detect OS
    OS=$(detect_os)
    print_info "Detected OS: $OS"

    # Find or install Python
    PYTHON_CMD=$(find_python)
    if [ -z "$PYTHON_CMD" ]; then
        install_python
        PYTHON_CMD=$(find_python)
    fi

    if [ -z "$PYTHON_CMD" ]; then
        print_error "Could not find or install Python 3"
        exit 1
    fi

    print_success "Found Python: $($PYTHON_CMD --version)"

    # Check Python version
    PY_VERSION=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    PY_MAJOR=$(echo $PY_VERSION | cut -d. -f1)
    PY_MINOR=$(echo $PY_VERSION | cut -d. -f2)

    if [ "$PY_MAJOR" -lt 3 ] || ([ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 9 ]); then
        print_error "Python 3.9+ required, found Python $PY_VERSION"
        exit 1
    fi

    # Install ffmpeg
    install_ffmpeg

    # Detect GPU
    if [ "$NO_GPU" = true ]; then
        GPU_TYPE="cpu"
        print_info "GPU disabled by --no-gpu flag"
    else
        GPU_TYPE=$(detect_gpu)
        print_info "Detected GPU: $GPU_TYPE"
    fi

    # Create virtual environment
    create_venv

    # Upgrade pip
    local pip_cmd=$(get_pip)
    print_info "Upgrading pip..."
    $pip_cmd install --upgrade pip

    # Install PyTorch
    install_pytorch "$GPU_TYPE"

    # Install audio-separator
    install_audio_separator

    # Verify installation
    verify_installation

    # Optional: pre-download models
    echo ""
    read -p "Download AI models now? (recommended, ~200MB) [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        download_models
    fi

    echo ""
    echo -e "${GREEN}=============================================="
    echo " Installation Complete!"
    echo "==============================================${NC}"
    echo ""
    echo "Stemperator is ready to use."
    echo ""
    echo "For REAPER integration:"
    echo "  1. Open REAPER"
    echo "  2. Extensions > ReaPack > Import repositories"
    echo "  3. Add: https://raw.githubusercontent.com/flarkflarkflark/Stemperator/main/scripts/reaper/index.xml"
    echo "  4. Install 'Stemperator' scripts from ReaPack"
    echo ""
    echo "For VST3/Standalone:"
    echo "  The AI backend is now configured in: $VENV_DIR"
    echo ""
}

main "$@"
