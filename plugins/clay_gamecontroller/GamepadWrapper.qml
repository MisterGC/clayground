// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtGamepad

/** Represents a very simple GameController which is inspired by input possibilities of NES controller. */

Gamepad {
    property int numConnectedGamepads: GamepadManager.connectedGamepads.length
    function selectGamepad(gamePadIdx, useAnalogAxis) {
        if (gamePadIdx >= 0 && gamePadIdx < numConnectedGamepads)
        {
            deviceId = GamepadManager.connectedGamepads[gamePadIdx];
            return true;
        }
        return false;
    }
}
