// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype GamepadWrapper
    \inqmlmodule Clayground.GameController
    \inherits QtGamepad::Gamepad
    \brief Wrapper for Qt's Gamepad API providing physical gamepad access.

    GamepadWrapper extends Qt's Gamepad type to provide gamepad selection
    and connection management. Currently disabled in Qt6 due to API changes.

    \qmlproperty int GamepadWrapper::numConnectedGamepads
    \readonly
    \brief Number of currently connected physical gamepads.

    \qmlmethod bool GamepadWrapper::selectGamepad(int gamePadIdx, bool useAnalogAxis)
    \brief Selects a gamepad by index. Returns true on success.
*/
import QtQuick
import QtGamepad

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
