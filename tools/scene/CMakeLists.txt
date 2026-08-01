cmake_minimum_required(VERSION 3.16)
project (clayscene)

# Scene access shared by every host of a loaded sandbox: the dojo
# (QQuickWidget), clayrender (render-control window) and, later, the web
# runtime (QQuickWindow). Core/Gui/Qml/Quick only - linking QtWidgets here
# would lock the web runtime out (see issue #173).
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

add_library (${PROJECT_NAME} STATIC
    clayscenecapture.cpp
    clayscenecapture.h
    clayscenehost.cpp
    clayscenehost.h
    clayscenequery.cpp
    clayscenequery.h
    claysettle.cpp
    claysettle.h
)

target_include_directories(${PROJECT_NAME} PUBLIC .)
target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_link_libraries(${PROJECT_NAME}
PUBLIC
  Qt::Core
  Qt::Gui
  Qt::Qml
  Qt::Quick
)
