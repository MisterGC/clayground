# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# lab-check builds nothing - it is a stdlib-only python3 script, the same
# convention as tools/lab-sweep and tools/lab-new. This file exists so its own
# unit suite reaches CTest.
#
# Two kinds of check, for two kinds of claim:
#
#   lab_check          pure. What the tool REPORTS: the config it reads, the
#                      remark counter, the message a failed determinism run
#                      carries, that the scene drivers still render. No
#                      graphics, no lab, never skips.
#   lab_check_<lab>    the gates themselves, registered from labs/CMakeLists.txt
#                      because they belong to the labs, not to the tool.

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME lab_check
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_lab_check_tests.py)
        set_tests_properties(lab_check PROPERTIES LABELS "tools" TIMEOUT 60)
    endif()
endif()
