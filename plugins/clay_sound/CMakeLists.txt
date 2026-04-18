# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback for games
# WASM: Web Audio API via Emscripten (C++ backend)
# Desktop/Mobile: Qt Multimedia (pure QML)
#
if(NOT EMSCRIPTEN)
    find_package(Qt6 COMPONENTS Multimedia Widgets REQUIRED)
endif()

include(clayplugin)

# Stage 0 spine — platform-agnostic C++ engine. Compiled into both
# desktop and WASM plugin builds; has no QML types yet, no public API.
set(ENGINE_SRC
    src/engine/note_event.h
    src/engine/voice.h
    src/engine/instrument.h
    src/engine/scheduler.cpp src/engine/scheduler.h
    src/engine/engine.cpp src/engine/engine.h)

if(EMSCRIPTEN)
    set_source_files_properties(Sound_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Sound)
    set_source_files_properties(Music_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Music)
    set(SOUND_QML Sound_wasm.qml)
    set(MUSIC_QML Music_wasm.qml)
    set(CPP_SRC
        src/claysound.cpp src/claysound.h
        src/claymusic.cpp src/claymusic.h
        src/chiptracker.cpp src/chiptracker.h
        ${ENGINE_SRC})
    set(EXTRA_LIBS "")
else()
    set(SOUND_QML Sound.qml)
    set(MUSIC_QML Music.qml)
    set(CPP_SRC
        src/chiptracker.cpp src/chiptracker.h
        src/softsynth.cpp src/softsynth.h
        ${ENGINE_SRC})
    set(EXTRA_LIBS Qt::Multimedia Qt::Widgets)
endif()

clay_plugin(Sound
    VERSION 1.0
    SOURCES ${CPP_SRC}
    QML_FILES ${SOUND_QML} ${MUSIC_QML}
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
