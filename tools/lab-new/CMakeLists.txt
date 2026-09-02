# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# lab-new builds nothing - it is a stdlib-only python3 script, the same
# convention as tools/lab-sweep and docs/scripts. This file exists so its
# checks reach CTest.
#
# Two kinds of check, for two kinds of claim:
#
#   lab_new              pure. What the generator writes: the file set, the
#                        dictionaries, the exit codes. No graphics, never skips.
#   lab_new_boot_<kind>  the claim that a template is a LOADABLE LAB. Boots the
#                        generated sandbox in clayliveloader offscreen and
#                        drives it through the inspector protocol. Skips (77)
#                        when the loader has not been built.
#
# The per-kind tests are DISCOVERED from the templates tree, so adding
# templates/build/Sandbox.qml adds lab_new_boot_build at the next configure -
# no line here changes.

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME lab_new
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_lab_new_tests.py)
        set_tests_properties(lab_new PROPERTIES LABELS "tools" TIMEOUT 120)

        if(TARGET clayliveloader)
            file(GLOB _lab_new_sandboxes
                 ${CMAKE_CURRENT_SOURCE_DIR}/templates/*/Sandbox.qml)
            foreach(_sbx IN LISTS _lab_new_sandboxes)
                get_filename_component(_dir ${_sbx} DIRECTORY)
                get_filename_component(_kind ${_dir} NAME)
                add_test(NAME lab_new_boot_${_kind}
                    COMMAND ${Python3_EXECUTABLE}
                            ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_boot_test.py
                            --loader $<TARGET_FILE:clayliveloader>
                            --kind ${_kind})
                set_tests_properties(lab_new_boot_${_kind} PROPERTIES
                    LABELS "tools;integration"
                    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_DISABLE_SHADER_DISK_CACHE=1"
                    SKIP_RETURN_CODE 77
                    TIMEOUT 180)
            endforeach()
        endif()
    endif()
endif()
