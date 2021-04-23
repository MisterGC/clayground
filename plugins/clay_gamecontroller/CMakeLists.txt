cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayGameController
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/GameController"
    URI Clayground.GameController
    SOURCES
        claygamectrlplugin.cpp clay_controller.qrc qmldir.in Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml
#}
)
