# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# PATCH_COMMAND for FetchContent: applies PATCH in the working directory
# unless it is applied already, so a repopulation of an already patched
# checkout does not fail. Usage: cmake -DPATCH=<file> -P apply_patch.cmake
find_package(Git REQUIRED)
execute_process(COMMAND ${GIT_EXECUTABLE} apply --reverse --check ${PATCH}
                RESULT_VARIABLE already_applied OUTPUT_QUIET ERROR_QUIET)
if(already_applied EQUAL 0)
    return()
endif()
execute_process(COMMAND ${GIT_EXECUTABLE} apply ${PATCH} RESULT_VARIABLE failed)
if(failed)
    message(FATAL_ERROR "Could not apply ${PATCH}")
endif()
