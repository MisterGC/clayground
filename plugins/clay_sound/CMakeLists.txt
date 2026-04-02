# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback for games
# WASM: Web Audio API via Emscripten (C++ backend)
# Desktop/Mobile: Qt Multimedia (pure QML)
#
if(NOT EMSCRIPTEN)
    find_package(Qt6 COMPONENTS Multimedia REQUIRED)
endif()

include(clayplugin)

if(EMSCRIPTEN)
    set_source_files_properties(Sound_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Sound)
    set_source_files_properties(Music_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Music)
    set(SOUND_QML Sound_wasm.qml)
    set(MUSIC_QML Music_wasm.qml)
    set(CPP_SRC
        src/claysound.cpp src/claysound.h
        src/claymusic.cpp src/claymusic.h
        src/chipmood.cpp src/chipmood.h)
    set(EXTRA_LIBS "")
else()
    set(SOUND_QML Sound.qml)
    set(MUSIC_QML Music.qml)
    set(CPP_SRC src/chipmood.cpp src/chipmood.h src/softsynth.cpp src/softsynth.h)
    set(EXTRA_LIBS Qt::Multimedia)
endif()

clay_plugin(Sound
    VERSION 1.0
    SOURCES ${CPP_SRC}
    QML_FILES ${SOUND_QML} ${MUSIC_QML}
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
