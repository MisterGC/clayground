cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml Network)

clay_p( Network
    VERSION 1.0
    SOURCES
        claynetworknode.cpp connection.cpp peermanager.cpp server.cpp
    QML_FILES
        ClayNetworkUser.qml Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml Qt::Network
)
