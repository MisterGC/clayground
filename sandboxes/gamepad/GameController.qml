import QtQuick 2.0
import QtGamepad 1.0

/** Represents a very simple GameController which is inspired by input possibilities of NES controller. */
Item {
    id: theController

    // State of "directional" control axis in [-1;1]
    property real axisX: 0
    property real axisY: 0

    // Currently only two buttons are supported
    property bool buttonAPressed: false
    property bool buttonBPressed: false

    property alias showDebugOverlay: theDebugVisu.visible

    readonly property bool gamepadSelected: gamepad.deviceId !== -1
    readonly property bool vGamepadSelected: vgamepad.enabled
    property bool keyboardSelected: false


    /** Selects the specified gamepad as input source */
    function selectGamepad(gamePadIdx) {
        if (gamePadIdx >= 0 &&
            gamePadIdx < GamepadManager.connectedGamepads.length)
        {
            gamepad.deviceId = GamepadManager.connectedGamepads[gamePadIdx];
            buttonAPressed = Qt.binding(function() {return gamepad.buttonB;});
            buttonBPressed = Qt.binding(function() {return gamepad.buttonA;});
            axisX = Qt.binding(function() {return gamepad.buttonLeft ? -1 : gamepad.buttonRight ? 1 : 0;});
            axisY = Qt.binding(function() {return gamepad.buttonUp ? 1 : gamepad.buttonDown ? -1 : 0;});
            keyboardSelected = false;
        }
        else console.error("Invalid game pad index: " + gamePadIdx +
                           " nr of connected gamepads: " + GamepadManager.connectedGamepads.length)
    }

    /** Selects the keyboard as input */
    function selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey) {
        keyboardSelected = true;
        _upKey = upKey;
        _downKey = downKey;
        _leftKey = leftKey;
        _rightKey = rightKey;
        _buttonAKey = buttonAKey;
        _buttonBKey = buttonBKey;
    }

    property var _upKey: null
    property var _downKey: null
    property var _leftKey: null
    property var _rightKey: null
    property var _buttonAKey: null
    property var _buttonBKey: null

    Keys.onPressed: {
        if (!keyboardSelected) return;
        switch (event.key)
        {
            case _upKey: axisY = 1; break;
            case _downKey: axisY = -1; break;
            case _leftKey: axisX = -1; break;
            case _rightKey: axisX = 1; break;
            case _buttonAKey: buttonBPressed = true; break;
            case _buttonBKey: buttonAPressed = true; break;
        }
    }

    Keys.onReleased: {
        if (!keyboardSelected) return;
        switch (event.key)
        {
            case _upKey: axisY = 0; break;
            case _downKey: axisY = 0; break;
            case _leftKey: axisX = 0; break;
            case _rightKey: axisX = 0; break;
            case _buttonAKey: buttonBPressed = false; break;
            case _buttonBKey: buttonAPressed = false; break;
        }
    }

    Gamepad { id: gamepad }
    TouchscreenGamepad { id: vgamepad }

    GameControllerDV {
        id: theDebugVisu
        observed: theController
    }

}
