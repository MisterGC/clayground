cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (clayground)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory (qml_live_loader)
add_subdirectory (plugins)

add_subdirectory (sandboxes/game_template)
add_subdirectory (sandboxes/gui)
add_subdirectory (sandboxes/ld44_tiny_rebels)
add_subdirectory (sandboxes/particle)
add_subdirectory (sandboxes/coord_drawer)
add_subdirectory (sandboxes/jump_n_run)
add_subdirectory (sandboxes/splitscreen)
