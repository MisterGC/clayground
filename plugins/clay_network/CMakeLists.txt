cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml Network)

clay_p( ClayNetwork
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Network"
    URI Clayground.Network
    SOURCES
        claynetworkplugin.cpp Sandbox.qml claynetworkuser.h claynetworkuser.cpp qmldir.in
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml Qt::Network
#}
)
