project (MyPlugin)

include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_p( MyPlugin
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/MyPlugin"
    URI Clayground.MyPlugin
    QML_FILES MyItem.qml
    SOURCES  mycomponent.cpp
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml
)
