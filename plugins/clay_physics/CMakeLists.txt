cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayPhysics
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Physics"
    URI Clayground.Physics
    SOURCES
        clayphysicsplugin.cpp clay_physics.qrc qmldir.in
    LINK_LIBS
        Qt6::Core Qt6::Quick Qt6::Qml
#}
)
