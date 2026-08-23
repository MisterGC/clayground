# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for clay_character3d speech/lip-sync

find_package(Qt6 REQUIRED COMPONENTS Test Multimedia)

add_executable(tst_clay_character3d_speech
    tst_speech_timeline.cpp
    ../src/speech.cpp
    ../src/speech.h
    ../src/visemeanalysis.cpp
    ../src/visemeanalysis.h
    ../src/visemetimeline.h
)

# The spectral analyser is pure - no QObject, no media, no clock - so its
# suite links none of that. Formant thresholds are the arguable numbers in
# this plugin, and arguable numbers are the ones worth pinning.
add_executable(tst_clay_character3d_visemes
    tst_viseme_analysis.cpp
    ../src/visemeanalysis.cpp
    ../src/visemeanalysis.h
    ../src/visemetimeline.h
)
set_target_properties(tst_clay_character3d_visemes PROPERTIES AUTOMOC ON)
target_include_directories(tst_clay_character3d_visemes PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)
target_link_libraries(tst_clay_character3d_visemes PRIVATE
    Qt6::Core Qt6::Test
)
add_test(NAME clay_character3d_visemes COMMAND tst_clay_character3d_visemes)
set_tests_properties(clay_character3d_visemes PROPERTIES
    LABELS "clay_character3d;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

set_target_properties(tst_clay_character3d_speech PROPERTIES AUTOMOC ON)

target_include_directories(tst_clay_character3d_speech PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)

target_link_libraries(tst_clay_character3d_speech PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
    Qt6::Multimedia
)

add_test(NAME clay_character3d_speech COMMAND tst_clay_character3d_speech)
set_tests_properties(clay_character3d_speech PROPERTIES
    LABELS "clay_character3d;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
