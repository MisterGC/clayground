# (c) Clayground Contributors - MIT License, see "LICENSE" file

# ===============
# PROJECT BASICS
# ===============

# Policy must be set before project() to allow VERSION in project()
if(POLICY CMP0048)
    cmake_policy(SET CMP0048 NEW)
endif()

file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" VERSION_CONTENT)
string(STRIP "${VERSION_CONTENT}" CLAYGROUND_VERSION)

project (Clayground
         VERSION ${CLAYGROUND_VERSION}
         DESCRIPTION "Qt-based set of tools, plugins and libs for rapid app development."
         HOMEPAGE_URL "https://github.com/MisterGC/clayground"
         LANGUAGES CXX)

# Initializes global context that Clayground relies on
# Must be after project() so platform detection (EMSCRIPTEN, etc.) works
include("${CMAKE_CURRENT_LIST_DIR}/cmake/clayinit.cmake")

include(claycommon)
include(clayplugin)

set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}" CACHE INTERNAL "")
set(CLAYGROUND_PROJECT_VERSION "${CMAKE_PROJECT_VERSION}" CACHE INTERNAL "")

# Ensure that all Qt tools are available on root
# level (needed for Qt >= 6.8.0)
find_package(Qt6 COMPONENTS Core Qml REQUIRED)

enable_testing()
init_static_plugin_cfg()


# ==========================
# USER OPTIONS
# ==========================

option(CLAYGROUND_WITH_TOOLS "Include Clayground tools e.g. dojo" ON)
option(CLAYGROUND_WITH_EXAMPLES "Include Clayground examples" ON)
option(CLAY_BUILD_WEBSITE "Build website with WASM demos (requires WASM target)" OFF)
option(CLAY_BUILD_DOCS "Build API documentation using QDoc" OFF)

# Include website module early so clay_website_register_demo() is available
# Prerequisites are checked and target is created at the end
if(CLAY_BUILD_WEBSITE)
    include(claywebsite)
    clay_website_check_prerequisites()
endif()

# Include documentation module for API reference generation
# Also included when building website (docs are auto-generated)
if(CLAY_BUILD_DOCS OR CLAY_BUILD_WEBSITE)
    include(claydoc)
    clay_docs()
endif()


# ===================
# BASIC REQUIREMENTS
# ===================

set(CLAY_CMAKE_MIN_VERSION 3.20 CACHE INTERNAL "")
cmake_minimum_required(VERSION ${CLAY_CMAKE_MIN_VERSION})

set(CLAY_CXX_STANDARD 17 CACHE INTERNAL "")
clay_check_cxx_requirements(MIN_CXX_STANDARD ${CLAY_CXX_STANDARD})

set(CLAY_QT_MIN_VERSION 6.10.0 CACHE INTERNAL "")
clay_check_qt_requirements(MIN_VERSION ${CLAY_QT_MIN_VERSION})


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
    if(NOT (ANDROID OR IOS OR EMSCRIPTEN))
        add_subdirectory (tools)
    endif()
endif()

if(CLAYGROUND_WITH_EXAMPLES)
    add_subdirectory (examples)
endif()


# ================
# WEBSITE BUILD
# ================

# WebDojo is only built for WASM website builds
# (tools/ is excluded from WASM, so we add webdojo separately)
if(EMSCRIPTEN AND CLAY_BUILD_WEBSITE)
    add_subdirectory(tools/webdojo)
endif()

# Create website target after all demos are registered
if(CLAY_BUILD_WEBSITE)
    clay_website_create_target()
endif()
