/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
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

    property int gamepadId: gamepad.deviceId
    readonly property bool gamepadSelected: gamepad.deviceId !== -1
    readonly property bool vGamepadSelected: vgamepad.enabled
    readonly property bool keyboardSelected: keybGamepad.enabled

    /** Selects the specified gamepad as input source */
    function selectGamepad(gamePadIdx, useAnalogAxis) {
        if (gamePadIdx >= 0 &&
            gamePadIdx < GamepadManager.connectedGamepads.length)
        {
            gamepad.deviceId = GamepadManager.connectedGamepads[gamePadIdx];
            keybGamepad.enabled = false;
            vgamepad.enabled = false;
            buttonAPressed = Qt.binding(function() {return gamepad.buttonB;});
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
        gamepad.deviceId = -1;
        keybGamepad.enabled = true;
        vgamepad.enabled = false;
        keybGamepad.configure(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey);
    }

    /** Selects the touchscreen gamepad */
    function selectTouchscreenGamepad()
    {
        gamepad.deviceId = -1;
        keybGamepad.enabled = false;
        vgamepad.enabled = true;
        vgamepad.configure();
    }

    GameControllerDV {
        id: theDebugVisu
        visible: false
        observed: theController
    }

    Keys.forwardTo: keybGamepad
    Gamepad { id: gamepad }
    KeyboardGamepad { id: keybGamepad; gameController: theController; }
    TouchscreenGamepad { id: vgamepad; gameController: theController; }
}
