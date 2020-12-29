cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayWorld
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/World"
    URI Clayground.World
    SOURCES
        clayworldplugin.cpp clay_world.qrc qmldir.in
        Sandbox.qml
    LINK_LIBS
        Qt5::Core Qt5::Quick Qt5::Qml
#}
)
