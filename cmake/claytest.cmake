# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

# Registers a QML test suite directory with CTest using qmltestrunner.
# Usage:
#   clay_add_qml_test(<Name>
#       DIRECTORY <dir-with-qml-tests>
#       [IMPORT_DIRS <additional-import-dirs>...]
#   )
function(clay_add_qml_test NAME)
    set(options)
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

    # Compose QML import path (build path + optional extras)
    set(_imports "${CMAKE_BINARY_DIR}/bin/qml")
    if(T_IMPORT_DIRS)
        list(APPEND _imports ${T_IMPORT_DIRS})
    endif()
    string(REPLACE ";" ":" _imports_env "${_imports}")

    # Register with CTest
    add_test(NAME qml_${NAME}
        COMMAND ${QMLTESTRUNNER_EXECUTABLE}
                -input ${T_DIRECTORY}
                -import ${_imports_env}
                -o junitxml
                -output ${CMAKE_BINARY_DIR}/test-results/${NAME}.xml
    )

    # Run headless, with software backend for stability
    set_tests_properties(qml_${NAME} PROPERTIES
        ENVIRONMENT "QML2_IMPORT_PATH=${_imports_env};QT_QPA_PLATFORM=minimal;QT_OPENGL=software"
        LABELS "qml"
    )
endfunction()
