cmake_minimum_required(VERSION 3.16)
project(clayrestarter LANGUAGES CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 5.15 COMPONENTS Core Quick QuickWidgets REQUIRED)
find_package(Threads REQUIRED)

add_executable(${PROJECT_NAME}
    clayrestarter.cpp
    main.cpp
    main.qml
    res.qrc
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

target_link_libraries(${PROJECT_NAME}
PRIVATE 
  clayutilities
  Qt5::Core
  Qt5::Quick
  Qt5::QuickWidgets
  Threads::Threads
)
