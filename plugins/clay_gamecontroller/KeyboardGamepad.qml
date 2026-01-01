// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype KeyboardGamepad
    \inqmlmodule Clayground.GameController
    \brief Internal component that maps keyboard input to GameController.

    KeyboardGamepad translates keyboard key presses into GameController axis
    and button states. It is used internally by GameController when keyboard
    input is selected.

    \qmlproperty bool KeyboardGamepad::enabled
    \brief Whether keyboard input handling is active.

    \qmlproperty var KeyboardGamepad::upKey
    \brief Qt.Key value for up direction.

    \qmlproperty var KeyboardGamepad::downKey
    \brief Qt.Key value for down direction.

    \qmlproperty var KeyboardGamepad::leftKey
    \brief Qt.Key value for left direction.

    \qmlproperty var KeyboardGamepad::rightKey
    \brief Qt.Key value for right direction.

    \qmlproperty var KeyboardGamepad::buttonAKey
    \brief Qt.Key value for button A.

    \qmlproperty var KeyboardGamepad::buttonBKey
    \brief Qt.Key value for button B.

    \qmlproperty GameController KeyboardGamepad::gameController
    \brief Reference to the parent GameController.

    \qmlmethod void KeyboardGamepad::configure(var uk, var dk, var lk, var rk, var bA, var bB)
    \brief Configures all key mappings at once.
*/
import QtQuick

Item
{
    enabled: false
    property var upKey: null
    property var downKey: null
    property var leftKey: null
    property var rightKey: null
    property var buttonAKey: null
    property var buttonBKey: null
    property var gameController: null

    function configure(uk, dk, lk, rk, bA, bB) {
        upKey = uk;
        downKey = dk;
        leftKey = lk;
        rightKey = rk;
        buttonAKey = bA;
        buttonBKey = bB;
    }

    Keys.onPressed: (event)=> {
        if (!enabled || event.isAutoRepeat) return;
        switch (event.key)
        {
            case upKey: gameController.axisY = 1; break;
            case downKey: gameController.axisY = -1; break;
            case leftKey: gameController.axisX = -1; break;
            case rightKey: gameController.axisX = 1; break;
            case buttonAKey: gameController.buttonBPressed = true; break;
            case buttonBKey: gameController.buttonAPressed = true; break;
        }
    }

    Keys.onReleased: (event)=> {
        if (!enabled || event.isAutoRepeat) return;
        switch (event.key)
        {
            case upKey: if (gameController.axisY > 0) gameController.axisY = 0; break;
            case downKey: if (gameController.axisY < 0) gameController.axisY = 0; break;
            case leftKey: if (gameController.axisX < 0) gameController.axisX = 0; break;
            case rightKey: if (gameController.axisX > 0) gameController.axisX = 0; break;
            case buttonAKey: gameController.buttonBPressed = false; break;
            case buttonBKey: gameController.buttonAPressed = false; break;
        }
    }
}
