# (c) Clayground Contributors - MIT License, see "LICENSE" file

cmake_minimum_required(VERSION 3.19)
project (Clayground VERSION 2023.1)

# CMAKE INCLUDES
set(CLAY_CMAKE_SCRIPT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${CLAY_CMAKE_SCRIPT_DIR}")
include(clayplugin)

# CHECK MIN REQUIRED QT VERSION
set(CLAY_QT_MIN_VERSION "6.6.0")
find_package(Qt6 ${CLAY_QT_MIN_VERSION} QUIET COMPONENTS Core)
if (NOT Qt6_FOUND)
    message(FATAL_ERROR
        "\n>>>>>>>>>> CLAYGROUND CONFIGURE ERROR!!! <<<<<<<<<<<\n"
        "Clayground requires Qt6 ${CLAY_QT_MIN_VERSION} or higher. "
        "Please ensure it is installed and used for configuring your project."
    )
endif()

# COMMON CONFIGURATION
enable_testing()
set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}")
set(CLAYGROUND_PROJECT_VERSION "${CMAKE_PROJECT_VERSION}")

if (NOT (ANDROID OR IOS)) # Desktop, TODO What about WASM?
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
else()
    if (ANDROID)
        # In some environements Qt (Creator) produces a gradle properties
        # file with invalid androidBuildToolsVersion value - the following
        # option allows to workaround this bug by allowing to provide the version
        # explicitely. (See https://bugreports.qt.io/browse/QTBUG-94956)
        set(CLAY_ANDROID_BUILD_TOOLS_VERSION
            "DO_NOT_USE" CACHE STRING
            "Set to the used version, if you need to workaround QTBUG-94956")
    endif()
endif()

set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
set(CLAY_PLUGIN_BASE_DIR ${QML_IMPORT_PATH}/Clayground)
set(CLAY_DEPS_BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty)

# PLUGIN LINKING
set(CLAYPLUGIN_LINKING SHARED)
if (ANDROID OR IOS)
    set(CLAYPLUGIN_LINKING STATIC)
endif()
init_static_plugin_cfg()


# DEPENDENCIES
#add_subdirectory (thirdparty/qml-box2d)
#if (TARGET Box2Dplugin)
#    extend_static_plugin_cfg("Box2Dplugin" "Box2DPlugin")
#endif()
#add_subdirectory (thirdparty/simple-svg-writer)
#add_subdirectory (thirdparty/csv-parser)

# CLAYGROUND PLUGINS, TOOLS AND EXAMPLES
add_subdirectory (plugins)
if(NOT (ANDROID OR IOS))
    add_subdirectory (tools)
endif()
add_subdirectory (examples)
