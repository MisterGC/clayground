cmake_minimum_required(VERSION 3.19)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_plugin( GameController
    VERSION 1.0
    QML_FILES
            Sandbox.qml
            GameController.qml
            GameControllerDV.qml
            GamepadWrapper.qml
            KeyboardGamepad.qml
            TouchscreenGamepad.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml
)
