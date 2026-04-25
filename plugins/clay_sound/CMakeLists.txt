# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Sound Plugin - Audio playback for games
# Unified desktop + WASM build: Qt Multimedia's QAudioSink drives the
# clay::sound engine on both targets (WASM uses the emscripten backend).
#
find_package(Qt6 COMPONENTS Multimedia Network REQUIRED)
if(NOT EMSCRIPTEN)
    find_package(Qt6 COMPONENTS Widgets REQUIRED)
endif()

include(clayplugin)

# Platform-agnostic C++ engine (Stage 0 spine). No QML types; used by
# every instrument host below.
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

set(CPP_SRC
    src/voice_waveform.h
    src/softsynth.cpp src/softsynth.h
    src/synth_instrument.cpp src/synth_instrument.h
    src/sample_instrument.cpp src/sample_instrument.h
    src/song_player.cpp src/song_player.h
    src/sound.cpp src/sound.h
    src/chiptracker.cpp src/chiptracker.h
    src/chipmood.cpp src/chipmood.h
    ${ENGINE_SRC})

set(EXTRA_LIBS Qt::Multimedia Qt::Network)
if(NOT EMSCRIPTEN)
    list(APPEND EXTRA_LIBS Qt::Widgets)
endif()

clay_plugin(Sound
    VERSION 1.0
    SOURCES ${CPP_SRC}
    QML_FILES Music.qml MoodPlayer.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
