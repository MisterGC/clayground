# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# lab-sweep builds nothing - it is a stdlib-only python3 script, the same
# convention as docs/scripts and tools/render/tests. This file exists so its
# unit suite reaches CTest.
#
# The lab_sweep suite is pure (manifest parsing, matrix expansion, record
# reading), so unlike the clayrender tests it needs no graphics session and
# never skips.

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME lab_sweep
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_sweep_tests.py)
        set_tests_properties(lab_sweep PROPERTIES LABELS "tools" TIMEOUT 60)
        # Lab.run() against the grid-capacity study's committed records
        # (#567): drives clayrender, so it needs a graphics session and
        # reports 77 without one. It runs the lab kernel and reads
        # street-network-101, so a change to either runs it (verify.sh, #384).
        # About 40 s alone; the timeout leaves room for a loaded machine.
        if(TARGET clayrender)
            add_test(NAME lab_run_grid_capacity
                COMMAND ${Python3_EXECUTABLE}
                        ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_lab_run_test.py
                        --clayrender $<TARGET_FILE:clayrender>)
            set_tests_properties(lab_run_grid_capacity PROPERTIES
                LABELS "integration;labs;plugins/clay_lab"
                SKIP_RETURN_CODE 77
                TIMEOUT 300)
            # Lab.snapshot()/restore() (#568): street-network-101 restored at
            # step 600 - in the same process and in a new one - writes the
            # record a straight 900-step run writes, byte for byte; and a
            # restore at 60 sim seconds of sensor-fusion-101 and
            # street-network-101 is timed. Five clayrender processes, about
            # 20 s alone.
            add_test(NAME lab_snapshot
                COMMAND ${Python3_EXECUTABLE}
                        ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_snapshot_test.py
                        --clayrender $<TARGET_FILE:clayrender>)
            set_tests_properties(lab_snapshot PROPERTIES
                LABELS "integration;labs;plugins/clay_lab"
                SKIP_RETURN_CODE 77
                TIMEOUT 300)
        endif()
    endif()
endif()
