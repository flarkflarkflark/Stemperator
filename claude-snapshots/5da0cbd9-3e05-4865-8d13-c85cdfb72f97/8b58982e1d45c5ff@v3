cmake_minimum_required(VERSION 3.22)
project(Stemperator VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# =============================================================================
# macOS Deployment Target - Support older macOS versions
# =============================================================================
# macOS 10.13 (High Sierra, 2017) for maximum compatibility
# This allows the app to run on:
# - All Intel Macs from 2012 onwards
# - All Apple Silicon Macs (via Rosetta 2 or native)
# - macOS 10.13 through macOS 15 (Sequoia)
if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "Minimum macOS version")
    message(STATUS "macOS deployment target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
endif()

# Add JUCE
add_subdirectory(JUCE)

# =============================================================================
# GPU Acceleration Detection
# =============================================================================
option(ENABLE_GPU "Enable GPU acceleration" ON)
set(GPU_BACKEND "AUTO" CACHE STRING "GPU backend: AUTO, CUDA, HIP, OPENCL, NONE")

set(USE_CUDA OFF)
set(USE_HIP OFF)
set(USE_OPENCL OFF)

if(ENABLE_GPU)
    # Try CUDA first (NVIDIA GPUs)
    if(GPU_BACKEND STREQUAL "AUTO" OR GPU_BACKEND STREQUAL "CUDA")
        find_package(CUDAToolkit QUIET)
        if(CUDAToolkit_FOUND)
            message(STATUS "✓ CUDA found - GPU acceleration enabled for NVIDIA GPUs")
            message(STATUS "  CUDA version: ${CUDAToolkit_VERSION}")
            set(USE_CUDA ON)
        elseif(GPU_BACKEND STREQUAL "CUDA")
            message(FATAL_ERROR "CUDA requested but not found. Install CUDA toolkit or set GPU_BACKEND=AUTO")
        endif()
    endif()

    if(NOT USE_CUDA AND (GPU_BACKEND STREQUAL "AUTO" OR GPU_BACKEND STREQUAL "HIP"))
        # Try to find HIP/ROCm first (AMD GPUs)
        list(APPEND CMAKE_PREFIX_PATH "/opt/rocm" "/opt/rocm/hip")

        find_package(hip QUIET CONFIG)
        find_package(rocfft QUIET CONFIG)

        if(hip_FOUND AND rocfft_FOUND)
            message(STATUS "✓ HIP/ROCm found - GPU acceleration enabled for AMD GPUs")
            message(STATUS "  HIP version: ${hip_VERSION}")
            set(USE_HIP ON)
        elseif(GPU_BACKEND STREQUAL "HIP")
            message(FATAL_ERROR "HIP requested but not found. Install ROCm or set GPU_BACKEND=AUTO")
        endif()
    endif()

    if(NOT USE_CUDA AND NOT USE_HIP AND (GPU_BACKEND STREQUAL "AUTO" OR GPU_BACKEND STREQUAL "OPENCL"))
        # Fall back to OpenCL (works on all GPUs)
        find_package(OpenCL QUIET)
        if(OpenCL_FOUND)
            message(STATUS "✓ OpenCL found - GPU acceleration enabled (universal)")
            set(USE_OPENCL ON)
        elseif(GPU_BACKEND STREQUAL "OPENCL")
            message(FATAL_ERROR "OpenCL requested but not found")
        endif()
    endif()

    if(NOT USE_CUDA AND NOT USE_HIP AND NOT USE_OPENCL)
        message(STATUS "✗ No GPU backend found - using CPU only")
    endif()
endif()

# =============================================================================
# Plugin Definition - MULTI-OUTPUT for stem separation
# =============================================================================
juce_add_plugin(Stemperator
    COMPANY_NAME "flarkAUDIO"
    COMPANY_WEBSITE "https://github.com/flarkflarkflark/Stemperator"
    COMPANY_EMAIL "flark@flark-audio.local"

    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS FALSE

    COPY_PLUGIN_AFTER_BUILD TRUE
    PLUGIN_MANUFACTURER_CODE Flrk
    PLUGIN_CODE Stem

    FORMATS VST3 Standalone

    PRODUCT_NAME "Stemperator"

    VST3_CATEGORIES "Fx" "Tools" "Analyzer"

    # Multi-output configuration
    VST_NUM_MIDI_INS 0
    VST_NUM_MIDI_OUTS 0
)

juce_generate_juce_header(Stemperator)

# =============================================================================
# Binary Resources (Icon)
# =============================================================================
juce_add_binary_data(StemperatorBinaryData
    HEADER_NAME "BinaryData.h"
    NAMESPACE "BinaryData"
    SOURCES
        Resources/icons/stemperator_256.png
        Resources/icons/stemperator_128.png
        Resources/icons/stemperator_64.png
        Resources/icons/stemperator_48.png
        Resources/icons/stemperator_32.png
        Resources/icons/stemperator_16.png
)

# =============================================================================
# Source Files
# =============================================================================
set(STEMPERATOR_SOURCES
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/StandaloneFilterApp.cpp
    Source/DSP/StemSeparator.cpp
    Source/DSP/StemSeparator.h
    Source/DSP/SpectralProcessor.cpp
    Source/DSP/SpectralProcessor.h
    Source/GUI/StemChannel.cpp
    Source/GUI/StemChannel.h
    Source/GUI/Visualizer.cpp
    Source/GUI/Visualizer.h
    Source/GUI/PremiumLookAndFeel.h
    Source/GUI/SeparationWizard.cpp
    Source/GUI/SeparationWizard.h
    # AI-powered stem separation
    Source/AI/DemucsProcessor.cpp
    Source/AI/DemucsProcessor.h
    Source/AI/UVRProcessor.cpp
    Source/AI/UVRProcessor.h
    Source/AI/SeparationWorkflow.cpp
    Source/AI/SeparationWorkflow.h
)

# Add GPU sources if available
if(USE_CUDA OR USE_HIP OR USE_OPENCL)
    list(APPEND STEMPERATOR_SOURCES
        Source/GPU/GPUStemSeparator.cpp
        Source/GPU/GPUStemSeparator.h
    )
endif()

target_sources(Stemperator PRIVATE ${STEMPERATOR_SOURCES})

# =============================================================================
# Compile Definitions
# =============================================================================
target_compile_definitions(Stemperator
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_MODAL_LOOPS_PERMITTED=1
        # Disable VSync to reduce GPU idle usage on Linux
        JUCE_COREGRAPHICS_RENDER_WITH_MULTIPLE_PAINT_CALLS=0
        # Standalone settings - use custom app to intercept window close
        JUCE_STANDALONE_FILTER_WINDOW_USE_KIOSK_MODE=0
        JUCE_USE_CUSTOM_PLUGIN_STANDALONE_APP=1
        JucePlugin_WantsMidiInput=0
        JucePlugin_ProducesMidiOutput=0
)

if(USE_CUDA)
    target_compile_definitions(Stemperator PUBLIC USE_CUDA=1)
elseif(USE_HIP)
    target_compile_definitions(Stemperator PUBLIC USE_HIP=1)
elseif(USE_OPENCL)
    target_compile_definitions(Stemperator PUBLIC USE_OPENCL=1)
endif()

# =============================================================================
# Link Libraries
# =============================================================================
target_link_libraries(Stemperator
    PRIVATE
        StemperatorBinaryData
        juce::juce_audio_basics
        juce::juce_audio_devices
        juce::juce_audio_formats
        juce::juce_audio_plugin_client
        juce::juce_audio_processors
        juce::juce_audio_utils
        juce::juce_core
        juce::juce_data_structures
        juce::juce_dsp
        juce::juce_events
        juce::juce_graphics
        juce::juce_gui_basics
        juce::juce_gui_extra
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# Link GPU libraries
if(USE_CUDA)
    target_link_libraries(Stemperator PRIVATE CUDA::cufft CUDA::cudart)
elseif(USE_HIP)
    target_link_libraries(Stemperator PRIVATE hip::host roc::rocfft)
    target_include_directories(Stemperator PRIVATE /opt/rocm/include)
elseif(USE_OPENCL)
    target_link_libraries(Stemperator PRIVATE OpenCL::OpenCL)
endif()

# =============================================================================
# Copy AI scripts to build directories
# =============================================================================
# Copy to Standalone directory
add_custom_command(TARGET Stemperator_Standalone POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/Source/AI/demucs_process.py
        $<TARGET_FILE_DIR:Stemperator_Standalone>/demucs_process.py
    COMMENT "Copying Demucs script to Standalone"
)

# Copy to VST3 directory
add_custom_command(TARGET Stemperator_VST3 POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_SOURCE_DIR}/Source/AI/demucs_process.py
        ${CMAKE_BINARY_DIR}/Stemperator_artefacts/VST3/demucs_process.py
    COMMENT "Copying Demucs script to VST3"
)

# =============================================================================
# GPU Status Summary
# =============================================================================
message(STATUS "")
message(STATUS "=== Stemperator Build Configuration ===")
message(STATUS "  Version: ${PROJECT_VERSION}")
if(USE_CUDA)
    message(STATUS "  GPU Backend: CUDA (NVIDIA optimized)")
    message(STATUS "  cuFFT: Enabled")
elseif(USE_HIP)
    message(STATUS "  GPU Backend: HIP/ROCm (AMD optimized)")
    message(STATUS "  rocFFT: Enabled")
elseif(USE_OPENCL)
    message(STATUS "  GPU Backend: OpenCL (universal)")
else()
    message(STATUS "  GPU Backend: None (CPU only)")
endif()
message(STATUS "  AI Separation: UVR/Demucs (requires Python + audio-separator)")
message(STATUS "  Install AI: pip install audio-separator[gpu]")
message(STATUS "")
