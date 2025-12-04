cmake_minimum_required(VERSION 3.22)
project(Stemperator VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Add JUCE
add_subdirectory(JUCE)

# GPU Acceleration (optional)
option(ENABLE_GPU "Enable GPU acceleration via OpenCL" ON)

if(ENABLE_GPU)
    find_package(OpenCL QUIET)
    if(OpenCL_FOUND)
        message(STATUS "OpenCL found - GPU acceleration enabled")
        add_definitions(-DUSE_OPENCL=1)
    else()
        message(STATUS "OpenCL not found - using CPU only")
        set(ENABLE_GPU OFF)
    endif()
endif()

# Plugin definition - MULTI-OUTPUT for stem separation
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

# Source files
target_sources(Stemperator PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/DSP/StemSeparator.cpp
    Source/DSP/StemSeparator.h
    Source/DSP/SpectralProcessor.cpp
    Source/DSP/SpectralProcessor.h
    Source/GUI/StemChannel.cpp
    Source/GUI/StemChannel.h
    Source/GUI/Visualizer.cpp
    Source/GUI/Visualizer.h
)

target_compile_definitions(Stemperator
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_MODAL_LOOPS_PERMITTED=1
)

target_link_libraries(Stemperator
    PRIVATE
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

if(ENABLE_GPU AND OpenCL_FOUND)
    target_link_libraries(Stemperator PRIVATE OpenCL::OpenCL)
endif()
