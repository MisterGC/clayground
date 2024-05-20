include (clayplugin)

clay_plugin( Behavior

    VERSION 1.0

    QML_FILES
        FollowPath.qml
        Move.qml
        MoveTo.qml
        RectTrigger.qml
        WorldChangedConnections.qml
        Sandbox.qml
        DoorBuilder.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        ClayWorld
)
