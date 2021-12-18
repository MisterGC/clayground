cmake_minimum_required(VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayWorld
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/World"
    URI Clayground.World
    QML_FILES
        ClayWorld.qml
        MapLoader.qml
        Minimap.qml
        Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml ClayPhysics
)
