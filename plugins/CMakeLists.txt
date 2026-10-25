cmake_minimum_required(VERSION 3.16)
project (plugins)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

add_subdirectory (clay_common)
add_subdirectory (clay_text)

add_subdirectory (clay_canvas)
add_subdirectory (clay_canvas3d)
add_subdirectory (clay_character3d)
add_subdirectory (clay_gamecontroller)
add_subdirectory (clay_sound)
add_subdirectory (clay_storage)
add_subdirectory (clay_svg)

# clay_network: WebRTC/PeerJS on WASM, TCP/UDP on native. Not on iOS yet:
# libdatachannel needs an OpenSSL, and a Mac has none built for iOS (#476).
if (IOS)
    message(STATUS "Clayground: clay_network is not part of iOS builds yet (#476)")
else()
    add_subdirectory (clay_network)
endif()

add_subdirectory (clay_algorithm)
add_subdirectory (clay_physics)
add_subdirectory (clay_world)
add_subdirectory (clay_behavior)

# Lab: experiment kernel for Clayground Labs
add_subdirectory (clay_lab)

# AI plugin: LLM, STT, TTS. Not on iOS yet: under the Xcode generator
# llama.cpp's ggml-metal .m files compile as plain C and fail (#475).
if (IOS)
    message(STATUS "Clayground: clay_ai is not part of iOS builds yet (#475)")
else()
    add_subdirectory (clay_ai)
endif()

# Platform-specific plugins
if (IOS)
    add_subdirectory (clay_ios)
endif()
