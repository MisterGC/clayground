// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

Item {
    id: theController

    // Which inputs the controller has: "nes" is a stick and A/B, "full" adds
    // a second stick, X/Y, shoulders, triggers and start/select. Sources set
    // only the inputs of the layout; the others stay neutral.
    property string layout: "nes"
    readonly property var inputs: _layoutInputs()

    // State of "directional" control axis in [-1;1] - the left stick in full
    property real axisX: 0
    property real axisY: 0

    property bool buttonAPressed: false
    property bool buttonBPressed: false

    // Inputs of the full layout only
    property real axisRightX: 0
    property real axisRightY: 0
    property bool buttonXPressed: false
    property bool buttonYPressed: false
    property bool buttonL1Pressed: false
    property bool buttonR1Pressed: false
    property real triggerL2: 0
    property real triggerR2: 0
    property bool buttonStartPressed: false
    property bool buttonSelectPressed: false

    readonly property var _nesInputs: ["axisX", "axisY", "buttonA", "buttonB"]
    // Same names and order as ClayInputControl::inputNames() in the loader
    readonly property var _fullInputs: [
        "axisX", "axisY", "axisRightX", "axisRightY",
        "buttonA", "buttonB", "buttonX", "buttonY",
        "buttonL1", "buttonR1", "triggerL2", "triggerR2",
        "buttonStart", "buttonSelect"]

    /** The current value of the input called name, as inputs names it */
    function inputValue(name) { return theController[_property(name)]; }

    function _property(name) {
        return name.startsWith("button") ? name + "Pressed" : name;
    }

    function _neutral(name) { return name.startsWith("button") ? false : 0; }

    // Read from layout rather than inputs: inside onLayoutChanged the binding
    // of inputs may not have caught up yet.
    function _layoutInputs() { return layout === "full" ? _fullInputs : _nesInputs; }

    // Sources write through here, so an input the layout lacks is never set.
    function _write(name, value) {
        if (_layoutInputs().indexOf(name) !== -1)
            theController[_property(name)] = value;
    }

    onLayoutChanged: {
        if (layout !== "nes" && layout !== "full")
            console.warn("GameController: unknown layout '" + layout +
                         "', using nes");
        // The sources write the inputs the layout has, on the same signal.
        const has = _layoutInputs();
        for (const name of _fullInputs)
            if (has.indexOf(name) === -1)
                theController[_property(name)] = _neutral(name);
    }

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

    /** Selects the keyboard as input: six keys for the stick and two
        buttons, or one map from input name to key - an axis takes
        [negative key, positive key] */
    function selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey) {
        if (gamepad) gamepad.deviceId = -1;
        keybGamepad.enabled = true;
        vgamepad.enabled = false;
        if (typeof upKey === "object" && upKey !== null)
            keybGamepad.configureKeys(upKey);
        else
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

    // Agent-synthesized input (Dojo inspector); inert outside the sandbox.
    // It writes imperatively like KeyboardGamepad, so it composes with the
    // humanly selected source instead of replacing it.
    readonly property bool syntheticActive: synthGamepad.active

    Keys.forwardTo: keybGamepad
    KeyboardGamepad { id: keybGamepad; gameController: theController; }
    TouchscreenGamepad { id: vgamepad; gameController: theController; }
    SyntheticGamepad { id: synthGamepad; gameController: theController; }
}
