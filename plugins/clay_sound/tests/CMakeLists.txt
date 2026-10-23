# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for clay_sound engine (Stage 0 spine)

find_package(Qt6 REQUIRED COMPONENTS Test Multimedia Network)

add_executable(tst_clay_sound_engine
    tst_engine.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
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
    ClaySoundEngine
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
)

set_target_properties(tst_clay_sound_song_parser PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_song_parser PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_song_parser PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Test
)

add_test(NAME clay_sound_song_parser COMMAND tst_clay_sound_song_parser)
set_tests_properties(clay_sound_song_parser PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# Song v2 offline (#430): the adaptive demo song switches state on a bar
# and fades a layer in by intensity, measured on renderSong(); the
# sequencer's sync points. Clayground::SoundEngine alone.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_song_v2
    tst_song_v2.cpp
)

set_target_properties(tst_clay_sound_song_v2 PROPERTIES AUTOMOC ON)

target_compile_definitions(tst_clay_sound_song_v2 PRIVATE
    CLAY_SOUND_DEMO_ADAPTIVE="${CMAKE_CURRENT_SOURCE_DIR}/../demo/songs/adaptive.song.json"
)

target_link_libraries(tst_clay_sound_song_v2 PRIVATE
    Clayground::SoundEngine
    Qt6::Core
    Qt6::Test
)

add_test(NAME clay_sound_song_v2 COMMAND tst_clay_sound_song_v2)
set_tests_properties(clay_sound_song_v2 PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# SongPlayer tests (drives a fake instrument via Q_INVOKABLE triggerNote).
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_song_player
    tst_song_player.cpp
    ../src/song_player.cpp
    ../src/song_player.h
    ../src/source_url.cpp
    ../src/source_url.h
    # SongPlayer's volume is a gain stage of AudioOutput's engine.
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    # renderOffline() reads the instruments' specs.
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
)

set_target_properties(tst_clay_sound_song_player PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_song_player PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_compile_definitions(tst_clay_sound_song_player PRIVATE
    CLAY_SOUND_DEMO_WAV="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sound.wav"
    CLAY_SOUND_DEMO_ADAPTIVE="${CMAKE_CURRENT_SOURCE_DIR}/../demo/songs/adaptive.song.json"
)

target_link_libraries(tst_clay_sound_song_player PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_song_player COMMAND tst_clay_sound_song_player)
set_tests_properties(clay_sound_song_player PROPERTIES LABELS "clay_sound;unit")

# ----------------------------------------------------------------------
# SynthInstrument::bake() tests (offline render + WAV bounce).
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_synth_bake
    tst_synth_bake.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
)

set_target_properties(tst_clay_sound_synth_bake PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_synth_bake PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_synth_bake PRIVATE
    ClaySoundEngine
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

# ----------------------------------------------------------------------
# SynthInstrument filter + pulse width, measured on offline renders.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_synth_filter
    tst_synth_filter.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
)

set_target_properties(tst_clay_sound_synth_filter PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_synth_filter PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_synth_filter PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_synth_filter COMMAND tst_clay_sound_synth_filter)
set_tests_properties(clay_sound_synth_filter PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ----------------------------------------------------------------------
# The stereo mix: pan, buses and gain stages, measured on offline renders.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_mix
    tst_sound_mix.cpp
    ../src/music.cpp
    ../src/music.h
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/sound_mixer.cpp
    ../src/sound_mixer.h
    ../src/bus_effect_objects.cpp
    ../src/bus_effect_objects.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
)

set_target_properties(tst_clay_sound_mix PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_mix PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_mix PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_mix COMMAND tst_clay_sound_mix)
set_tests_properties(clay_sound_mix PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ----------------------------------------------------------------------
# Sample interpolation and the voice cap, measured on offline renders.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_voices
    tst_sound_voices.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
)

set_target_properties(tst_clay_sound_voices PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_voices PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_voices PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_voices COMMAND tst_clay_sound_voices)
set_tests_properties(clay_sound_voices PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ----------------------------------------------------------------------
# The bus echo and reverb: delay, decay, FIR and tail, measured on
# offline renders, and set from QML.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_effects
    tst_sound_effects.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/bus_effect_objects.cpp
    ../src/bus_effect_objects.h
    ../src/sound_mixer.cpp
    ../src/sound_mixer.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
)

set_target_properties(tst_clay_sound_effects PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_effects PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_effects PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_effects COMMAND tst_clay_sound_effects)
set_tests_properties(clay_sound_effects PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ----------------------------------------------------------------------
# Effect recipes: parser, seeded variation and SfxPlayer, measured on
# offline renders and against live playback.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_sfx
    tst_sfx_recipe.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/source_url.cpp
    ../src/source_url.h
    ../src/sfx_player.cpp
    ../src/sfx_player.h
)

set_target_properties(tst_clay_sound_sfx PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_sfx PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_compile_definitions(tst_clay_sound_sfx PRIVATE
    CLAY_SOUND_DEMO_WAV="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sound.wav"
    CLAY_SOUND_DEMO_SFX="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sfx/wheel-detent.sfx.json"
)

target_link_libraries(tst_clay_sound_sfx PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_sfx COMMAND tst_clay_sound_sfx)
set_tests_properties(clay_sound_sfx PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# ----------------------------------------------------------------------
# Effect design files (#446): a template and a design file compile to a
# recipe through the engine library alone - no QML, no audio device.
# ----------------------------------------------------------------------

add_executable(tst_clay_sound_sfx_design tst_sfx_design.cpp)

set_target_properties(tst_clay_sound_sfx_design PROPERTIES AUTOMOC ON)

target_compile_definitions(tst_clay_sound_sfx_design PRIVATE
    CLAY_SOUND_DEMO_SFX_DIR="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sfx"
)

target_link_libraries(tst_clay_sound_sfx_design PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Test
)

add_test(NAME clay_sound_sfx_design COMMAND tst_clay_sound_sfx_design)
set_tests_properties(clay_sound_sfx_design PROPERTIES
    LABELS "clay_sound;unit"
)

# ----------------------------------------------------------------------
# The engine outside QML (#429): a program built against
# Clayground::SoundEngine alone renders the demo recipe and song to wav,
# and the QML players' offline renders hold the same samples.
# ----------------------------------------------------------------------

add_subdirectory(outside)

add_executable(tst_clay_sound_outside
    tst_render_outside.cpp
    ../src/audio_devices.cpp
    ../src/audio_devices.h
    ../src/audio_output.cpp
    ../src/audio_output.h
    ../src/source_url.cpp
    ../src/source_url.h
    ../src/sfx_player.cpp
    ../src/sfx_player.h
    ../src/song_player.cpp
    ../src/song_player.h
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
    ../src/sample_instrument.cpp
    ../src/sample_instrument.h
)

set_target_properties(tst_clay_sound_outside PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_outside PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_compile_definitions(tst_clay_sound_outside PRIVATE
    CLAY_SOUND_DEMO_SFX="${CMAKE_CURRENT_SOURCE_DIR}/../demo/sfx/wheel-detent.sfx.json"
    CLAY_SOUND_DEMO_SONG="${CMAKE_CURRENT_SOURCE_DIR}/../demo/songs/demo.song.json"
    CLAY_SOUND_RENDER_DEMO="$<TARGET_FILE:clay_sound_render_demo>"
)

add_dependencies(tst_clay_sound_outside clay_sound_render_demo)

target_link_libraries(tst_clay_sound_outside PRIVATE
    ClaySoundEngine
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_sound_outside COMMAND tst_clay_sound_outside)
set_tests_properties(clay_sound_outside PROPERTIES
    LABELS "clay_sound;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
