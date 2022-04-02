# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

macro(clay_example EXAMPLE_NAME)

    set (oneValueArgs VERSION)
    set (multiValueArgs SOURCES QML_FILES RES_FILES)
    cmake_parse_arguments(CLAYEXAMPLE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    cmake_minimum_required(VERSION 3.16)
    project (${EXAMPLE_NAME} VERSION ${CLAYEXAMPLE_VERSION})

    set(CMAKE_INCLUDE_CURRENT_DIR ON)

    set(CMAKE_AUTOUIC ON)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    find_package(Qt6 REQUIRED COMPONENTS Core Quick)

    configure_file(${CLAY_CMAKE_SCRIPT_DIR}/main_example.cpp.in main.cpp)
    qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION
        ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
        ${CLAYEXAMPLE_SOURCES} )

    qt_add_qml_module(${PROJECT_NAME}
        URI ${PROJECT_NAME}
        VERSION   ${CLAYEXAMPLE_VERSION}
        QML_FILES ${CLAYEXAMPLE_QML_FILES}
        RESOURCES ${CLAYEXAMPLE_RES_FILES}
    )

    target_compile_definitions(${PROJECT_NAME}
        PRIVATE
            $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>
            $<$<STREQUAL:"${CLAYPLUGIN_LINKING}","STATIC">:CLAYPLUGIN_LINKING_STATIC>
    )
    target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

    target_link_libraries(${PROJECT_NAME}
        PRIVATE
            Qt::Core
            Qt::Quick
            ${ALL_STATIC_CLAY_PLUGIN_TARGETS})

    qt_import_qml_plugins(${PROJECT_NAME})
    qt_finalize_executable(${PROJECT_NAME})

    if (NOT ANDROID)
        add_test(NAME test${PROJECT_NAME} COMMAND ${PROJECT_NAME})
        set_tests_properties(test${PROJECT_NAME} PROPERTIES
            ENVIRONMENT "QSG_INFO=1;QT_OPENGL=software;QT_QPA_PLATFORM=minimal"
        )
    endif()

endmacro()
