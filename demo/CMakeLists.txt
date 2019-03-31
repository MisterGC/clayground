cmake_minimum_required(VERSION 3.1)

project(qml_live_loader LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 COMPONENTS Core Quick REQUIRED)

add_executable(${PROJECT_NAME} 
		main.cpp 
		qmlenginewrapper.cpp
		qmlenginewrapper.h
                qmlfileobserver.cpp
                qmlfileobserver.h
                qml/main.qml
                qml/Angle.qml
                qml/LiveLoader.qml
		qml/TestComponent.qml
		qml/EmbeddedComponent.qml
)

target_compile_definitions(${PROJECT_NAME} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)

target_link_libraries(${PROJECT_NAME} 
PRIVATE 
  Qt5::Core 
  Qt5::Quick
)

