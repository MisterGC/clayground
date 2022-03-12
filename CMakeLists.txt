# (c) Clayground Contributors - MIT License, see "LICENSE" file
cmake_minimum_required(VERSION 3.19)
project (Clayground VERSION 2021.2)

enable_testing()
set(CLAYGROUND_PROJECT_NAME "${CMAKE_PROJECT_NAME}")
#set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
#set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CLAY_PLUGIN_BASE_DIR ${CMAKE_BINARY_DIR}/bin/qml/Clayground)
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

if(ANDROID)
   set(CLAY_ANDROID_ACTIVE_EXAMPLE "sbx_void" CACHE STRING
       "Choose which of the example should be build/deployed (e.g. sbx_void, topdown ...)")
   #set(ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android" CACHE INTERNAL "")
   set(ANDROID_EXTRA_PLUGINS "${QML_IMPORT_PATH}" CACHE INTERNAL "")
endif()

if (${CMAKE_SYSTEM_NAME} STREQUAL "iOS")
  set(QML_PLUGIN_LINK_TYPE STATIC CACHE STRING "" FORCE)
endif()

#add_subdirectory (thirdparty/qml-box2d)
#add_subdirectory (thirdparty/simple-svg-writer)
#add_subdirectory (plugins)

# Qt has problems with multiple executables when building for Android
# TODO Re-check if support for Android got better in Qt6
if(NOT ANDROID)
    add_subdirectory (tools)
endif()

add_subdirectory (examples)
