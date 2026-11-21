# (c) Clayground Contributors - MIT License, see "LICENSE" file

# labs/ builds nothing - a lab is QML and Markdown, loaded by the dojo or the
# web runtime, never compiled. This file exists so the labs' checks reach
# CTest: the kits' pure-JS suites, and one gate per lab.
include(claytest)

clay_add_node_test(kit_circuit
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/circuit.test.js)
clay_add_node_test(kit_circuit_plan
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/plan.test.js)
clay_add_node_test(kit_circuit_route
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/route.test.js)
clay_add_node_test(kit_traffic
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/traffic/traffic.test.js)
clay_add_node_test(kit_sensor
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/sensor/sensor.test.js)
clay_add_node_test(kit_hydro
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/hydro/hydro.test.js)
# The part tables behind the two ExplodedView3D subjects (#274): what the
# transistor and the valve are made of, checked against the kernel's rules.
clay_add_node_test(kit_circuit_anatomy
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/anatomy.test.js)
clay_add_node_test(kit_hydro_valve
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/hydro/valve.test.js)
clay_add_node_test(kit_character
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/character/sheet.test.js)

# website_lab_pages - every lab gets a page on the website (#533). The
# importer finds labs the same way as the gates below, and this goes red when
# one has none (no paper.md, an H1 it cannot read). Pure python, never skips.
if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME website_lab_pages
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_SOURCE_DIR}/docs/scripts/tests/test_import_labs.py)
        set_tests_properties(website_lab_pages PROPERTIES
            LABELS "labs;docs" TIMEOUT 60)
    endif()
endif()

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
        # Two pages that are not labs and that nothing else loads: the
        # kernel's demo page, which puts every instrument on one page, and
        # the professor kit's sandbox. A warning either logs on load is a
        # kernel or kit defect, so they get lab-check's load stage alone
        # (#532). Registered here rather than beside the kernel because this
        # is where clayliveloader is known to exist; the labels are what make
        # verify.sh run them when the kernel or the script changes.
        add_test(NAME lab_kernel_demo_load
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_SOURCE_DIR}/tools/lab-check/load_check.py
                    ${CMAKE_SOURCE_DIR}/plugins/clay_lab/demo/Sandbox.qml
                    --loader $<TARGET_FILE:clayliveloader>)
        add_test(NAME kit_professor_load
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_SOURCE_DIR}/tools/lab-check/load_check.py
                    ${CMAKE_CURRENT_SOURCE_DIR}/kits/professor/Sandbox.qml
                    --loader $<TARGET_FILE:clayliveloader>)
        set_tests_properties(lab_kernel_demo_load PROPERTIES
            LABELS "labs;integration;plugins/clay_lab;tools/lab-check"
            SKIP_RETURN_CODE 77 TIMEOUT 180)
        set_tests_properties(kit_professor_load PROPERTIES
            LABELS "labs;integration;tools/lab-check"
            SKIP_RETURN_CODE 77 TIMEOUT 180)

        # lab_rest_<lab> / lab_moving_<lab> - a lab with nothing moving draws
        # no frame, and one with a current or a flow draws again (#575). Both
        # labs drew 60 frames a second at rest, and only a frame count says
        # so. The rest check of electronics-101 also holds the professor to
        # having no body loaded while it is away.
        if(TARGET clayrender)
            set(_rest ${CMAKE_SOURCE_DIR}/tools/lab-check/rest_check.py)
            set(_elec ${CMAKE_CURRENT_SOURCE_DIR}/electronics-101/Sandbox.qml)
            set(_hydro ${CMAKE_CURRENT_SOURCE_DIR}/hydraulics-101/Sandbox.qml)
            set(_switchOn "root.elements.filter(e => e.type === 'switch').forEach(e => root.setSwitch(e.id, true))")
            add_test(NAME lab_rest_electronics-101
                COMMAND ${Python3_EXECUTABLE} ${_rest} ${_elec} --expect rest
                        --wait-for "clock.resting && !prof.present && prof.character === null"
                        --clayrender $<TARGET_FILE:clayrender>)
            add_test(NAME lab_moving_electronics-101
                COMMAND ${Python3_EXECUTABLE} ${_rest} ${_elec} --expect moving
                        --eval "${_switchOn}" --wait-for "wires3d.flowing"
                        --clayrender $<TARGET_FILE:clayrender>)
            # hydraulics-101 opens with water running; the valve shuts it off
            add_test(NAME lab_rest_hydraulics-101
                COMMAND ${Python3_EXECUTABLE} ${_rest} ${_hydro} --expect rest
                        --eval "root.setValve(2, false)" --wait-for "clock.resting"
                        --clayrender $<TARGET_FILE:clayrender>)
            add_test(NAME lab_moving_hydraulics-101
                COMMAND ${Python3_EXECUTABLE} ${_rest} ${_hydro} --expect moving
                        --wait-for "wires3d.flowing"
                        --clayrender $<TARGET_FILE:clayrender>)
            set_tests_properties(lab_rest_electronics-101 lab_moving_electronics-101
                                 lab_rest_hydraulics-101 lab_moving_hydraulics-101
                PROPERTIES LABELS "labs;integration;plugins/clay_lab;tools/lab-check"
                           SKIP_RETURN_CODE 77 TIMEOUT 180)
        endif()

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
