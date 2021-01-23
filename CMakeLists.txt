cmake_minimum_required(VERSION 3.16)
project (Clayground VERSION 2021.2)

enable_testing()
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CLAY_PLUGIN_BASE_DIR ${CMAKE_BINARY_DIR}/bin/plugins/Clayground)
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/plugins CACHE STRING "" FORCE)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if (${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  set(QML_PLUGIN_LINK_TYPE STATIC CACHE STRING "" FORCE)
endif()

include(qtsupportutils)
fetch_qt_version()
if(ANDROID AND ${QT_VERSION_MAJOR} LESS 6)
    message(FATAL_ERROR "Android builds of Clayground are only supported starting with Qt6")
endif()

if(ANDROID)
    set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    set(ANDROID_EXTRA_PLUGINS "${CLAY_PLUGIN_BASE_DIR}/.." "${CLAY_PLUGIN_BASE_DIR}")
#    if (ANDROID_ABI STREQUAL "armeabi-v7a")
#        set(ANDROID_EXTRA_LIBS
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libcrypto.so
#            ${CMAKE_CURRENT_SOURCE_DIR}/path/to/libssl.so)
#    endif()
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
