# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

function(clay_example EXAMPLE_NAME)

    cmake_minimum_required(VERSION 3.16)

    project (${EXAMPLE_NAME})

    set(CMAKE_INCLUDE_CURRENT_DIR ON)
    set(CMAKE_AUTORCC ON)
    find_package(Qt6 REQUIRED COMPONENTS Core Quick)

    configure_file(${CMAKE_SOURCE_DIR}/cmake/main_example.cpp.in main.cpp)
    add_executable (${PROJECT_NAME} ${CMAKE_CURRENT_BINARY_DIR}/main.cpp res.qrc)

    target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
    target_link_libraries(${PROJECT_NAME}
    PRIVATE
      Qt::Core
      Qt::Quick
    )

    add_test(NAME test${PROJECT_NAME} COMMAND ${PROJECT_NAME})
    set_tests_properties(test${PROJECT_NAME} PROPERTIES
        ENVIRONMENT "QSG_INFO=1;QT_OPENGL=software;QT_QPA_PLATFORM=minimal"
    )

endfunction()
