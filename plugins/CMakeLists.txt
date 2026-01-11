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

# clay_network: WebRTC/PeerJS on WASM, TCP/UDP on native
add_subdirectory (clay_network)

add_subdirectory (clay_physics)
add_subdirectory (clay_world)
add_subdirectory (clay_behavior)

# Platform-specific plugins
if (IOS)
    add_subdirectory (clay_ios)
endif()
