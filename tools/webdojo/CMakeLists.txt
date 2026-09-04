# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# WebDojo - Browser-based Clayground playground
# Only builds for WASM target
#
if(NOT EMSCRIPTEN)
    message(STATUS "WebDojo: Skipping (WASM build only)")
    return()
endif()

include(clayapp)

clay_app(webdojo
    VERSION 1.0

    CUSTOM_MAIN
        ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick
        Qt::QuickControls2
        Qt::QuickDialogs2
        Qt::QuickLayouts
        Qt::Quick3D
        Qt::Quick3DHelpers
        Qt::Quick3DAssetUtils
        Qt::QuickTimeline
        Qt::Sql
        Qt::Svg
        Qt6::QSvgPlugin

    QML_FILES
        Main.qml
        QmlModules.qml
)

# Emscripten-specific settings for JS interop
# Note: Qt's qtloader.js handles WASM loading, we add --bind for embind
# and export ccall/cwrap for fallback access to exported C functions
# Also export string helpers needed by clay_ai's EM_JS callbacks
target_link_options(webdojo PRIVATE
    "SHELL:--bind"
    "SHELL:-s EXPORTED_RUNTIME_METHODS=['ccall','cwrap','stringToUTF8','lengthBytesUTF8','stackAlloc']"
)

# --- Clayground Web Runtime packaging (issue #118) --------------------------
# The binary is the Clayground Web Runtime: neutral artifact names so the same
# files serve the webdojo playground and games deployed on user sites.
set_target_properties(webdojo PROPERTIES
    OUTPUT_NAME clayground
    QT_WASM_EXPORT_NAME clayground_entry
)

# Version info for the boot banner and the bundle manifest
execute_process(
    COMMAND git describe --tags --always
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
    OUTPUT_VARIABLE CLAY_RUNTIME_VERSION
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_QUIET
)
if(NOT CLAY_RUNTIME_VERSION)
    set(CLAY_RUNTIME_VERSION "dev")
endif()
target_compile_definitions(webdojo PRIVATE
    CLAY_RUNTIME_VERSION="${CLAY_RUNTIME_VERSION}")

set(CLAY_RUNTIME_QT_VERSION ${Qt6_VERSION})
set(CLAY_RUNTIME_EMSDK_VERSION "unknown")
if(DEFINED ENV{EMSDK} AND EXISTS "$ENV{EMSDK}/upstream/emscripten/emscripten-version.txt")
    file(READ "$ENV{EMSDK}/upstream/emscripten/emscripten-version.txt" _emver)
    string(REGEX REPLACE "[^0-9.]" "" _emver "${_emver}")
    set(CLAY_RUNTIME_EMSDK_VERSION "${_emver}")
endif()
configure_file(appshell/RUNTIME-MANIFEST.json.in
    ${CMAKE_CURRENT_BINARY_DIR}/RUNTIME-MANIFEST.json @ONLY)

# Starter bundle: everything a creator drops into their static site.
# Build with: cmake --build <dir> --target clayground_starter
set(CLAY_STARTER_DIR ${CMAKE_BINARY_DIR}/clayground-starter)
file(MAKE_DIRECTORY ${CLAY_STARTER_DIR})
add_custom_target(clayground_starter
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CLAY_STARTER_DIR}
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_BINARY_DIR}/bin/clayground.js
        ${CMAKE_BINARY_DIR}/bin/clayground.wasm
        ${CMAKE_BINARY_DIR}/bin/qtloader.js
        ${CMAKE_CURRENT_SOURCE_DIR}/appshell/index.html
        ${CMAKE_CURRENT_SOURCE_DIR}/appshell/Main.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/appshell/README.md
        ${CMAKE_SOURCE_DIR}/docs/coi-serviceworker.js
        ${CMAKE_CURRENT_BINARY_DIR}/RUNTIME-MANIFEST.json
        ${CLAY_STARTER_DIR}/
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/appshell/LICENSES
        ${CLAY_STARTER_DIR}/LICENSES
    COMMAND ${CMAKE_COMMAND} -E chdir ${CLAY_STARTER_DIR}
        ${CMAKE_COMMAND} -E tar cf ${CMAKE_BINARY_DIR}/clayground-starter.zip --format=zip --
        index.html Main.qml README.md clayground.js clayground.wasm
        qtloader.js coi-serviceworker.js RUNTIME-MANIFEST.json LICENSES
    DEPENDS webdojo
    COMMENT "Packaging Clayground starter bundle (clayground-starter.zip)"
)

# Register for website build
if(CLAY_BUILD_WEBSITE)
    clay_website_register_demo(webdojo)
endif()
