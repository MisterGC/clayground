include(clayplugin)

clay_plugin(Algorithm

    VERSION 1.0

    QML_FILES
        GridPathfinder.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
