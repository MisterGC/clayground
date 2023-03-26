cmake_minimum_required(VERSION 3.16)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Network)

clay_p( Network
    VERSION 1.1
    SOURCES
        claynetworknode.cpp claywebaccess.cpp connection.cpp peermanager.cpp server.cpp
    QML_FILES
        ClayNetworkUser.qml ClayHttpClient.qml Sandbox.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml Qt::Network
)
