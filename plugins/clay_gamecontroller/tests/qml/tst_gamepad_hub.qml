// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// The hub reads physical pads through SDL; a virtual SDL pad stands in for
// one plugged into the machine (#82).
Item {
    id: root

    TestCase {
        name: "GamepadHub"

        property var attached: []

        function init() {
            if (GamepadHub.backend !== "sdl")
                skip("this build reads no physical pads (" + GamepadHub.backend + ")");
        }

        function cleanup() {
            for (const id of attached) GamepadHub.detachVirtualGamepad(id);
            attached = [];
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

        function test_plug_in_and_out() {
            const before = GamepadHub.count;
            const first = attach("Clay Test Pad 1");
            compare(GamepadHub.count, before + 1);
            const second = attach("Clay Test Pad 2");
            compare(GamepadHub.count, before + 2);

            const pad = GamepadHub.gamepad(second);
            verify(pad !== null);
            compare(pad.name, "Clay Test Pad 2");
            verify(GamepadHub.gamepads.indexOf(pad) !== -1);

            detach(first);
            compare(GamepadHub.count, before + 1);
            compare(GamepadHub.gamepad(first), null);
            detach(second);
            compare(GamepadHub.count, before);
        }

        function test_reports_every_button_and_axis() {
            const pad = GamepadHub.gamepad(attach("Clay Test Pad"));
            compare(pad.buttons.length, 26);
            compare(pad.axes, ["leftX", "leftY", "rightX", "rightY",
                               "leftTrigger", "rightTrigger"]);
            for (const b of pad.buttons) compare(pad.value(b), false, b);
            for (const a of pad.axes) compare(pad.value(a), 0, a);
        }

        function test_values_follow_the_pad() {
            const id = attach("Clay Test Pad");
            const pad = GamepadHub.gamepad(id);
            const spy = valueSpy.createObject(root, {target: pad});

            for (const b of pad.buttons) {
                verify(GamepadHub.setVirtualGamepadInput(id, b, 1));
                compare(pad.values[b], true, b);
                verify(GamepadHub.setVirtualGamepadInput(id, b, 0));
                compare(pad.values[b], false, b);
            }
            verify(spy.count >= 2 * pad.buttons.length);

            for (const a of ["leftX", "leftY", "rightX", "rightY"]) {
                GamepadHub.setVirtualGamepadInput(id, a, 1);
                fuzzyCompare(pad.value(a), 1, 1e-4, a);
                GamepadHub.setVirtualGamepadInput(id, a, -1);
                fuzzyCompare(pad.value(a), -1, 1e-4, a);
                GamepadHub.setVirtualGamepadInput(id, a, 0);
                fuzzyCompare(pad.value(a), 0, 1e-4, a);
            }
            for (const t of ["leftTrigger", "rightTrigger"]) {
                GamepadHub.setVirtualGamepadInput(id, t, 1);
                fuzzyCompare(pad.value(t), 1, 1e-3, t);
                GamepadHub.setVirtualGamepadInput(id, t, .5);
                fuzzyCompare(pad.value(t), .5, 1e-3, t);
                GamepadHub.setVirtualGamepadInput(id, t, 0);
                fuzzyCompare(pad.value(t), 0, 1e-3, t);
            }
            spy.destroy();
        }

        function test_unknown_input_is_refused() {
            const id = attach("Clay Test Pad");
            verify(!GamepadHub.setVirtualGamepadInput(id, "buttonA", 1));
            verify(!GamepadHub.setVirtualGamepadInput(id + 1000, "south", 1));
        }
    }

    Component {
        id: valueSpy
        SignalSpy { signalName: "valuesChanged" }
    }
}
