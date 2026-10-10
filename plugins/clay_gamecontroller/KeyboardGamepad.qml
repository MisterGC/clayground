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

    \qmlmethod void KeyboardGamepad::releaseAll()
    \brief Forgets every held key and writes neutral axes and released buttons.

    The gamepad keeps the set of held keys and computes each axis from it:
    opposite keys cancel, and releasing one leaves the other in effect. A key
    released while the keys go elsewhere never reports its release, so the
    set is cleared whenever the window's active focus item changes or the
    window becomes inactive.
*/
import QtQuick

Item
{
    id: theKeyboard

    enabled: false
    property var upKey: null
    property var downKey: null
    property var leftKey: null
    property var rightKey: null
    property var buttonAKey: null
    property var buttonBKey: null
    property var gameController: null

    // Held keys as key code -> true. Axes are derived from it rather than set
    // per event: setting on press and clearing on release lost the opposite
    // key still held (hold A, tap D, release D -> axisX 0).
    property var _held: ({})

    function configure(uk, dk, lk, rk, bA, bB) {
        upKey = uk;
        downKey = dk;
        leftKey = lk;
        rightKey = rk;
        buttonAKey = bA;
        buttonBKey = bB;
        releaseAll();
    }

    function releaseAll() {
        _held = {};
        _apply();
    }

    // Writes only when something was held, so a focus change does not
    // overwrite touch or agent input with neutral values.
    function _releaseHeld() {
        if (Object.keys(_held).length > 0) releaseAll();
    }

    function _isMapped(key) {
        return key === upKey || key === downKey || key === leftKey ||
               key === rightKey || key === buttonAKey || key === buttonBKey;
    }

    function _apply() {
        if (!enabled || !gameController) return;
        const h = _held;
        gameController.axisX = (h[rightKey] ? 1 : 0) - (h[leftKey] ? 1 : 0);
        gameController.axisY = (h[upKey] ? 1 : 0) - (h[downKey] ? 1 : 0);
        gameController.buttonBPressed = !!h[buttonAKey];
        gameController.buttonAPressed = !!h[buttonBKey];
    }

    onEnabledChanged: _held = {}

    // A release that goes to another item (an overlay took focus, another
    // window is in front) never arrives here, so a key would stay held once
    // focus returns. The controller rarely has focus itself - games forward
    // keys to it from a parent - so any change of the focus item counts.
    Connections {
        target: theKeyboard.Window.window
        function onActiveFocusItemChanged() { theKeyboard._releaseHeld(); }
        function onActiveChanged() {
            if (!theKeyboard.Window.window.active) theKeyboard._releaseHeld();
        }
    }

    Keys.onPressed: (event)=> {
        if (!enabled || event.isAutoRepeat || !_isMapped(event.key)) return;
        _held[event.key] = true;
        _apply();
    }

    Keys.onReleased: (event)=> {
        if (!enabled || event.isAutoRepeat || !_isMapped(event.key)) return;
        delete _held[event.key];
        _apply();
    }
}
