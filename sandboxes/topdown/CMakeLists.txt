cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (topdown)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 COMPONENTS Core Quick REQUIRED)

add_executable (${PROJECT_NAME}
main.cpp
main.qml
Sandbox.qml
Player.qml
Wall.qml
res.qrc
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

target_link_libraries(${PROJECT_NAME}
PRIVATE
  Qt5::Core
  Qt5::Quick
)
