cmake_minimum_required(VERSION 3.1)

project(clayrestarter LANGUAGES CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 COMPONENTS Core Quick QuickWidgets REQUIRED)
find_package(Threads REQUIRED)
add_executable(${PROJECT_NAME}
clayrestarter.cpp
clayrestarter.h
main.cpp
PixelProgress.qml
SciFiWatch.qml
main.qml
res.qrc
)

target_link_libraries(${PROJECT_NAME}
PRIVATE 
  clayutilities
  Qt5::Core
  Qt5::Quick
  Qt5::QuickWidgets
  Threads::Threads
)
