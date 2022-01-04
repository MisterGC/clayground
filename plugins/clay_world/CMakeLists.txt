cmake_minimum_required(VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( World
    VERSION 1.0
    QML_FILES
        ClayWorld.qml
        MapLoader.qml
        Minimap.qml
        Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml ClayPhysics
)
