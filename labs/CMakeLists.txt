# (c) Clayground Contributors - MIT License, see "LICENSE" file

# labs/ builds nothing - a lab is QML and Markdown, loaded by the dojo or the
# web runtime, never compiled. This file exists so the labs' checks reach
# CTest: the kits' pure-JS suites, and one gate per lab.
include(claytest)

clay_add_node_test(kit_circuit
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/circuit.test.js)
clay_add_node_test(kit_traffic
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/traffic/traffic.test.js)
clay_add_node_test(kit_sensor
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/sensor/sensor.test.js)
clay_add_node_test(kit_hydro
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/hydro/hydro.test.js)

# lab_check_<lab> - the lab contract, as a test that can go red (#208).
#
# The contract (deterministic runs, flows that pass, records that regenerate,
# EN and DE saying the same things) was discipline and nothing else until this
# existed, and nothing in ctest so much as loaded a lab. One test per lab, so a
# failure names the lab rather than "the labs".
#
# DISCOVERED from the tree: a directory with a Sandbox.qml is a lab and gets a
# gate at the next configure, with no line here to remember. Skips (77) when
# clayliveloader has not been built, because a contract check that fails on a
# machine with no build tells you nothing about the contract.
#
# The gate drives clayliveloader offscreen through the inspector protocol, one
# process per stepped run, so it is minutes rather than seconds: electronics-101
# runs eleven scenarios twice plus two flows. Run one by hand while working on a
# lab - `tools/lab-check/lab-check labs/<slug> --only flows` - and let ctest run
# the whole thing.
if(BUILD_TESTING AND TARGET clayliveloader)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        file(GLOB _lab_sandboxes ${CMAKE_CURRENT_SOURCE_DIR}/*/Sandbox.qml)
        foreach(_sbx IN LISTS _lab_sandboxes)
            get_filename_component(_dir ${_sbx} DIRECTORY)
            get_filename_component(_lab ${_dir} NAME)
            add_test(NAME lab_check_${_lab}
                COMMAND ${Python3_EXECUTABLE}
                        ${CMAKE_SOURCE_DIR}/tools/lab-check/lab_check.py
                        ${_dir}
                        --loader $<TARGET_FILE:clayliveloader>
                        --clayrender $<TARGET_FILE:clayrender>)
            set_tests_properties(lab_check_${_lab} PROPERTIES
                LABELS "labs;integration"
                SKIP_RETURN_CODE 77
                TIMEOUT 1800)
        endforeach()
    endif()
endif()
