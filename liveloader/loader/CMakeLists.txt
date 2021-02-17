cmake_minimum_required(VERSION 3.16)
project(clayliveloader LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
import_qt_components(Core Quick QuickWidgets Sql)

add_executable(${PROJECT_NAME} 
    main.cpp
    qmlres.qrc
    clayliveloader.cpp
    main.qml
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PROJECT_NAME} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)

target_link_libraries(${PROJECT_NAME} 
PRIVATE 
  clayutilities
  Qt::Core
  Qt::Quick
  Qt::QuickWidgets
  Qt::Sql
)

