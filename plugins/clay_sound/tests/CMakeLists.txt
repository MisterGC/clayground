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
    ../src/synth_instrument.cpp
    ../src/synth_instrument.h
)

set_target_properties(tst_clay_sound_engine PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_sound_engine PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_sound_engine PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Qml
    Qt6::Multimedia
)

add_test(NAME clay_sound_engine COMMAND tst_clay_sound_engine)
set_tests_properties(clay_sound_engine PROPERTIES LABELS "clay_sound;unit")
