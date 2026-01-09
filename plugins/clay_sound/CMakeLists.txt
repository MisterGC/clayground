# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback for games
# Currently WASM-only (uses Web Audio API via Emscripten)
#
if(NOT EMSCRIPTEN)
    message(STATUS "clay_sound: Skipping (WASM build only for now)")
    return()
endif()

include(clayplugin)

clay_plugin(Sound
    VERSION 1.0

    SOURCES
        src/claysound.cpp
        src/claysound.h
        src/claymusic.cpp
        src/claymusic.h

    QML_FILES
        Sound.qml
        Music.qml
        Sandbox.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)

# Add src directory to include paths for the generated code
target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
