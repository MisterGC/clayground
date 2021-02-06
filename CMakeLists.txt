cmake_minimum_required(VERSION 3.16)
project (Clayground VERSION 2021.2)

enable_testing()
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
# Qt(5) expects Android QML plugins to be located in a qml/...
# dir therefore Clayground just uses this approach for all platforms
set(CLAY_PLUGIN_BASE_DIR ${CMAKE_BINARY_DIR}/bin/qml/Clayground)
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if (${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  set(QML_PLUGIN_LINK_TYPE STATIC CACHE STRING "" FORCE)
endif()

include(qtsupportutils)
fetch_qt_version()
if(ANDROID AND ${QT_VERSION_MAJOR} GREATER 5)
    message(FATAL_ERROR "Android builds of Clayground are only supported with Qt5")
endif()

add_subdirectory (liveloader)
add_subdirectory (plugins)
add_subdirectory (thirdparty/qml-box2d)
add_subdirectory (thirdparty/simple-svg-writer)

add_subdirectory (sandboxes/gui)
add_subdirectory (sandboxes/visualfx)
add_subdirectory (sandboxes/platformer)
add_subdirectory (sandboxes/pluginlive)
add_subdirectory (sandboxes/topdown)
add_subdirectory (sandboxes/void)
