// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// A physical pad selected with selectGamepad() drives every input of the
// layout (#82). A virtual SDL pad stands in for one plugged in.
Item {
    id: root

    GameController { id: ctrl }

    // Pad input -> the GameController input it drives and the value it reads
    readonly property var padToInput: [
        ["south", "buttonA", true], ["east", "buttonB", true],
        ["west", "buttonX", true], ["north", "buttonY", true],
        ["leftShoulder", "buttonL1", true], ["rightShoulder", "buttonR1", true],
        ["start", "buttonStart", true], ["back", "buttonSelect", true],
        ["leftTrigger", "triggerL2", 1], ["rightTrigger", "triggerR2", 1],
        ["leftX", "axisX", 1], ["rightX", "axisRightX", 1],
        // Pads have y down, GameController has it up
        ["leftY", "axisY", -1], ["rightY", "axisRightY", -1]]

    function neutral(name) { return name.startsWith("button") ? false : 0; }

    TestCase {
        name: "PhysicalGamepad"

        property var attached: []

        function init() {
            if (GamepadHub.backend !== "sdl")
                skip("this build reads no physical pads (" + GamepadHub.backend + ")");
            ctrl.layout = "full";
        }

        function cleanup() {
            for (const id of attached) GamepadHub.detachVirtualGamepad(id);
            attached = [];
            ctrl.selectKeyboard({});
        }

        function attach(name) {
            const id = GamepadHub.attachVirtualGamepad(name);
            verify(id > 0, "a virtual pad attaches");
            attached = attached.concat([id]);
            return id;
        }

        function detach(id) {
            verify(GamepadHub.detachVirtualGamepad(id));
            attached = attached.filter(a => a !== id);
        }

        function set(id, input, value) {
            verify(GamepadHub.setVirtualGamepadInput(id, input, value), input);
        }

        // The index of the pad in gamepads, as selectGamepad() takes it
        function indexOf(id) {
            for (let i = 0; i < ctrl.gamepads.length; ++i)
                if (ctrl.gamepads[i].deviceId === id) return i;
            return -1;
        }

        function test_numConnectedGamepads_follows_plugging() {
            const before = ctrl.numConnectedGamepads;
            const spy = countSpy.createObject(root, {target: ctrl});
            const first = attach("Clay Test Pad 1");
            compare(ctrl.numConnectedGamepads, before + 1);
            const second = attach("Clay Test Pad 2");
            compare(ctrl.numConnectedGamepads, before + 2);
            compare(ctrl.gamepads[indexOf(second)].name, "Clay Test Pad 2");
            detach(first);
            compare(ctrl.numConnectedGamepads, before + 1);
            detach(second);
            compare(ctrl.numConnectedGamepads, before);
            compare(spy.count, 4);
            spy.destroy();
        }

        function test_full_drives_every_input() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            verify(ctrl.gamepadSelected);
            verify(!ctrl.keyboardSelected);
            compare(ctrl.gamepadDeviceId, id);
            compare(ctrl.gamepad.name, "Clay Test Pad");

            const driven = [];
            for (const [padInput, input, value] of padToInput) {
                set(id, padInput, typeof value === "boolean" ? 1 : Math.abs(value));
                compare(ctrl.inputValue(input), value, padInput + " -> " + input);
                set(id, padInput, 0);
                compare(ctrl.inputValue(input), neutral(input), padInput + " released");
                driven.push(input);
            }
            compare(driven.sort(), ctrl.inputs.slice().sort(), "every input of full");
        }

        function test_nes_drives_only_stick_and_ab() {
            ctrl.layout = "nes";
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            // leftY stays: with leftX the stick would be diagonal
            for (const [padInput] of padToInput)
                if (padInput !== "leftY") set(id, padInput, 1);
            set(id, "dpadDown", 1);
            compare(ctrl.axisX, 1);
            compare(ctrl.axisY, -1);
            verify(ctrl.buttonAPressed);
            verify(ctrl.buttonBPressed);
            for (const input of ["buttonX", "buttonY", "buttonL1", "buttonR1",
                                 "triggerL2", "triggerR2", "axisRightX",
                                 "axisRightY", "buttonStart", "buttonSelect"])
                compare(ctrl.inputValue(input), neutral(input), input);

            // Switching to full picks up what the pad holds
            ctrl.layout = "full";
            verify(ctrl.buttonXPressed);
            compare(ctrl.triggerR2, 1);
        }

        function test_dpad_drives_the_stick_axes() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            set(id, "dpadLeft", 1);
            compare(ctrl.axisX, -1);
            set(id, "dpadLeft", 0);
            set(id, "dpadUp", 1);
            compare(ctrl.axisY, 1);
            // The d-pad wins over the stick while it is pressed
            set(id, "leftY", 1);
            compare(ctrl.axisY, 1);
            set(id, "dpadUp", 0);
            compare(ctrl.axisY, -1);
        }

        function test_without_analog_axis_only_the_dpad_counts() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id), false);
            set(id, "leftX", 1);
            compare(ctrl.axisX, 0);
            set(id, "dpadRight", 1);
            compare(ctrl.axisX, 1);
            // The right stick stays analog
            set(id, "rightX", 1);
            compare(ctrl.axisRightX, 1);
        }

        function test_stick_has_a_dead_zone() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            set(id, "leftX", .15);
            compare(ctrl.axisX, 0);
            set(id, "leftX", .6);
            fuzzyCompare(ctrl.axisX, .5, .01);
            set(id, "leftX", -1);
            fuzzyCompare(ctrl.axisX, -1, .01);
        }

        // Another source's write stands until the pad changes that input
        function test_pad_writes_only_the_inputs_it_changes() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            // As the Dojo's agent input writes
            ctrl._write("buttonB", true);
            ctrl._write("axisRightX", .5);
            // Drift inside the dead zone and another input moving
            set(id, "rightX", .05);
            set(id, "leftX", .1);
            set(id, "south", 1);
            verify(ctrl.buttonAPressed);
            verify(ctrl.buttonBPressed, "buttonB written by another source");
            compare(ctrl.axisRightX, .5, "axisRightX written by another source");
            // The pad takes an input over once it changes it
            set(id, "east", 1);
            set(id, "east", 0);
            verify(!ctrl.buttonBPressed);
        }

        function test_unplugging_the_selected_pad_releases_everything() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            set(id, "south", 1);
            set(id, "leftX", 1);
            verify(ctrl.buttonAPressed);
            detach(id);
            verify(!ctrl.gamepadSelected);
            compare(ctrl.gamepad, null);
            verify(!ctrl.buttonAPressed);
            compare(ctrl.axisX, 0);
        }

        function test_selecting_the_keyboard_releases_the_pad() {
            const id = attach("Clay Test Pad");
            ctrl.selectGamepad(indexOf(id));
            set(id, "east", 1);
            verify(ctrl.buttonBPressed);
            ctrl.selectKeyboard({});
            verify(!ctrl.gamepadSelected);
            verify(!ctrl.buttonBPressed);
            // The pad no longer writes
            set(id, "east", 0);
            set(id, "east", 1);
            verify(!ctrl.buttonBPressed);
        }

        function test_an_invalid_index_selects_nothing() {
            ctrl.selectKeyboard({});
            // Logs "Invalid game pad index" as console.error, which
            // ignoreWarning() cannot catch
            ctrl.selectGamepad(ctrl.numConnectedGamepads);
            verify(!ctrl.gamepadSelected);
            verify(ctrl.keyboardSelected);
        }
    }

    Component {
        id: countSpy
        SignalSpy { signalName: "numConnectedGamepadsChanged" }
    }
}
