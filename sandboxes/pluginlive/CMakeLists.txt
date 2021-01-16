cmake_minimum_required(VERSION 3.16)
project (sbx_plugin)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)
find_package(Qt6 COMPONENTS Core Quick REQUIRED)

add_executable (${PROJECT_NAME} main.cpp res.qrc)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME}
PRIVATE
  Qt6::Core
  Qt6::Quick
)
