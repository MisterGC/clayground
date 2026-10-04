# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for the scene access shared by the dojo, clayrender and the web runtime

find_package(Qt6 REQUIRED COMPONENTS Core Test Qml Quick)

add_executable(tst_scene_eval tst_scene_eval.cpp)
set_target_properties(tst_scene_eval PROPERTIES AUTOMOC ON)
target_link_libraries(tst_scene_eval PRIVATE
    clayscene
    Qt6::Core
    Qt6::Test
    Qt6::Qml
    Qt6::Quick
)
add_test(NAME scene_eval COMMAND tst_scene_eval)
set_tests_properties(scene_eval PROPERTIES
    LABELS "inspector;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)
