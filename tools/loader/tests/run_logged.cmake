# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Runs a Qt test with a log file beside its console output, and on a failure
# prints that file and the exit status. On Windows CI tst_annotations failed
# after its full run time with no output at all (#385): this says whether it
# failed checks, crashed on the way out, or lost its console.
#
#   cmake -P run_logged.cmake <test> <log file>
#
# Paths as plain arguments, not -D: tools/verify/select_tests.py maps a test to
# the targets whose files its arguments name.
set(EXE "${CMAKE_ARGV3}")
set(LOG "${CMAKE_ARGV4}")
execute_process(COMMAND ${EXE} -o ${LOG},txt -o -,txt RESULT_VARIABLE rc)
if(NOT rc STREQUAL "0")
    if(EXISTS ${LOG})
        file(READ ${LOG} text)
        message("--- ${LOG} ---\n${text}")
    else()
        message("--- no ${LOG} was written ---")
    endif()
    message(FATAL_ERROR "${EXE} exited with: ${rc}")
endif()
