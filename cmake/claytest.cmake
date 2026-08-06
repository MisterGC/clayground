# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

# Registers a QML test suite directory with CTest using qmltestrunner.
# Usage:
#   clay_add_qml_test(<Name>
#       DIRECTORY <dir-with-qml-tests>
#       [IMPORT_DIRS <additional-import-dirs>...]
#   )
function(clay_add_qml_test NAME)
    set(options IMPORTS_BUILT_MODULE)
    set(oneValueArgs DIRECTORY)
    set(multiValueArgs IMPORT_DIRS)
    cmake_parse_arguments(T "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT T_DIRECTORY)
        message(FATAL_ERROR "clay_add_qml_test: DIRECTORY is required")
    endif()

    # Ensure qmltestrunner is available
    find_package(Qt6 COMPONENTS Quick Qml QuickTest REQUIRED)

    # Try to resolve absolute path to qmltestrunner for reliable CTest runs
    set(_qt_hints)
    if(DEFINED QT_HOST_PATH)
        list(APPEND _qt_hints "${QT_HOST_PATH}/bin")
    endif()
    if(DEFINED Qt6_DIR)
        get_filename_component(_qt6_cmake_dir "${Qt6_DIR}" ABSOLUTE)
        get_filename_component(_qt_prefix "${_qt6_cmake_dir}/../../.." REALPATH)
        list(APPEND _qt_hints "${_qt_prefix}/bin")
    endif()
    if(DEFINED ENV{QTDIR})
        list(APPEND _qt_hints "$ENV{QTDIR}/bin")
    endif()
    find_program(QMLTESTRUNNER_EXECUTABLE NAMES qmltestrunner HINTS ${_qt_hints})
    if(NOT QMLTESTRUNNER_EXECUTABLE)
        # Fall back to PATH lookup, but warn so CI can be fixed
        set(QMLTESTRUNNER_EXECUTABLE qmltestrunner)
        message(WARNING "qmltestrunner not found via hints; relying on PATH. Set QT_HOST_PATH or ensure Qt bin is on PATH.")
    endif()

    # macOS: the shipped qmltestrunner is signed with Qt's team ID and runs with
    # the hardened runtime, which refuses to dlopen the ad-hoc signed plugins
    # this build produces - "mapping process and mapped file (non-platform) have
    # different Team IDs". So a suite that imports a built Clayground module
    # cannot run against it at all. An ad-hoc signed copy in the build tree has
    # no such restriction; it needs DYLD_FRAMEWORK_PATH because the copy no
    # longer sits next to Qt's lib directory.
    set(_runner "${QMLTESTRUNNER_EXECUTABLE}")
    set(_runner_env)
    if(APPLE AND _qt_prefix AND EXISTS "${QMLTESTRUNNER_EXECUTABLE}")
        find_program(CODESIGN_EXECUTABLE NAMES codesign)
        if(CODESIGN_EXECUTABLE)
            set(_runner_copy "${CMAKE_BINARY_DIR}/test-tools/qmltestrunner")
            file(COPY "${QMLTESTRUNNER_EXECUTABLE}"
                 DESTINATION "${CMAKE_BINARY_DIR}/test-tools")
            execute_process(
                COMMAND ${CODESIGN_EXECUTABLE} --force --sign - "${_runner_copy}"
                RESULT_VARIABLE _codesign_result
                OUTPUT_QUIET ERROR_QUIET)
            if(_codesign_result EQUAL 0)
                set(_runner "${_runner_copy}")
                set(_runner_env "DYLD_FRAMEWORK_PATH=${_qt_prefix}/lib")
            endif()
        endif()
    endif()

    # Compose QML import path (build path + optional extras)
    set(_imports "${CMAKE_BINARY_DIR}/bin/qml")
    if(T_IMPORT_DIRS)
        list(APPEND _imports ${T_IMPORT_DIRS})
    endif()

    # One -import per directory; qmltestrunner takes the flag repeatedly rather
    # than a joined path.
    set(_import_args)
    foreach(_dir IN LISTS _imports)
        list(APPEND _import_args -import ${_dir})
    endforeach()

    file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/test-results)

    # Register with CTest. QTest spells the report "-o <file>,<format>".
    add_test(NAME qml_${NAME}
        COMMAND ${_runner}
                -input ${T_DIRECTORY}
                ${_import_args}
                -o ${CMAKE_BINARY_DIR}/test-results/${NAME}.xml,junitxml
                -o -,txt
    )

    # Run headless, with software backend for stability
    set_tests_properties(qml_${NAME} PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=minimal;QT_OPENGL=software;${_runner_env}"
        LABELS "qml"
    )

    # QML2_IMPORT_PATH goes through ENVIRONMENT_MODIFICATION rather than being
    # spliced into ENVIRONMENT by hand: its entries are joined with the
    # platform's path separator, and a Windows path starts "C:/", so a
    # hand-written ":" would split at the drive letter.
    set(_env_mod)
    foreach(_dir IN LISTS _imports)
        list(APPEND _env_mod "QML2_IMPORT_PATH=path_list_append:${_dir}")
    endforeach()

    # A suite that imports a *built* Clayground module loads a plugin binary,
    # and that binary links against the other Clayground libraries in bin/.
    # Windows resolves a DLL's dependencies from PATH and nothing else, so
    # without this the plugin fails to load, qmltestrunner exits immediately and
    # the test fails with no output at all. Suites that import QML sources by
    # directory never noticed.
    if(WIN32)
        list(APPEND _env_mod "PATH=path_list_prepend:${CMAKE_BINARY_DIR}/bin")
    endif()

    set_tests_properties(qml_${NAME} PROPERTIES
        ENVIRONMENT_MODIFICATION "${_env_mod}")

    # A suite that imports a built Clayground module does not run on Windows
    # yet: qmltestrunner exits non-zero having printed nothing at all, so there
    # is nothing to diagnose from a CI log. Prepending bin/ to PATH got it from
    # 0.11s to 0.40s - the plugin now loads - but it still fails silently.
    # Suites importing QML sources by directory are unaffected and stay on.
    # Tracked in #192; do not widen this without a way to see the runner's
    # output on Windows.
    if(WIN32 AND T_IMPORTS_BUILT_MODULE)
        set_tests_properties(qml_${NAME} PROPERTIES DISABLED TRUE)
    endif()
endfunction()
