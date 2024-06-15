include (clayplugin)

clay_plugin( Storage

    VERSION 1.0

    QML_FILES KeyValueStore.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
