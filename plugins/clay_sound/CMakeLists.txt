# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback for games
# WASM: Web Audio API via Emscripten
# Desktop/Mobile: Qt Multimedia
#
if(NOT EMSCRIPTEN)
    find_package(Qt6 COMPONENTS Multimedia REQUIRED)
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

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        $<$<NOT:$<BOOL:${EMSCRIPTEN}>>:Qt::Multimedia>
)

# Add src directory to include paths for the generated code
target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
