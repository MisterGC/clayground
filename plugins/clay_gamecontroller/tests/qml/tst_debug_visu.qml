// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// GameControllerDV shows every input of the layout, live (#463).
Item {
    id: root
    width: 800; height: 400

    GameController { id: ctrl; anchors.fill: parent; showDebugOverlay: true }

    TestCase {
        name: "GameControllerDV"
        when: windowShown

        function indicator(input) {
            const found = [];
            (function walk(item) {
                for (const c of item.children) {
                    if (c.objectName === "dv_" + input) found.push(c);
                    walk(c);
                }
            })(ctrl);
            return found.find(i => i.visible) || null;
        }

        function exercise() {
            for (const name of ctrl.inputs) {
                const ind = indicator(name);
                verify(ind !== null, name);
                compare(ind.level, 0, name);
                const button = name.startsWith("button");
                const prop = button ? name + "Pressed" : name;
                ctrl[prop] = button ? true : (name.startsWith("trigger") ? .6 : -.6);
                compare(ind.level, button ? 1 : (name.startsWith("trigger") ? .6 : -.6),
                        name);
                ctrl[prop] = button ? false : 0;
                compare(ind.level, 0, name);
            }
        }

        function test_nes_shows_stick_and_ab_only() {
            ctrl.layout = "nes";
            exercise();
            for (const name of ["axisRightX", "buttonX", "buttonL1", "triggerR2",
                                "buttonStart"])
                compare(indicator(name), null, name);
        }

        function test_full_shows_every_input() {
            ctrl.layout = "full";
            exercise();
        }
    }
}
