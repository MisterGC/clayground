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
        Qt::Quick3D
        Qt::Quick3DHelpers

    QML_FILES
        Main.qml
)

# Emscripten-specific settings for JS interop
# Note: Qt's qtloader.js handles WASM loading, we add --bind for embind
# and export ccall/cwrap for fallback access to exported C functions
target_link_options(webdojo PRIVATE
    "SHELL:--bind"
    "SHELL:-s EXPORTED_RUNTIME_METHODS=['ccall','cwrap']"
)

# Register for website build
if(CLAY_BUILD_WEBSITE)
    clay_website_register_demo(webdojo)
endif()
