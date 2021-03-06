cmake_minimum_required(VERSION 3.16)
project(clayrestarter LANGUAGES CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

import_qt_components(Core Quick QuickWidgets)
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
  Qt::Core
  Qt::Quick
  Qt::QuickWidgets
  Threads::Threads
)
