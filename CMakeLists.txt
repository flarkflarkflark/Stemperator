cmake_minimum_required(VERSION 3.22)
project(Stemperator VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add JUCE as a subdirectory
add_subdirectory(JUCE)

# LibTorch for neural network inference (Demucs models)
option(USE_LIBTORCH "Enable LibTorch for Demucs model inference" ON)
option(USE_ONNX "Enable ONNX Runtime as alternative inference backend" OFF)

if(USE_LIBTORCH)
    find_package(Torch QUIET)
    if(Torch_FOUND)
        message(STATUS "LibTorch found: ${TORCH_LIBRARIES}")
        add_definitions(-DUSE_LIBTORCH=1)
    else()
        message(WARNING "LibTorch not found. Will use fallback spectral separation.")
        set(USE_LIBTORCH OFF)
    endif()
endif()

if(USE_ONNX)
    find_package(onnxruntime QUIET)
    if(onnxruntime_FOUND)
        message(STATUS "ONNX Runtime found")
        add_definitions(-DUSE_ONNX=1)
    else()
        message(WARNING "ONNX Runtime not found.")
        set(USE_ONNX OFF)
    endif()
endif()

# Define the plugin
juce_add_plugin(Stemperator
    COMPANY_NAME "flarkAUDIO"
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
    VST3_CATEGORIES "Fx" "Tools"
)

# Generate JUCE header
juce_generate_juce_header(Stemperator)

# Source files
target_sources(Stemperator PRIVATE
    Source/PluginProcessor.cpp
    Source/PluginProcessor.h
    Source/PluginEditor.cpp
    Source/PluginEditor.h
    Source/DSP/StemSeparator.cpp
    Source/DSP/StemSeparator.h
    Source/DSP/SpectralSeparator.cpp
    Source/DSP/SpectralSeparator.h
    Source/DSP/DemucsModel.cpp
    Source/DSP/DemucsModel.h
    Source/GUI/StemMixer.cpp
    Source/GUI/StemMixer.h
    Source/GUI/WaveformView.cpp
    Source/GUI/WaveformView.h
    Source/Utils/ModelLoader.cpp
    Source/Utils/ModelLoader.h
)

# Compile definitions
target_compile_definitions(Stemperator
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
)

# Link JUCE modules
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

# Link LibTorch if available
if(USE_LIBTORCH AND Torch_FOUND)
    target_link_libraries(Stemperator PRIVATE ${TORCH_LIBRARIES})
    target_include_directories(Stemperator PRIVATE ${TORCH_INCLUDE_DIRS})
endif()

# Link ONNX Runtime if available
if(USE_ONNX AND onnxruntime_FOUND)
    target_link_libraries(Stemperator PRIVATE onnxruntime::onnxruntime)
endif()

# Copy model files to build directory
file(GLOB MODEL_FILES "${CMAKE_SOURCE_DIR}/models/*")
if(MODEL_FILES)
    add_custom_command(TARGET Stemperator POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/models"
        "$<TARGET_FILE_DIR:Stemperator>/models"
    )
endif()
