cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayPhysics
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Physics"
    URI Clayground.Physics
    SOURCES
        clayphysicsplugin.cpp clay_physics.qrc qmldir.in
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml box2dqml
#}
)
