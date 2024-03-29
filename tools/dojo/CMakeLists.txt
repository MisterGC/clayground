cmake_minimum_required(VERSION 3.16)
project(claydojo LANGUAGES CXX)

set(THREADS_PREFER_PTHREAD_FLAG ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickWidgets Quick3D Quick3DPhysics)
find_package(Threads REQUIRED)

add_executable(${PROJECT_NAME}
    claydojo.cpp
    main.cpp
    main.qml
    res.qrc
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PROJECT_NAME}
    PUBLIC CLAY_DOJO_VERSION="${CLAYGROUND_PROJECT_VERSION}")

target_link_libraries(${PROJECT_NAME}
PRIVATE 
  claytoolscommon
  Qt::Core
  Qt::Quick
  Qt::QuickWidgets
  Qt::Quick3D
  Qt::Quick3DPhysics
  Threads::Threads
)
