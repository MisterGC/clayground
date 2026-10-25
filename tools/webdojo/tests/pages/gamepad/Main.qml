// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#464 - overlaid onto the starter
// bundle by wasm_smoke_test.py --gamepad steps.json. The harness stands in
// for navigator.getGamepads(); this page selects the first pad that shows up
// and prints every input of the full layout as it changes, so each step of
// steps.json can name the line it has to produce. steps-firefox.json, run
// with a Firefox user agent, plays Firefox's noise on a pad that must drive
// nothing.

import QtQuick
import Clayground.GameController

Rectangle {
    anchors.fill: parent
    color: "#101018"

    GameController {
        id: controller
        anchors.fill: parent
        layout: "full"
        showDebugOverlay: true

        property var _last: ({})

        function _text(v) { return typeof v === "boolean" ? String(v) : v.toFixed(2); }

        onNumConnectedGamepadsChanged: {
            if (numConnectedGamepads > 0) {
                selectGamepad(0);
                const p = gamepad;
                console.log("gamepad: selected " + p.name + " (" + p.type + ", " +
                            p.buttons.length + " buttons, " + p.axes.length + " axes)");
            } else {
                console.log("gamepad: none");
            }
        }
    }

    // Every input that changed since the last frame, one line each. Ready
    // only after the first frame has printed them all, so every PAD line
    // after it is a change.
    FrameAnimation {
        id: watcher
        running: true
        property bool ready: false
        onTriggered: {
            for (const name of controller.inputs) {
                const v = controller.inputValue(name);
                if (controller._last[name] === v) continue;
                controller._last[name] = v;
                console.log("PAD " + name + "=" + controller._text(v));
            }
            if (ready) return;
            ready = true;
            console.log("gamepad: ready backend=" + GamepadHub.backend +
                        " pads=" + controller.numConnectedGamepads);
        }
    }
}
