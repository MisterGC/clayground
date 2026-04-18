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
    src/engine/engine.cpp src/engine/engine.h
    src/engine/oscillator_voice.cpp src/engine/oscillator_voice.h
    src/engine/oscillator_instrument.cpp src/engine/oscillator_instrument.h
    src/engine/pcm_buffer.cpp src/engine/pcm_buffer.h
    src/engine/sample_voice.cpp src/engine/sample_voice.h
    src/engine/sampler_instrument.cpp src/engine/sampler_instrument.h
    src/song/song_model.h
    src/song/song_parser.cpp src/song/song_parser.h)

if(EMSCRIPTEN)
    set_source_files_properties(Sound_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Sound)
    set_source_files_properties(Music_wasm.qml PROPERTIES QT_QML_SOURCE_TYPENAME Music)
    set(SOUND_QML Sound_wasm.qml)
    set(MUSIC_QML Music_wasm.qml)
    set(MOOD_QML MoodPlayer.qml)
    set(CPP_SRC
        src/claysound.cpp src/claysound.h
        src/claymusic.cpp src/claymusic.h
        src/chiptracker.cpp src/chiptracker.h
        src/chipmood.cpp src/chipmood.h
        ${ENGINE_SRC})
    set(EXTRA_LIBS "")
else()
    # Desktop: Sound is a C++ QML_ELEMENT (Sound.qml retired, see [#113]).
    set(SOUND_QML "")
    set(MUSIC_QML Music.qml)
    set(MOOD_QML MoodPlayer.qml)
    set(CPP_SRC
        src/chiptracker.cpp src/chiptracker.h
        src/chipmood.cpp src/chipmood.h
        src/softsynth.cpp src/softsynth.h
        src/synth_instrument.cpp src/synth_instrument.h
        src/sample_instrument.cpp src/sample_instrument.h
        src/sound.cpp src/sound.h
        ${ENGINE_SRC})
    set(EXTRA_LIBS Qt::Multimedia Qt::Widgets)
endif()

clay_plugin(Sound
    VERSION 1.0
    SOURCES ${CPP_SRC}
    QML_FILES ${SOUND_QML} ${MUSIC_QML} ${MOOD_QML}
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
