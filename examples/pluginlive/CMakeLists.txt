cmake_minimum_required(VERSION 3.16)
project (sbx_plugin)

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

add_subdirectory(plugin)
