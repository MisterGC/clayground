cmake_minimum_required(VERSION 3.1)

project(clayrestarter LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 COMPONENTS Core REQUIRED)
add_executable(${PROJECT_NAME} 
clayrestarter.cpp
clayrestarter.h
main.cpp
)

target_link_libraries(${PROJECT_NAME} 
PRIVATE 
  Qt5::Core 
  pthread
)
