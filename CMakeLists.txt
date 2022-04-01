# (c) Clayground Contributors - MIT License, see "LICENSE" file

cmake_minimum_required(VERSION 3.19)
project (Clayground VERSION 2022.1)

# COMMON CONFIGURATION
enable_testing()
set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}")

if (NOT ANDROID) # Qt Android cmake causes problems otherwise
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
set(CLAY_PLUGIN_BASE_DIR ${QML_IMPORT_PATH}/Clayground)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")


# DEPENDENCIES
add_subdirectory (thirdparty/qml-box2d)
add_subdirectory (thirdparty/simple-svg-writer)


# PLUGINS
set(CLAYPLUGIN_LINKING SHARED)
if (ANDROID) # Avoids plugin loading problems
    set(CLAYPLUGIN_LINKING STATIC)
endif()
add_subdirectory (plugins)

include(clayplugin)
fetch_all_static_clay_plugins()


# APPLICATIONS
if(NOT ANDROID)
    add_subdirectory (tools)
endif()

if(ANDROID)
#   # Set this directory in case you want to customize packaging of the Android App
#   # (name, icons, permissions ...) - see also Qt docs
#   # set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android" CACHE INTERNAL "")
endif()
add_subdirectory (examples)
