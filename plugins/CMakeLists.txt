cmake_minimum_required(VERSION 3.16)
project (plugins)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

add_subdirectory (clay_common)

add_subdirectory (clay_canvas)
add_subdirectory (clay_gamecontroller)
add_subdirectory (clay_storage)
add_subdirectory (clay_svg)
#add_subdirectory (clay_network)

add_subdirectory (clay_physics)
add_subdirectory (clay_world)
#add_subdirectory (clay_behavior)
