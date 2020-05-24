cmake_minimum_required(VERSION 3.1)

project(clayliveloader LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 COMPONENTS Core Quick QuickWidgets Sql REQUIRED)

add_executable(${PROJECT_NAME} 
		main.cpp 
		qmlres.qrc
		clayliveloader.cpp
		clayliveloader.h
		main.qml
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PROJECT_NAME} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)

target_link_libraries(${PROJECT_NAME} 
PRIVATE 
  clayutilities
  Qt5::Core 
  Qt5::Quick
  Qt5::QuickWidgets
  Qt5::Sql
)

