# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)
clay_app (sbx_plugin

    VERSION 1.0

    SOURCES main.cpp

    QML_FILES
        Main.qml
        Sandbox.qml

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick
)
add_subdirectory (plugin)
