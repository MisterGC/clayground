cmake_minimum_required(VERSION 3.16)
project (clayutilities)

find_package(Qt6 COMPONENTS Core REQUIRED)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

add_library (${PROJECT_NAME} STATIC
    clayfilesysobserver.cpp
    utilityfunctions.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC .)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME}
PUBLIC 
  Qt6::Core 
)

