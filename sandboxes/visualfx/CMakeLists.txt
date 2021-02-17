cmake_minimum_required(VERSION 3.16)
project (sbx_visualfx)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)
import_qt_components(Core Quick)

add_executable (${PROJECT_NAME} main.cpp res.qrc)
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
