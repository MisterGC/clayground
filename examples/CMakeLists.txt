cmake_minimum_required(VERSION 3.16)
project (examples)

add_subdirectory (gui)
add_subdirectory (platformer)
add_subdirectory (topdown)
add_subdirectory (visualfx)
add_subdirectory (void)

if (NOT ANDROID)
    add_subdirectory (pluginlive)
endif()
