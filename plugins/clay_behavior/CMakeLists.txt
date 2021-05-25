cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayBehavior
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Behavior"
    URI Clayground.Behavior
    SOURCES
        claybehaviorplugin.cpp clay_behavior.qrc qmldir.in
        Sandbox.qml DoorBuilder.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml ClayWorld
#}
)
