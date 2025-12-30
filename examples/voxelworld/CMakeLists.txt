# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( voxelworld

    VERSION 1.0

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick
        Qt::Quick3D

    QML_FILES
        Main.qml
        Sandbox.qml
)
