# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# lab-sweep builds nothing - it is a stdlib-only python3 script, the same
# convention as docs/scripts and tools/render/tests. This file exists so its
# unit suite reaches CTest.
#
# The suite is pure (manifest parsing, matrix expansion, record reading), so
# unlike the clayrender test it needs no graphics session and never skips.

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME lab_sweep
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_sweep_tests.py)
        set_tests_properties(lab_sweep PROPERTIES LABELS "tools" TIMEOUT 60)
    endif()
endif()
