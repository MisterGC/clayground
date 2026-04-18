# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for clay_sound engine (Stage 0 spine)

find_package(Qt6 REQUIRED COMPONENTS Test Multimedia)

add_executable(tst_clay_sound_engine
    tst_engine.cpp
    ../src/engine/scheduler.cpp
    ../src/engine/scheduler.h
    ../src/engine/engine.cpp
    ../src/engine/engine.h
    ../src/engine/voice.h
    ../src/engine/instrument.h
    ../src/engine/note_event.h
    ../src/engine/oscillator_voice.cpp
    ../src/engine/oscillator_voice.h
    ../src/engine/oscillator_instrument.cpp
    ../src/engine/oscillator_instrument.h
    ../src/engine/pcm_buffer.cpp
    ../src/engine/pcm_buffer.h
    ../src/engine/sample_voice.cpp
    ../src/engine/sample_voice.h
    ../src/engine/sampler_instrument.cpp
    ../src/engine/sampler_instrument.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
)

set_target_properties(tst_clay_sound_engine PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_engine PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_compile_definitions(tst_clay_sound_engine PRIVATE
    CLAY_SOUND_DEMO_WAV="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sound.wav"
)

target_link_libraries(tst_clay_sound_engine PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Qml
    Qt6::Multimedia
)

add_test(NAME clay_sound_engine COMMAND tst_clay_sound_engine)
set_tests_properties(clay_sound_engine PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# Song parser tests (pure data; no audio).
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_song_parser
    tst_song_parser.cpp
    ../src/song/song_model.h
    ../src/song/song_parser.cpp
    ../src/song/song_parser.h
)

set_target_properties(tst_clay_sound_song_parser PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_song_parser PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_song_parser PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME clay_sound_song_parser COMMAND tst_clay_sound_song_parser)
set_tests_properties(clay_sound_song_parser PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# SongPlayer tests (drives a fake instrument via Q_INVOKABLE triggerNote).
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_song_player
    tst_song_player.cpp
    ../src/song_player.cpp
    ../src/song_player.h
    ../src/song/song_model.h
    ../src/song/song_parser.cpp
    ../src/song/song_parser.h
)

set_target_properties(tst_clay_sound_song_player PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_song_player PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_song_player PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
)

add_test(NAME clay_sound_song_player COMMAND tst_clay_sound_song_player)
set_tests_properties(clay_sound_song_player PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# SynthInstrument::bake() tests (offline render + WAV bounce).
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_synth_bake
    tst_synth_bake.cpp
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
    ../src/engine/scheduler.cpp
    ../src/engine/scheduler.h
    ../src/engine/engine.cpp
    ../src/engine/engine.h
    ../src/engine/voice.h
    ../src/engine/instrument.h
    ../src/engine/note_event.h
    ../src/engine/oscillator_voice.cpp
    ../src/engine/oscillator_voice.h
    ../src/engine/oscillator_instrument.cpp
    ../src/engine/oscillator_instrument.h
    ../src/engine/pcm_buffer.cpp
    ../src/engine/pcm_buffer.h
    ../src/engine/sample_voice.cpp
    ../src/engine/sample_voice.h
    ../src/engine/sampler_instrument.cpp
    ../src/engine/sampler_instrument.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
)

set_target_properties(tst_clay_sound_synth_bake PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_synth_bake PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_synth_bake PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_synth_bake COMMAND tst_clay_sound_synth_bake)
set_tests_properties(clay_sound_synth_bake PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
