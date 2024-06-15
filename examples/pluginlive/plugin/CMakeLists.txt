project (MyPlugin)

include (clayplugin)

clay_plugin( MyPlugin

    VERSION 1.0
    URI Clayground.MyPlugin
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/MyPlugin"

    SOURCES  mycomponent.cpp

    QT_LIBS
        Core
        Qml
        Quick

    QML_FILES MyItem.qml
)
