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
set(SMTG_CREATE_MODULE_INFO OFF CACHE BOOL "Disable module info generation" FORCE)
set(SMTG_PLUGIN_TARGET_USER_PROGRAM_FILES_COMMON OFF CACHE BOOL "Disable plugin installation" FORCE)
set(SMTG_COREAUDIO_SDK_PATH "" CACHE STRING "Disable CoreAudio" FORCE)

# Override VST3 SDK's default hidden visibility on Linux
# This ensures ModuleEntry and GetPluginFactory are properly exported
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    set(CMAKE_CXX_VISIBILITY_PRESET default)
    set(CMAKE_C_VISIBILITY_PRESET default)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)
endif()

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
    ${vst3sdk_SOURCE_DIR}/public.sdk/source/main/linuxmain.cpp
)

target_include_directories(${target} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${target} PRIVATE
    sdk
)

# Platform-specific libraries
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    find_package(Threads REQUIRED)
    target_link_libraries(${target} PRIVATE Threads::Threads m)

    # Override VST3 SDK's hidden visibility for our plugin target
    # This ensures ModuleEntry and GetPluginFactory are exported
    set_target_properties(${target} PROPERTIES
        CXX_VISIBILITY_PRESET default
        C_VISIBILITY_PRESET default
        VISIBILITY_INLINES_HIDDEN OFF
    )

    # Linker flags
    target_link_options(${target} PRIVATE
        "-Wl,--no-undefined"
    )

elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    target_link_libraries(${target} PRIVATE m)
endif()

smtg_target_set_bundle(${target}
    BUNDLE_IDENTIFIER com.matrixfilter.vst3
    COMPANY_NAME "MatrixFilter"
)

# Add moduleinfo.json to VST3 bundle (required by some DAWs like Reaper)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_SOURCE_DIR}/moduleinfo.json.in
            $<TARGET_FILE_DIR:${target}>/../Resources/moduleinfo.json
        COMMENT "Copying moduleinfo.json to VST3 bundle"
    )
endif()

# Installation
install(TARGETS ${target} DESTINATION .)
install(FILES README.md DESTINATION .)
