# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_world3d

    VERSION 1.0

    SOURCES main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
        Sandbox2d.qml
        Sandbox3d.qml
        Player2d.qml
        Player3d.qml
        Wall2d.qml
        Wall3d.qml

    RES_FILES map.svg
)
