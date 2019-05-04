cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (sbx_coordsys)
set (CMAKE_INCLUDE_CURRENT_DIR on)

add_executable (${PROJECT_NAME}
main.cpp
Absorbicer.qml
Angle.qml
AiMap.qml
Sandbox.qml
ScalingText.qml
CoordCanvasDev.qml
Minigy.qml
Player.qml
PhysicsItem.qml
Wall.qml
Waypoint.qml
VisualizedBoxBody.qml)

set_target_properties (${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS NO
    )

