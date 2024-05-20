# (c) Clayground Contributors - MIT License, see "LICENSE" file

# ==========================
# CMAKE AND QT REQUIREMENTS
# ==========================

# Study this include if you want to know more about the
# detailed global cmake cache/variable initialization
include("${CMAKE_CURRENT_LIST_DIR}/cmake/clayinit.cmake")

include(claycommon)

set(CLAY_CMAKE_MIN_VERSION 3.20 CACHE INTERNAL "")
cmake_minimum_required(VERSION ${CLAY_MIN_CMAKE_VERSION})

set(CLAY_QT_MIN_VERSION 6.6.0 CACHE INTERNAL "")
clay_check_qt_requirements(MIN_VERSION ${CLAY_QT_MIN_VERSION})


# ==========================
# USER OPTIONS
# ==========================

option(CLAYGROUND_WITH_TOOLS "Include Clayground tools e.g. dojo" ON)
option(CLAYGROUND_WITH_EXAMPLES "Include Clayground examples" ON)


# ====================
# BASIC PROJECT SETUP
# ====================

include(clayplugin)

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" VERSION_CONTENT)
string(STRIP "${VERSION_CONTENT}" CLAYGROUND_VERSION)

project (Clayground
         VERSION ${CLAYGROUND_VERSION}
         DESCRIPTION "Qt-based set of tools, plugins and libs for rapid app development."
         HOMEPAGE_URL "https://github.com/MisterGC/clayground"
         LANGUAGES CXX)

set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}" CACHE INTERNAL "")
set(CLAYGROUND_PROJECT_VERSION "${CMAKE_PROJECT_VERSION}" CACHE INTERNAL "")

enable_testing()
init_static_plugin_cfg()


# =============
# DEPENDENCIES
# =============

add_subdirectory (thirdparty/qml-box2d)
if (TARGET Box2Dplugin)
    extend_static_plugin_cfg("Box2Dplugin" "Box2DPlugin")
endif()
add_subdirectory (thirdparty/simple-svg-writer)
add_subdirectory (thirdparty/csv-parser)


# ============================
# PLUGINS, TOOLS AND EXAMPLES
# ============================

add_subdirectory (plugins)

if(CLAYGROUND_WITH_TOOLS)
    if(NOT (ANDROID OR IOS))
        add_subdirectory (tools)
    endif()
endif()

if(CLAYGROUND_WITH_EXAMPLES)
    add_subdirectory (examples)
endif()
