// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import QtGamepad 1.0

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
