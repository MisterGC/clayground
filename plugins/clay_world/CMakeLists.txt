cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayWorld
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/World"
    URI Clayground.World
    SOURCES
        clayworldplugin.cpp clay_world.qrc qmldir.in
        Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml ClayPhysics
#}
)
