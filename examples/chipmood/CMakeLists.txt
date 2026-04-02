# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_chipmood

    VERSION 1.0

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
)
