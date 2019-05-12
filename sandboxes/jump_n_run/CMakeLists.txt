cmake_minimum_required (VERSION 3.5.0 FATAL_ERROR)
project (jump_n_run)
set (CMAKE_INCLUDE_CURRENT_DIR on)

add_executable (${PROJECT_NAME}
main.cpp
PhysicsItem.qml
Player.qml
Sandbox.qml
ScalingText.qml
VisualizedBoxBody.qml
VisualizedCircleBody.qml
Wall.qml
)

set_target_properties (${PROJECT_NAME} PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS NO
    )

