# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_gui

    VERSION 1.0

    SOURCES main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
        Scoreboard.qml
        ShortcutChecker.qml
        TrainingDb.qml

    RES_FILES
        inkscape.xml
        visuals.svg
)
