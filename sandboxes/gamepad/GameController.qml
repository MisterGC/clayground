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

    // Visualizes the state of the GameController
    property alias showDebugOverlay: theDebugVisu.visible

    readonly property bool gamepadSelected: gamepad.deviceId !== -1
    readonly property bool vGamepadSelected: vgamepad.enabled
    readonly property bool keyboardSelected: keybGamepad.enabled

    /** Selects the specified gamepad as input source */
    function selectGamepad(gamePadIdx) {
        if (gamePadIdx >= 0 &&
            gamePadIdx < GamepadManager.connectedGamepads.length)
        {
            keybGamepad.enabled = false;
            gamepad.deviceId = GamepadManager.connectedGamepads[gamePadIdx];
            buttonAPressed = Qt.binding(function() {return gamepad.buttonB;});
            buttonBPressed = Qt.binding(function() {return gamepad.buttonA;});
            axisX = Qt.binding(function() {return gamepad.buttonLeft ? -1 : gamepad.buttonRight ? 1 : 0;});
            axisY = Qt.binding(function() {return gamepad.buttonUp ? 1 : gamepad.buttonDown ? -1 : 0;});
        }
        else console.error("Invalid game pad index: " + gamePadIdx +
                           " nr of connected gamepads: " + GamepadManager.connectedGamepads.length)
    }

    /** Selects the keyboard as input */
    function selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey) {
        gamepad.deviceId = -1;
        keybGamepad.enabled = true;
        keybGamepad.configure(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey);
    }

    Keys.forwardTo: keybGamepad
    Gamepad { id: gamepad }
    KeyboardGamepad { id: keybGamepad; gameController: theController; }
    TouchscreenGamepad { id: vgamepad }

    GameControllerDV {
        id: theDebugVisu
        observed: theController
    }

}
