cmake_minimum_required(VERSION 3.16)
project(clayliveloader LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 QuickWidgets Sql Qml)

add_executable(${PROJECT_NAME}
    main.cpp
    qmlres.qrc
    clayinspector.cpp
    clayinspector.h
    clayliveloader.cpp
    clayliveloader.h
    hotreloadcontainer.cpp
    hotreloadcontainer.h
    mainwindow.cpp
    mainwindow.h
    retroeffect.cpp
    retroeffect.h
    main.qml
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PROJECT_NAME} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)
target_compile_definitions(${PROJECT_NAME}
    PUBLIC CLAY_LOADER_VERSION="${CLAYGROUND_PROJECT_VERSION}")

target_link_libraries(${PROJECT_NAME}
PRIVATE
  claytoolscommon
  Qt::Core
  Qt::Quick
  Qt::QuickControls2
  Qt::QuickWidgets
  Qt::Sql
  Qt::Qml
)

if(NOT EMSCRIPTEN AND BUILD_TESTING)
    add_subdirectory(tests)
endif()

