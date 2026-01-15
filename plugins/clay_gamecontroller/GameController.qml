// (c) Clayground Contributors - MIT License, see "LICENSE" file

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
