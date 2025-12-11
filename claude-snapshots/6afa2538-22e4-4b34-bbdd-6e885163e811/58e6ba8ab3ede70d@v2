cmake_minimum_required(VERSION 3.17)
project(MatrixFilter VERSION 1.0.0 LANGUAGES C CXX)

# Find CLAP - try external directory first, then pkg-config
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/external/clap/include")
    set(CLAP_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/external/clap/include")
    message(STATUS "Using CLAP from external/clap")
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(CLAP REQUIRED clap)
    message(STATUS "Using CLAP from pkg-config")
endif()

add_library(MatrixFilter SHARED)
set_target_properties(MatrixFilter PROPERTIES
    C_STANDARD 11
    CXX_STANDARD 17
)

# Include directories
target_include_directories(MatrixFilter PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CLAP_INCLUDE_DIRS}
)

# Source files
target_sources(MatrixFilter PRIVATE
    src/dsp.cpp
    src/gui.cpp
    src/plugin.cpp
    src/plugin-extensions.cpp
    src/gui-extension.cpp
    src/plugin-factory.cpp
    src/plugin-entry.cpp
)

# Link libraries
target_link_libraries(MatrixFilter PRIVATE
    ${CLAP_LIBRARIES}
    m
    pthread
)

# Platform-specific settings and dependencies
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # Find OpenGL for Linux
    find_package(OpenGL REQUIRED)
    target_link_libraries(MatrixFilter PRIVATE OpenGL::GL)
    
    # Link pthread for Linux
    find_package(Threads REQUIRED)
    target_link_libraries(MatrixFilter PRIVATE Threads::Threads)
    
    # Symbol exports for Linux
    target_link_libraries(MatrixFilter PRIVATE -Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/src/symbols.map)
    target_link_libraries(MatrixFilter PRIVATE -Wl,-z,defs)
    set_target_properties(MatrixFilter PROPERTIES SUFFIX ".clap" PREFIX "")
    
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    # Find OpenGL for macOS
    find_package(OpenGL REQUIRED)
    target_link_libraries(MatrixFilter PRIVATE OpenGL::GL)
    
    # Symbol exports for macOS
    target_link_options(MatrixFilter PRIVATE -exported_symbols_list ${CMAKE_CURRENT_SOURCE_DIR}/src/symbols.map)
    set_target_properties(MatrixFilter PROPERTIES
        BUNDLE True
        BUNDLE_EXTENSION clap
        MACOSX_BUNDLE_GUI_IDENTIFIER com.flark.matrixfilter
        MACOSX_BUNDLE_BUNDLE_NAME "flark's MatrixFilter"
        MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0.0"
    )
    
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    # Find OpenGL for Windows
    find_package(OpenGL REQUIRED)
    target_link_libraries(MatrixFilter PRIVATE OpenGL::GL)
    
    # Symbol exports for Windows
    target_link_options(MatrixFilter PRIVATE /DEF:${CMAKE_CURRENT_SOURCE_DIR}/src/symbols-windows.txt)
    set_target_properties(MatrixFilter PROPERTIES SUFFIX ".clap" PREFIX "")
endif()

# Installation
install(TARGETS MatrixFilter DESTINATION .)
install(FILES README.md DESTINATION .)