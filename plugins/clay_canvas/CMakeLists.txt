include (clayplugin)

clay_plugin( Canvas

    VERSION 1.0

    QML_FILES
        ClayCanvas.qml
        Connector.qml
        Image.qml
        Poly.qml
        Rectangle.qml
        Text.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
