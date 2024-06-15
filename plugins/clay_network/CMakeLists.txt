include (clayplugin)

clay_plugin( Network

    VERSION 1.1

    SOURCES
        claynetworknode.cpp
        claywebaccess.cpp
        connection.cpp
        peermanager.cpp
        server.cpp

    QML_FILES
        ClayNetworkUser.qml
        ClayHttpClient.qml
        Sandbox.qml
        SandboxHttpClient.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        Qt::Network
)
