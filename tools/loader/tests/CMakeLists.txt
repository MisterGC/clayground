# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for ClayInspector (Clay Crew file-based protocol)

find_package(Qt6 REQUIRED COMPONENTS Test Quick Qml QuickWidgets)

# --- Unit tests (no GUI, null container) ---
add_executable(tst_inspector_unit
    tst_inspector_unit.cpp
    ../clayinspector.cpp
    ../clayinspector.h
    ../claycontrols.cpp
    ../claycontrols.h
    hotreloadcontainer_stub.cpp
)

set_target_properties(tst_inspector_unit PROPERTIES AUTOMOC ON)

target_include_directories(tst_inspector_unit PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_BINARY_DIR}/tst_inspector_unit_autogen/include
)

target_link_libraries(tst_inspector_unit PRIVATE
    clayscene
    Qt6::Core
    Qt6::Test
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickWidgets
)

add_test(NAME inspector_unit COMMAND tst_inspector_unit)
set_tests_properties(inspector_unit PROPERTIES LABELS "inspector;unit")

# --- Annotation surface (issue #182): store + the surface driven for real ---
add_executable(tst_annotations
    tst_annotations.cpp
    ../clayannotations.cpp
    ../clayannotations.h
    ../clayinspector.cpp
    ../clayinspector.h
    ../claycontrols.cpp
    ../claycontrols.h
    ../clayliveloader.cpp
    ../clayliveloader.h
    ../hotreloadcontainer.cpp
    ../hotreloadcontainer.h
    ../mainwindow.cpp
    ../mainwindow.h
    ../retroeffect.cpp
    ../retroeffect.h
    ../qmlres.qrc
)

set_target_properties(tst_annotations PROPERTIES AUTOMOC ON AUTORCC ON)

target_compile_definitions(tst_annotations PRIVATE
    SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}"
    CLAY_LOADER_VERSION="${CLAYGROUND_PROJECT_VERSION}"
)

target_include_directories(tst_annotations PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_BINARY_DIR}/tst_annotations_autogen/include
)

target_link_libraries(tst_annotations PRIVATE
    claytoolscommon
    clayscene
    Qt6::Core
    Qt6::Test
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::QuickWidgets
    Qt6::Sql
    Qt6::Widgets
)

add_test(NAME annotations COMMAND tst_annotations)
set_tests_properties(annotations PROPERTIES
    LABELS "annotations;gui"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
    TIMEOUT 120
)

# --- Integration tests (launches clayliveloader, exercises file protocol) ---
add_executable(tst_inspector_dojo
    tst_inspector_dojo.cpp
)

set_target_properties(tst_inspector_dojo PROPERTIES AUTOMOC ON)

target_compile_definitions(tst_inspector_dojo PRIVATE
    SRCDIR="${CMAKE_CURRENT_SOURCE_DIR}"
    LOADER_BIN="$<TARGET_FILE:clayliveloader>"
)

target_link_libraries(tst_inspector_dojo PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME inspector_dojo COMMAND tst_inspector_dojo)
set_tests_properties(inspector_dojo PROPERTIES
    LABELS "inspector;integration"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
    TIMEOUT 60
)

# --- Crew Gym (drives the full protocol v2 through the file interface) ---
find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_test(NAME crew_gym
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/gym/run_gym.py
                --loader $<TARGET_FILE:clayliveloader>
    )
    set_tests_properties(crew_gym PROPERTIES
        LABELS "inspector;integration;gym"
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
        TIMEOUT 180
    )
endif()
