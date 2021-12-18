cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayStorage
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Storage"
    URI Clayground.Storage
    QML_FILES KeyValueStore.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml
)
