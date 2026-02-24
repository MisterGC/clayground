# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback and analysis for games
# WASM: Web Audio API via Emscripten (C++ backend)
# Desktop/Mobile: Qt Multimedia
#
if(NOT EMSCRIPTEN)
    find_package(Qt6 COMPONENTS Multimedia REQUIRED)
endif()

include(clayplugin)

set(COMMON_SOURCES
    src/claymusicmonitor.cpp src/claymusicmonitor.h
)

if(EMSCRIPTEN)
    set_source_files_properties(Sound_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Sound)
    set_source_files_properties(Music_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Music)
    set(SOUND_QML Sound_wasm.qml)
    set(MUSIC_QML Music_wasm.qml)
    set(PLATFORM_SOURCES src/claysound.cpp src/claysound.h src/claymusic.cpp src/claymusic.h)
    set(EXTRA_LIBS "")
else()
    set(SOUND_QML Sound.qml)
    set(MUSIC_QML Music.qml)
    set(PLATFORM_SOURCES "")
    set(EXTRA_LIBS Qt::Multimedia)
endif()

clay_plugin(Sound
    VERSION 1.0
    SOURCES ${COMMON_SOURCES} ${PLATFORM_SOURCES}
    QML_FILES ${SOUND_QML} ${MUSIC_QML} MusicMonitor.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
