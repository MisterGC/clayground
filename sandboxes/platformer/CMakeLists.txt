cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
project (platformer)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt5 5.14 COMPONENTS Core Quick REQUIRED)

add_executable (${PROJECT_NAME} main.cpp res.qrc)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME}
PRIVATE
  Qt5::Core
  Qt5::Quick
)

add_test(NAME test${PROJECT_NAME} COMMAND ${PROJECT_NAME})
set_tests_properties(test${PROJECT_NAME} PROPERTIES
    ENVIRONMENT "QSG_INFO=1;QT_OPENGL=software;QT_QPA_PLATFORM=minimal"
)
