// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype GameController
    \inqmlmodule Clayground.GameController
    \brief A unified game input system supporting keyboard, gamepad, and touchscreen.

    GameController provides a simple NES-style controller abstraction with directional
    axis controls and two action buttons. It supports multiple input sources that can
    be switched at runtime.

    Example usage:
    \qml
    import Clayground.GameController

    GameController {
        id: controller
        showDebugOverlay: true

        Component.onCompleted: {
            selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
                          Qt.Key_Space, Qt.Key_Return)
        }
    }

    Rectangle {
        x: x + controller.axisX * 5
        y: y - controller.axisY * 5
        color: controller.buttonAPressed ? "red" : "blue"
    }
    \endqml

    \qmlproperty real GameController::axisX
    \brief Horizontal directional axis value in range [-1, 1].

    \qmlproperty real GameController::axisY
    \brief Vertical directional axis value in range [-1, 1].

    \qmlproperty bool GameController::buttonAPressed
    \brief True when button A is pressed.

    \qmlproperty bool GameController::buttonBPressed
    \brief True when button B is pressed.

    \qmlproperty bool GameController::showDebugOverlay
    \brief Shows a visual debug overlay displaying controller state.

    \qmlproperty bool GameController::gamepadSelected
    \readonly
    \brief True if a physical gamepad is the active input source.

    \qmlproperty bool GameController::vGamepadSelected
    \readonly
    \brief True if touchscreen gamepad is the active input source.

    \qmlproperty bool GameController::keyboardSelected
    \readonly
    \brief True if keyboard is the active input source.

    \qmlproperty var GameController::gamepad
    \readonly
    \brief Reference to the connected physical gamepad, or null.

    \qmlproperty int GameController::gamepadDeviceId
    \readonly
    \brief Device ID of the connected gamepad, or -1 if none.

    \qmlproperty int GameController::numConnectedGamepads
    \readonly
    \brief Number of currently connected physical gamepads.

    \qmlmethod void GameController::selectGamepad(int gamePadIdx, bool useAnalogAxis)
    \brief Selects a physical gamepad as the input source.

    \a gamePadIdx is the index of the gamepad to select.
    \a useAnalogAxis if true uses analog sticks, otherwise uses D-pad.

    \qmlmethod void GameController::selectKeyboard(var upKey, var downKey, var leftKey, var rightKey, var buttonAKey, var buttonBKey)
    \brief Configures keyboard as the input source with specified key mappings.

    All parameters are Qt.Key values for the respective directions and buttons.

    \qmlmethod void GameController::selectTouchscreenGamepad()
    \brief Enables the touchscreen virtual gamepad overlay.
*/
import QtQuick

Item {
    id: theController

    // State of "directional" control axis in [-1;1]
    property real axisX: 0
    property real axisY: 0

    // Currently only two buttons are supported
    property bool buttonAPressed: false
    property bool buttonBPressed: false

    // Visualizes the state of the GameController
    property alias showDebugOverlay: theDebugVisu.visible

    // Which input source is selected?
    readonly property bool gamepadSelected: gamepadDeviceId !== -1
    readonly property bool vGamepadSelected: vgamepad.enabled
    readonly property bool keyboardSelected: keybGamepad.enabled

    // All properties of a connected, physical gamepad
    // TODO: Reactivate Gamepad
    readonly property var gamepad: null//gamepadLoader.item
    readonly property int gamepadDeviceId: gamepad ? gamepad.deviceId : -1
    readonly property int numConnectedGamepads: gamepad ? gamepad.numConnectedGamepads : 0

    /** Selects the specified gamepad as input source */
    function selectGamepad(gamePadIdx, useAnalogAxis) {
        if (!gamepad) return;
        if (gamepad.selectGamepad(gamePadIdx, useAnalogAxis)) {
            keybGamepad.enabled = false;
            vgamepad.enabled = false;
            buttonAPressed = Qt.binding(function() {return gamepad.buttonX;});
            buttonBPressed = Qt.binding(function() {return gamepad.buttonA;});
            if (useAnalogAxis) {
                axisX = Qt.binding(function() {return Math.abs(gamepad.axisLeftX) > .2 ? gamepad.axisLeftX : 0;});
                axisY = Qt.binding(function() {return Math.abs(gamepad.axisLeftY) > .2 ? -gamepad.axisLeftY : 0;});
            }
            else {
                axisX = Qt.binding(function() {return gamepad.buttonLeft ? -1 : gamepad.buttonRight ? 1 : 0;});
                axisY = Qt.binding(function() {return gamepad.buttonUp ? 1 : gamepad.buttonDown ? -1 : 0;});
            }
        }
        else console.error("Invalid game pad index: " + gamePadIdx +
                           " nr of connected gamepads: " + GamepadManager.connectedGamepads.length)

    }

    /** Selects the keyboard as input */
    function selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey) {
        if (gamepad) gamepad.deviceId = -1;
        keybGamepad.enabled = true;
        vgamepad.enabled = false;
        keybGamepad.configure(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey);
    }

    /** Selects the touchscreen gamepad */
    function selectTouchscreenGamepad()
    {
        if (gamepad) gamepad.deviceId = -1;
        keybGamepad.enabled = false;
        vgamepad.enabled = true;
        vgamepad.configure();
    }

    GameControllerDV {
        id: theDebugVisu
        visible: false
        observed: theController
    }

    // TODO There is not yet a Qt6.x version available that supports
    // Gamepad again - either wait for a version or use an alternative
//    Loader {
//        id: gamepadLoader
//        source: Qt.platform.os !== "ios" ?  "GamepadWrapper.qml" : null
//    }

    Keys.forwardTo: keybGamepad
    KeyboardGamepad { id: keybGamepad; gameController: theController; }
    TouchscreenGamepad { id: vgamepad; gameController: theController; }
}
