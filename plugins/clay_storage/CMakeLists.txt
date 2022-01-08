cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( Storage
    VERSION 1.0
    QML_FILES KeyValueStore.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml
)
