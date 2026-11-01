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

    \qmlproperty var KeyboardGamepad::keys
    \brief Map from input name (as GameController.inputs names it) to the
    Qt.Key that sets it.

    A button or a trigger takes one key; an axis takes
    [negative key, positive key], so \c {axisY: [Qt.Key_S, Qt.Key_W]} is down
    and up. Inputs the controller's layout lacks are ignored.

    \qmlproperty GameController KeyboardGamepad::gameController
    \brief Reference to the parent GameController.

    \qmlmethod void KeyboardGamepad::configure(var uk, var dk, var lk, var rk, var bA, var bB)
    \brief Maps the stick and two buttons, as GameController.selectKeyboard()
    always has: the key \a bA presses B, the key \a bB presses A.

    \qmlmethod void KeyboardGamepad::configureKeys(var keys)
    \brief Sets \l keys and releases every key.

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
    property var keys: ({})
    property var gameController: null

    // Held keys as key code -> true. Axes are derived from it rather than set
    // per event: setting on press and clearing on release lost the opposite
    // key still held (hold A, tap D, release D -> axisX 0).
    property var _held: ({})
    // Key code -> true for every key in keys
    property var _mapped: ({})

    // The fifth key has always pressed B and the sixth A; games rely on it.
    function configure(uk, dk, lk, rk, bA, bB) {
        configureKeys({axisX: [lk, rk], axisY: [dk, uk],
                       buttonA: bB, buttonB: bA});
    }

    function configureKeys(k) {
        const mapped = {};
        for (const name in k) {
            const key = k[name];
            if (Array.isArray(key)) {
                if (name.startsWith("button"))
                    console.warn("KeyboardGamepad: " + name + " takes one key");
                for (const one of key) mapped[one] = true;
            }
            else mapped[key] = true;
        }
        keys = k;
        _mapped = mapped;
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

    function _isMapped(key) { return !!_mapped[key]; }

    function _apply() {
        if (!enabled || !gameController) return;
        const h = _held;
        for (const name in keys) {
            const key = keys[name];
            let value;
            if (Array.isArray(key))
                value = (h[key[1]] ? 1 : 0) - (h[key[0]] ? 1 : 0);
            else if (name.startsWith("button"))
                value = !!h[key];
            else
                value = h[key] ? 1 : 0;
            gameController._write(name, value);
        }
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

    // Keys held while the layout changes set the inputs it now has.
    Connections {
        target: theKeyboard.gameController
        function onLayoutChanged() { theKeyboard._apply(); }
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
