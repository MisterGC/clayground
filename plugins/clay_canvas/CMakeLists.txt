cmake_minimum_required (VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayCanvas
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Canvas"
    URI Clayground.Canvas
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
