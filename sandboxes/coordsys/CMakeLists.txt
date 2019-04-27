cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (sbx_coordsys)
set (CMAKE_INCLUDE_CURRENT_DIR on)

add_executable (${PROJECT_NAME}
main.cpp
Angle.qml
Sandbox.qml
CoordCanvas.qml
Player.qml
Wall.qml
VisualizedBoxBody.qml)

set_target_properties (${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS NO
    )

