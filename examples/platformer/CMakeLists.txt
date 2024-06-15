# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( platformer

    VERSION 1.0

    SOURCES main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
        JnRPlayer.qml
        Player.qml
        Wall.qml
        WoodenBox.qml

    RES_FILES
        map.svg
        visuals.svg
)
