cmake_minimum_required(VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayGameController
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/GameController"
    URI Clayground.GameController
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
