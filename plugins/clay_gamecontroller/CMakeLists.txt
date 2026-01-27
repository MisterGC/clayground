include (clayplugin)

clay_plugin( GameController

    VERSION 1.0

    QML_FILES
            GameController.qml
            GameControllerDV.qml
            GamepadWrapper.qml
            KeyboardGamepad.qml
            TouchscreenGamepad.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
