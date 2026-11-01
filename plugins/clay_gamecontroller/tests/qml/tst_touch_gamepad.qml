// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// The touchscreen gamepad has a stick and a pad for every input of the
// layout, each on its own touch point (#463).
Item {
    id: root
    width: 800; height: 400

    GameController { id: ctrl; anchors.fill: parent }

    TestCase {
        id: test
        name: "TouchscreenGamepad"
        when: windowShown

        readonly property var pads: ["buttonA", "buttonB", "buttonX",
            "buttonY", "buttonL1", "buttonR1", "triggerL2", "triggerR2",
            "buttonStart", "buttonSelect"]

        function init() { useLayout("nes"); }

        function useLayout(layout) {
            ctrl.layout = layout;
            ctrl.selectTouchscreenGamepad();
        }

        // Qt Quick compresses touch moves and delivers them with the next
        // frame, so a value is waited for rather than read after commit().
        function expect(name, value) {
            tryVerify(() => Math.abs(ctrl.inputValue(name) - value) < 1e-6, 1000,
                      name + " = " + ctrl.inputValue(name) + ", expected " + value);
        }

        function pad(name) {
            // A nes and a full pad share the name; take the visible one.
            const found = [];
            (function walk(item) {
                for (const c of item.children) {
                    if (c.objectName === "touch_" + name) found.push(c);
                    walk(c);
                }
            })(ctrl);
            return found.find(p => p.visible) || null;
        }

        function centre(item) {
            return item.mapToItem(root, item.width / 2, item.height / 2);
        }

        function touchPad(name) {
            const p = pad(name);
            verify(p !== null, name);
            const c = centre(p);
            const t = touchEvent(root);
            t.press(0, root, c.x, c.y).commit();
            const pressed = name.startsWith("button") ? true : 1;
            tryVerify(() => ctrl.inputValue(name) === pressed, 1000, name);
            const held = ctrl.inputValue(name);
            t.release(0, root, c.x, c.y).commit();
            tryVerify(() => ctrl.inputValue(name) !== pressed, 1000, name);
            return held;
        }

        function test_full_has_a_pad_for_every_button_and_trigger() {
            useLayout("full");
            for (const name of pads) {
                const held = touchPad(name);
                compare(held, name.startsWith("button") ? true : 1, name);
                compare(ctrl.inputValue(name), name.startsWith("button") ? false : 0,
                        name);
            }
        }

        function test_nes_shows_only_b_and_a() {
            for (const name of pads)
                compare(pad(name) !== null, name === "buttonA" || name === "buttonB",
                        name);
            compare(touchPad("buttonA"), true);
            compare(touchPad("buttonB"), true);
        }

        function test_left_stick_reads_offset_over_radius() {
            const r = .05 * root.height;
            const t = touchEvent(root);
            t.press(0, root, 200, 200).commit();
            t.move(0, root, 200 + r / 2, 200 - r).commit();
            expect("axisX", .5);
            expect("axisY", 1);
            t.move(0, root, 200 - 3 * r, 200).commit();
            expect("axisX", -1);
            expect("axisY", 0);
            t.release(0, root, 200 - 3 * r, 200).commit();
            expect("axisX", 0);
        }

        function test_full_drives_both_sticks_and_a_pad_at_once() {
            useLayout("full");
            const r = .05 * root.height;
            const a = centre(pad("buttonA"));
            const t = touchEvent(root);
            t.press(0, root, 200, 200).press(1, root, 600, 150).commit();
            t.move(0, root, 200 + r, 200).move(1, root, 600, 150 + r).commit();
            expect("axisX", 1);
            expect("axisRightY", -1);
            t.press(2, root, a.x, a.y).commit();
            expect("buttonA", 1);
            expect("axisX", 1);
            expect("axisY", 0);
            expect("axisRightX", 0);
            expect("axisRightY", -1);
            t.release(0, root, 200 + r, 200).release(1, root, 600, 150 + r)
             .release(2, root, a.x, a.y).commit();
            expect("axisX", 0);
            expect("axisRightY", 0);
            expect("buttonA", 0);
        }

        function test_nes_stick_covers_the_whole_area() {
            const r = .05 * root.height;
            const t = touchEvent(root);
            t.press(0, root, 600, 150).commit();
            t.move(0, root, 600 + r, 150).commit();
            expect("axisX", 1);
            expect("axisRightX", 0);
            t.release(0, root, 600 + r, 150).commit();
        }
    }
}
