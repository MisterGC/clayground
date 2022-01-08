cmake_minimum_required (VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( Canvas
    VERSION 1.0
    QML_FILES
        ClayCanvas.qml
        Connector.qml
        Image.qml
        Poly.qml
        Rectangle.qml
        Text.qml
        Sandbox.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml
)
