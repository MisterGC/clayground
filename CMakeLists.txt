cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (qml_live_loader)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory (qml_live_loader)

add_subdirectory (plugins)

add_subdirectory (sandboxes/coordsys)
add_subdirectory (sandboxes/gui)
add_subdirectory (sandboxes/particle)
