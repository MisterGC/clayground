cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (clayutilities)

find_package(Qt5 COMPONENTS Core REQUIRED)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library (${PROJECT_NAME} STATIC
  clayfilesysobserver.cpp
  clayfilesysobserver.h
  )

target_include_directories(${PROJECT_NAME} PUBLIC .)
target_link_libraries(${PROJECT_NAME}
PUBLIC 
  Qt5::Core 
)

