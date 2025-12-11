#!/bin/bash

# flark's MatrixFilter - Linux Build Script
# This script builds the plugin for Linux systems

set -e

echo "Building flark's MatrixFilter for Linux..."

# Create build directory
mkdir -p build/linux
cd build/linux

# Run CMake configuration
cmake ../.. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_INSTALL_PREFIX=./install

echo "CMake configuration completed."

# Build the plugin
make -j$(nproc)

echo "Plugin build completed successfully."

# Create installation directory
mkdir -p install/MatrixFilter

# Copy plugin to installation directory
cp libMatrixFilter.so install/MatrixFilter/flark-MatrixFilter.clap

echo "Plugin copied to installation directory."

# Install CLAP libraries if needed
echo "Checking for CLAP library..."
if ! pkg-config --exists clap; then
    echo "CLAP library not found. Installing..."
    sudo apt-get update
    sudo apt-get install libclap-dev
fi

echo "Linux build completed!"
echo "Plugin location: build/linux/install/MatrixFilter/flark-MatrixFilter.clap"
echo ""
echo "To use this plugin:"
echo "1. Copy flark-MatrixFilter.clap to your DAW's CLAP plugin directory"
echo "2. Typical locations:"
echo "   - ~/.clap/Plugins/"
echo "   - /usr/local/lib/clap/"
echo "   - /usr/lib/clap/"
echo ""
echo "Supported DAWs with CLAP support:"
echo "- Bitwig Studio"
echo "- Reaper (with CLAP plugin)"
echo "- Ardour"
echo "- LMMS"