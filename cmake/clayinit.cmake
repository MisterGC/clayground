# Set the plugin linking type based on the platform
set(CLAYPLUGIN_LINKING SHARED CACHE INTERNAL "")
if (ANDROID OR IOS)
    set(CLAYPLUGIN_LINKING STATIC CACHE INTERNAL "")
endif()

# Set output directories
if (NOT (ANDROID OR IOS)) # Desktop, TODO What about WASM?
    set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
else()
    if (ANDROID)
        # In some environments Qt (Creator) produces a gradle properties
        # file with an invalid androidBuildToolsVersion value - the following
        # option allows to workaround this bug by allowing to provide the version
        # explicitly. (See https://bugreports.qt.io/browse/QTBUG-94956)
        set(CLAY_ANDROID_BUILD_TOOLS_VERSION
            "DO_NOT_USE" CACHE STRING
            "Set to the used version, if you need to workaround QTBUG-94956")
    endif()
endif()

# Set the QML import path
set(QML_IMPORT_PATH ${CMAKE_BINARY_DIR}/bin/qml CACHE STRING "" FORCE)
set(CLAY_PLUGIN_BASE_DIR ${QML_IMPORT_PATH}/Clayground CACHE INTERNAL "")
set(CLAY_DEPS_BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty CACHE INTERNAL "")

# Set the CMake script directory and extend the module path
set(CLAY_CMAKE_SCRIPT_DIR "${CMAKE_CURRENT_LIST_DIR}" CACHE INTERNAL "")
list(APPEND CMAKE_MODULE_PATH "${CLAY_CMAKE_SCRIPT_DIR}")

