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
    src/engine/bus.h
    src/engine/bus_effects.cpp src/engine/bus_effects.h
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
    src/song/song_parser.cpp src/song/song_parser.h
    src/sfx/sfx_recipe.h
    src/sfx/sfx_parser.cpp src/sfx/sfx_parser.h
    src/sfx/sfx_render.cpp src/sfx/sfx_render.h)

set(CPP_SRC
    src/voice_waveform.h
    src/audio_devices.cpp src/audio_devices.h
    src/audio_output.cpp src/audio_output.h
    src/softsynth.cpp src/softsynth.h
    src/synth_instrument.cpp src/synth_instrument.h
    src/sample_instrument.cpp src/sample_instrument.h
    src/source_url.cpp src/source_url.h
    src/song_player.cpp src/song_player.h
    src/sfx_player.cpp src/sfx_player.h
    src/sound_mixer.cpp src/sound_mixer.h
    src/bus_effect_objects.cpp src/bus_effect_objects.h
    src/sound.cpp src/sound.h
    src/music.cpp src/music.h
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
    QML_FILES MoodPlayer.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml ${EXTRA_LIBS}
)

target_include_directories(ClaySound PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
