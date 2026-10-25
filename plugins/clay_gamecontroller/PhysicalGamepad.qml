// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype PhysicalGamepad
    \inqmlmodule Clayground.GameController
    \brief Internal component that maps a physical gamepad to GameController.

    PhysicalGamepad writes the buttons and axes of one connected pad into its
    GameController, in the terms of the controller's layout. It is used
    internally by GameController when selectGamepad() picks a pad.

    The pad is read positionally, the way SDL and the browser describe a
    standard pad: buttonA is the bottom face button, buttonB the right one,
    buttonX the left one and buttonY the top one, whatever they are labelled
    on the pad. axisX and axisY follow the left stick and the d-pad - the
    d-pad wins while it is pressed - with up positive; axisRightX and
    axisRightY follow the right stick. L1/R1 are the shoulder buttons,
    triggerL2/R2 the analog triggers, start and select the start and back
    buttons. The guide button, the stick clicks, paddles and other extra
    buttons have no input in GameController's layouts and are not written.

    \qmlproperty GameController PhysicalGamepad::gameController
    \brief Reference to the parent GameController.

    \qmlproperty int PhysicalGamepad::deviceId
    \readonly
    \brief The deviceId of the selected pad, -1 when none is selected.

    \qmlproperty var PhysicalGamepad::pad
    \readonly
    \brief The selected pad as GameController.gamepads lists it, or null.

    \qmlproperty bool PhysicalGamepad::useStick
    \brief Whether the left stick drives axisX/axisY; the d-pad always does.

    \qmlproperty real PhysicalGamepad::deadzone
    \brief How far a stick moves from the centre before it counts, 0.2 of
    its range; beyond it the stick reads from 0 to 1 again.

    \qmlmethod bool PhysicalGamepad::select(int index, bool useStick)
    \brief Selects the pad at \a index of GameController.gamepads; returns
    false if there is none.

    \qmlmethod void PhysicalGamepad::deselect()
    \brief Lets go of the pad and writes every input of the layout neutral.

    When the selected pad is unplugged, the gamepad deselects itself: the
    inputs go neutral and GameController.gamepadSelected becomes false.
*/
import QtQuick

Item {
    id: thePad

    property var gameController: null
    property int deviceId: -1
    readonly property var pad: _find(deviceId, GamepadHub.gamepads)
    property bool useStick: true
    property real deadzone: .2

    // Input name -> the value last written. A pad reports raw changes all the
    // time - a resting stick drifts inside its dead zone - and rewriting every
    // input on each of them erased what the Dojo's agent input had set.
    property var _written: ({})

    function select(index, useStick) {
        const pads = GamepadHub.gamepads;
        if (index < 0 || index >= pads.length) return false;
        thePad.useStick = useStick !== false;
        deviceId = pads[index].deviceId;
        return true;
    }

    function deselect() {
        if (deviceId === -1) return;
        deviceId = -1;
        _written = {};
        _writeNeutral();
    }

    function _find(id, pads) {
        if (id === -1) return null;
        for (const p of pads) if (p.deviceId === id) return p;
        return null;
    }

    function _writeNeutral() {
        if (!gameController) return;
        for (const name of gameController._layoutInputs())
            gameController._write(name, gameController._neutral(name));
    }

    // A stick with a radial dead zone, rescaled so it starts at 0 at its edge
    function _stick(x, y) {
        const len = Math.hypot(x, y);
        if (len <= deadzone) return [0, 0];
        const scale = (Math.min(len, 1) - deadzone) / (1 - deadzone) / len;
        return [x * scale, y * scale];
    }

    function _apply() {
        if (!pad || !gameController) return;
        const v = pad.values;
        const on = (b) => v[b] === true;
        const num = (a) => v[a] !== undefined ? v[a] : 0;

        // Pads report y down, GameController has it up
        const left = useStick ? _stick(num("leftX"), -num("leftY")) : [0, 0];
        const dx = on("dpadRight") - on("dpadLeft");
        const dy = on("dpadUp") - on("dpadDown");
        const right = _stick(num("rightX"), -num("rightY"));
        // Only what the pad changed, so other sources' writes stand
        const w = (name, value) => {
            if (_written[name] === value) return;
            _written[name] = value;
            gameController._write(name, value);
        };
        w("axisX", dx !== 0 ? dx : left[0]);
        w("axisY", dy !== 0 ? dy : left[1]);
        w("axisRightX", right[0]);
        w("axisRightY", right[1]);
        w("buttonA", on("south"));
        w("buttonB", on("east"));
        w("buttonX", on("west"));
        w("buttonY", on("north"));
        w("buttonL1", on("leftShoulder"));
        w("buttonR1", on("rightShoulder"));
        w("triggerL2", num("leftTrigger"));
        w("triggerR2", num("rightTrigger"));
        w("buttonStart", on("start"));
        w("buttonSelect", on("back"));
    }

    // A newly selected pad and a new layout write every input once
    function _applyAll() {
        _written = {};
        _apply();
    }

    onPadChanged: _applyAll()
    onUseStickChanged: _apply()

    // Not from onPadChanged: changing deviceId there re-enters pad's binding
    Connections {
        target: GamepadHub
        function onGamepadRemoved(id) { if (id === thePad.deviceId) thePad.deselect(); }
    }

    Connections {
        target: thePad.pad
        function onValuesChanged() { thePad._apply(); }
    }

    Connections {
        target: thePad.gameController
        function onLayoutChanged() { thePad._applyAll(); }
    }
}
