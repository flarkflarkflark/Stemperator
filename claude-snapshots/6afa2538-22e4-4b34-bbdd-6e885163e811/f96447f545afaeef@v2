#!/bin/bash

# flark's MatrixFilter - LV2 Build Script
# This script builds the LV2 plugin for Linux and cross-platform support

set -e

echo "Building flark's MatrixFilter LV2 Plugin..."

# Create build directory
mkdir -p build-lv2
cd build-lv2

# Check for LV2 development headers
if ! pkg-config --exists lv2 2>/dev/null; then
    echo "LV2 development headers not found. Installing..."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: Check for Homebrew
        if command -v brew >/dev/null 2>&1; then
            brew install lv2 || echo "Please install LV2 manually from http://lv2plug.in/"
        else
            echo "Please install Homebrew first: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux: Install LV2 development headers
        sudo apt-get update
        sudo apt-get install -y lv2-dev liblilv-dev cmake build-essential pkg-config
        echo "LV2 development headers installed"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
        # Windows: Manual installation required
        echo "Please install LV2 development headers manually from http://lv2plug.in/"
    fi
fi

# Run CMake configuration
echo "Running CMake configuration for LV2..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS build
    cmake ../lv2 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_INSTALL_PREFIX=./install \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux build
    cmake ../lv2 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_C_COMPILER=gcc \
        -DCMAKE_CXX_COMPILER=g++ \
        -DCMAKE_INSTALL_PREFIX=./install
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows build
    cmake ../lv2 \
        -G "Visual Studio 16 2019" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=.\install
else
    # Generic Unix build
    cmake ../lv2 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=./install
fi

if [ $? -ne 0 ]; then
    echo "CMake configuration failed!"
    echo "Please ensure LV2 development headers are installed"
    exit 1
fi

echo "CMake configuration completed."

# Build the plugin
echo "Building LV2 plugin..."

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    # Windows: Use MSBuild
    cmake --build . --config Release
else
    # Unix/Linux/macOS: Use make
    make -j$(nproc || sysctl -n hw.ncpu 2>/dev/null || echo 4)
fi

if [ $? -ne 0 ]; then
    echo "LV2 plugin build failed!"
    exit 1
fi

echo "LV2 plugin build completed successfully."

# Build the LV2 bundle
echo "Creating LV2 bundle..."
make lv2_bundle

# Create installation directory
mkdir -p install/lv2

# Copy LV2 bundle to installation directory
if [ -d "flark-matrixfilter.lv2" ]; then
    cp -r flark-matrixfilter.lv2 install/lv2/
    echo "LV2 bundle created successfully."
else
    echo "Warning: LV2 bundle directory not found."
fi

# Copy individual files if bundle doesn't exist
if [ -f "libflark-matrixfilter-lv2.so" ]; then
    mkdir -p install/lv2/flark-matrixfilter.lv2
    cp libflark-matrixfilter-lv2.so install/lv2/flark-matrixfilter.lv2/flark-matrixfilter.so
    cp ../../lv2/manifest.ttl install/lv2/flark-matrixfilter.lv2/
    cp ../../lv2/flark-matrixfilter.ttl install/lv2/flark-matrixfilter.lv2/
    cp ../../lv2/flark-matrixfilter-ui.ttl install/lv2/flark-matrixfilter.lv2/
    
    # Copy UI library if it exists
    if [ -f "libflark-matrixfilter-lv2-ui.so" ]; then
        cp libflark-matrixfilter-lv2-ui.so install/lv2/flark-matrixfilter.lv2/flark-matrixfilter-ui.so
    fi
fi

echo "LV2 plugin copied to installation directory."

echo ""
echo "LV2 build completed!"
echo "Plugin location: build-lv2/install/lv2/flark-matrixfilter.lv2/"
echo ""
echo "To use this LV2 plugin:"
echo "1. Copy the flark-matrixfilter.lv2 folder to your LV2 plugin directory"
echo "2. Typical locations:"
echo "   Linux:"
echo "     - ~/.lv2/"
echo "     - /usr/lib/lv2/"
echo "     - /usr/share/lv2/"
echo "   macOS:"
echo "     - ~/Library/Audio/Plug-Ins/LV2/"
echo "     - /Library/Audio/Plug-Ins/LV2/"
echo "   Windows:"
echo "     - C:\Program Files\LV2\"
echo "     - C:\Users\%USERNAME%\AppData\Local\LV2\"
echo ""
echo "Compatible software with LV2 support:"
echo "- Ardour (native LV2 support)"
echo "- Hydrogen (drum machine)"
echo "- Carla (LV2 host and plugin)"
echo "- Ingen (real-time audio processing)"
echo "- LMMS (with LV2 plugin)"
echo "- ReaHost (Reaper LV2 support)"
echo "- Any DAW with LV2 compatibility"
echo ""
echo "LV2 Plugin Features:"
echo "- Complete LV2 specification compliance"
echo "- State management and preset support"
echo "- Real-time parameter control"
echo "- Matrix visualization with OpenGL"
echo "- Cross-platform compatibility"
echo "- Open-source and free"
echo ""
echo "Note: LV2 plugins use Turtle (.ttl) files for metadata and are"
echo "particularly popular in the Linux audio community."