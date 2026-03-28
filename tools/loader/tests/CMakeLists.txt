# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for ClayInspector (Clay Crew file-based protocol)

find_package(Qt6 REQUIRED COMPONENTS Test Quick Qml QuickWidgets)

# --- Unit tests (no GUI, null container) ---
add_executable(tst_inspector_unit
    tst_inspector_unit.cpp
    ../clayinspector.cpp
    ../clayinspector.h
    hotreloadcontainer_stub.cpp
)

set_target_properties(tst_inspector_unit PROPERTIES AUTOMOC ON)

target_include_directories(tst_inspector_unit PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/..
    ${CMAKE_CURRENT_BINARY_DIR}/tst_inspector_unit_autogen/include
)

target_link_libraries(tst_inspector_unit PRIVATE
    Qt6::Core
    Qt6::Test
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickWidgets
)

add_test(NAME inspector_unit COMMAND tst_inspector_unit)
set_tests_properties(inspector_unit PROPERTIES LABELS "inspector;unit")

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
