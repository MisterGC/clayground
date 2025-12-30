cmake_minimum_required(VERSION 3.16)
project (examples)

add_subdirectory (gui)
add_subdirectory (platformer)
add_subdirectory (visualfx)
add_subdirectory (void)
add_subdirectory (voxelworld)

# topdown uses clay_network which is not available in WASM
if (NOT EMSCRIPTEN)
    add_subdirectory (topdown)
endif()

# pluginlive requires desktop features
if (NOT (ANDROID OR IOS OR EMSCRIPTEN))
    add_subdirectory (pluginlive)
endif()
