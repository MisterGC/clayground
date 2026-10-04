# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# verify.sh and its selector build nothing - stdlib-only python3, like
# lab-sweep. This file exists so the selector's unit suite reaches CTest.

find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_test(NAME verify_select
        COMMAND ${Python3_EXECUTABLE}
                ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_select_tests.py)
    set_tests_properties(verify_select PROPERTIES LABELS "tools;unit" TIMEOUT 30)
endif()
