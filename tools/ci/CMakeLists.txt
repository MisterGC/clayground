# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# CI's helpers build nothing - stdlib-only python3, like verify.sh's
# selector. This file exists so their suite reaches CTest.

find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
    add_test(NAME ci_ctest_retry
        COMMAND ${Python3_EXECUTABLE}
                ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_ctest_retry_tests.py
                ${CMAKE_COMMAND} ${CMAKE_CTEST_COMMAND})
    set_tests_properties(ci_ctest_retry PROPERTIES LABELS "tools;unit" TIMEOUT 60)
endif()
