cmake_minimum_required(VERSION 3.17)
project(MatrixFilter VERSION 1.1.0 LANGUAGES C CXX)

#-------------------------------------------------------------------------------
# VST3 Plugin Build
#-------------------------------------------------------------------------------
message(STATUS "Building MatrixFilter VST3")

# Disable VSTGUI and samples to avoid GUI dependencies
set(SMTG_ADD_VSTGUI OFF CACHE BOOL "Disable VSTGUI" FORCE)
set(SMTG_CREATE_VST2_VERSION OFF CACHE BOOL "Disable VST2" FORCE)
set(SMTG_ENABLE_VSTGUI_SUPPORT OFF CACHE BOOL "Disable VSTGUI support" FORCE)
set(SMTG_ADD_VST3_HOSTING_SAMPLES OFF CACHE BOOL "Disable VST3 hosting samples" FORCE)
set(SMTG_ADD_VST3_PLUGINS_SAMPLES OFF CACHE BOOL "Disable VST3 plugin samples" FORCE)
set(SMTG_RUN_VST_VALIDATOR OFF CACHE BOOL "Disable VST3 validator" FORCE)
set(SMTG_PLUGIN_TARGET_USER_PROGRAM_FILES_COMMON OFF CACHE BOOL "Disable plugin installation" FORCE)
set(SMTG_COREAUDIO_SDK_PATH "" CACHE STRING "Disable CoreAudio" FORCE)

# Add VST3 SDK
add_subdirectory(external/vst3sdk)

# Create VST3 plugin target
set(vst3sdk_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/external/vst3sdk)
set(target MatrixFilterVST)

smtg_add_vst3plugin(${target}
    src/vst3/MatrixFilterVST_processor.cpp
    src/vst3/MatrixFilterVST_processor.h
    src/vst3/MatrixFilterVST_controller.cpp
    src/vst3/MatrixFilterVST_controller.h
    src/vst3/MatrixFilterVST_cids.h
    src/vst3/MatrixFilterVST_entry.cpp
    src/dsp.cpp
)

target_include_directories(${target} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${target} PRIVATE
    sdk
)

# Platform-specific libraries and symbol visibility
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(Threads REQUIRED)
    target_link_libraries(${target} PRIVATE Threads::Threads m)

    # Fix symbol visibility for VST3 entry points on Linux
    # The VST3 SDK requires ModuleEntry and GetPluginFactory to be exported
    set_target_properties(${target} PROPERTIES
        CXX_VISIBILITY_PRESET default
        C_VISIBILITY_PRESET default
        VISIBILITY_INLINES_HIDDEN OFF
    )

    # Add linker flags to export all symbols (VST3 SDK handles filtering)
    target_link_options(${target} PRIVATE
        "-Wl,--no-undefined"
        "-Wl,--export-dynamic"
    )

elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    target_link_libraries(${target} PRIVATE m)
endif()

smtg_target_set_bundle(${target}
    BUNDLE_IDENTIFIER com.matrixfilter.vst3
    COMPANY_NAME "MatrixFilter"
)

# Installation
install(TARGETS ${target} DESTINATION .)
install(FILES README.md DESTINATION .)
