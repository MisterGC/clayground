# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# A program the way one outside clayground builds against the sound
# engine (#429): Clayground::SoundEngine is its only dependency - no
# include path, no QML, no Multimedia.

add_executable(clay_sound_render_demo render_demo.cpp)
target_link_libraries(clay_sound_render_demo PRIVATE Clayground::SoundEngine)

add_test(NAME clay_sound_render_demo
    COMMAND clay_sound_render_demo ${CMAKE_CURRENT_BINARY_DIR}/render_demo
        ${CMAKE_CURRENT_SOURCE_DIR}/../../demo/sfx/wheel-detent.sfx.json
        ${CMAKE_CURRENT_SOURCE_DIR}/../../demo/songs/demo.song.json 1 2)
set_tests_properties(clay_sound_render_demo PROPERTIES LABELS "clay_sound;unit")
