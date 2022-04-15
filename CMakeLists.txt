# (c) Clayground Contributors - MIT License, see "LICENSE" file

cmake_minimum_required(VERSION 3.19)
project (Clayground VERSION 2022.1)

# CMAKE INCLUDES
set(CLAY_CMAKE_SCRIPT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${CLAY_CMAKE_SCRIPT_DIR}")
include(clayplugin)


# COMMON CONFIGURATION
enable_testing()
set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}")
set(CLAYGROUND_PROJECT_VERSION "${CMAKE_PROJECT_VERSION}")

if (NOT ANDROID) # Qt Android cmake causes problems otherwise
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
endif()

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
set(CLAY_PLUGIN_BASE_DIR ${QML_IMPORT_PATH}/Clayground)


# PLUGIN LINKING
set(CLAYPLUGIN_LINKING SHARED)
if (ANDROID) # Avoids plugin loading problems
    set(CLAYPLUGIN_LINKING STATIC)
endif()
init_static_plugin_cfg()


# DEPENDENCIES
add_subdirectory (thirdparty/qml-box2d)
if (TARGET Box2Dplugin)
    extend_static_plugin_cfg("Box2Dplugin" "Box2DPlugin")
endif()
add_subdirectory (thirdparty/simple-svg-writer)


# CLAYGROUND PLUGINS, TOOLS AND EXAMPLES
add_subdirectory (plugins)
if(NOT ANDROID)
    add_subdirectory (tools)
endif()
add_subdirectory (examples)


# ANDROID PACKAGING CFG
if(ANDROID)
#   # Set this directory in case you want to customize packaging of the Android App
#   # (name, icons, permissions ...) - see also Qt docs
#   # set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android" CACHE INTERNAL "")
endif()
