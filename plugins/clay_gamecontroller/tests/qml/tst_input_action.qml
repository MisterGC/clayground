// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Box2D
import Clayground.GameController

// InputAction reads tap, hold and buffered press on the physics clock (#416).
// The World is stepped by hand (running: false + step()), which is what the
// dojo's pause and single step do to a ClayWorld2d: wall time passing without
// a step must not move any reading. Every timing test runs twice, once with
// the action bound to a key and once fed by a MouseArea, and expects the same.
Item {
    id: root
    width: 200; height: 200

    World {
        id: physicsWorld
        gravity: Qt.point(0, 0)
        timeStep: 1/60
        running: false
    }

    component CountingAction: InputAction {
        property int taps: 0
        property int holds: 0
        property var releases: []
        world: physicsWorld
        holdThresholdMs: 200
        bufferMs: 150
        onTapped: taps += 1
        onHoldStarted: holds += 1
        onReleased: (heldMs) => releases.push(heldMs)
    }

    // Keys reach the action the way games route them: a focused item
    // forwards them, the action before the controller.
    Item {
        id: player
        anchors.fill: parent
        focus: true
        Keys.forwardTo: [keyAction, bothAction, ctrl]
        GameController { id: ctrl }
        CountingAction { id: keyAction; key: Qt.Key_J }
        CountingAction { id: mouseAction; mouseButton: Qt.LeftButton }
        CountingAction { id: bothAction; key: Qt.Key_K; mouseButton: Qt.LeftButton }
        CountingAction { id: wallAction; world: null }
    }

    // The game's own MouseArea feeds the mouse-bound actions.
    MouseArea {
        id: area
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property var target: mouseAction
        onPressed: (mouse) => target.press(mouse)
        onReleased: (mouse) => target.release(mouse)
        onCanceled: target.release()
    }

    // Takes the focus away, like an overlay or a menu would.
    Item { id: overlay }

    TestCase {
        name: "InputAction"
        when: windowShown

        function init() {
            physicsWorld.timeStep = 1/60;
            ctrl.selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
                                Qt.Key_Space, Qt.Key_Shift);
            area.target = mouseAction;
            player.forceActiveFocus();
            verify(player.activeFocus);
            for (const a of [keyAction, mouseAction, bothAction, wallAction]) {
                verify(!a.pressed);
                a.taps = 0;
                a.holds = 0;
                a.releases = [];
            }
        }

        function cleanup() {
            keyRelease(Qt.Key_J);
            keyRelease(Qt.Key_K);
            mouseRelease(area, 10, 10, Qt.LeftButton);
            mouseAction.release();
            bothAction.release();
            wallAction.release();
        }

        function sources() {
            return [{tag: "key", source: "key"}, {tag: "mouse", source: "mouse"}];
        }
        function action(data) {
            return data.source === "key" ? keyAction : mouseAction;
        }
        function down(data) {
            if (data.source === "key") keyPress(Qt.Key_J);
            else mousePress(area, 10, 10, Qt.LeftButton);
        }
        function up(data) {
            if (data.source === "key") keyRelease(Qt.Key_J);
            else mouseRelease(area, 10, 10, Qt.LeftButton);
        }
        function step(n) {
            for (let i = 0; i < n; ++i) physicsWorld.step();
        }
        function near(actual, expected, what) {
            verify(Math.abs(actual - expected) < 1e-2,
                   what + ": " + actual + ", expected " + expected);
        }

        function test_tap_and_hold_at_the_threshold_data() { return sources(); }
        function test_tap_and_hold_at_the_threshold(data) {
            const a = action(data);

            // 11 steps of 1/60 s are 183 ms: a tap.
            down(data);
            verify(a.pressed);
            step(11);
            compare(a.holds, 0);
            up(data);
            verify(!a.pressed);
            compare(a.taps, 1);
            compare(a.releases.length, 1);
            near(a.releases[0], 11000 / 60, "tap held");

            // The 12th step reaches 200 ms: the hold starts on that step.
            down(data);
            step(11);
            compare(a.holds, 0);
            step(1);
            compare(a.holds, 1);
            near(a.heldMs, 200, "heldMs at the threshold");
            step(5);
            compare(a.holds, 1, "a hold starts once per press");
            up(data);
            compare(a.taps, 1, "a hold is no tap");
            compare(a.releases.length, 2);
            near(a.releases[1], 17000 / 60, "hold held");
            compare(a.heldMs, 0);
        }

        function test_heldMs_stands_still_while_the_world_is_paused_data() { return sources(); }
        function test_heldMs_stands_still_while_the_world_is_paused(data) {
            const a = action(data);
            down(data);
            step(6);
            near(a.heldMs, 100, "after six steps");

            // The world is not running: wall time alone moves nothing.
            wait(250);
            near(a.heldMs, 100, "paused");
            compare(a.holds, 0, "250 ms of pause start no hold");

            // A full hit stop steps with timeStep 0.
            physicsWorld.timeStep = 0;
            step(30);
            near(a.heldMs, 100, "hit stop");

            physicsWorld.timeStep = 1/60;
            step(6);
            near(a.heldMs, 200, "running again");
            compare(a.holds, 1);
            up(data);
            near(a.releases[0], 200, "released after");
        }

        function test_a_buffered_press_is_consumed_once_data() { return sources(); }
        function test_a_buffered_press_is_consumed_once(data) {
            const a = action(data);
            verify(!a.consume(), "nothing pressed yet");

            down(data);
            up(data);
            step(6);
            near(a.pressedAgoMs, 100, "pressedAgoMs");
            verify(a.consume(), "100 ms old with bufferMs 150");
            verify(!a.consume(), "consumed once");

            down(data);
            up(data);
            step(12);
            near(a.pressedAgoMs, 200, "pressedAgoMs");
            verify(!a.consume(), "200 ms old with bufferMs 150");
        }

        function test_pressedAgoMs_and_releasedAgoMs_data() { return sources(); }
        function test_pressedAgoMs_and_releasedAgoMs(data) {
            const a = action(data);
            down(data);
            step(3);
            up(data);
            near(a.releasedAgoMs, 0, "just released");
            step(9);
            near(a.pressedAgoMs, 200, "pressedAgoMs");
            near(a.releasedAgoMs, 150, "releasedAgoMs");

            // Read on the press, releasedAgoMs still tells how long the
            // action was up before it.
            let upBefore = -1;
            const seen = function() { if (a.pressed) upBefore = a.releasedAgoMs; };
            a.pressedChanged.connect(seen);
            down(data);
            a.pressedChanged.disconnect(seen);
            near(upBefore, 150, "up before the press");
            up(data);
        }

        function test_other_mouse_buttons_do_not_count() {
            mousePress(area, 10, 10, Qt.RightButton);
            verify(!mouseAction.pressed);
            mouseRelease(area, 10, 10, Qt.RightButton);
            compare(mouseAction.releases.length, 0);
            verify(!keyAction.press({button: Qt.LeftButton}),
                   "an action with no mouse button takes no mouse event");
            verify(!keyAction.pressed);
        }

        function test_key_and_mouse_hold_one_press() {
            area.target = bothAction;
            keyPress(Qt.Key_K);
            step(3);
            mousePress(area, 10, 10, Qt.LeftButton);
            keyRelease(Qt.Key_K);
            verify(bothAction.pressed, "the mouse still holds it");
            compare(bothAction.releases.length, 0);
            step(3);
            mouseRelease(area, 10, 10, Qt.LeftButton);
            verify(!bothAction.pressed);
            compare(bothAction.releases.length, 1);
            near(bothAction.releases[0], 100, "one press from first down to last up");
            compare(bothAction.taps, 1);
        }

        function test_keys_go_on_to_the_controller() {
            keyPress(Qt.Key_J);
            keyPress(Qt.Key_A);
            verify(keyAction.pressed);
            compare(ctrl.axisX, -1, "the action leaves key events unaccepted");
            keyRelease(Qt.Key_A);
            keyRelease(Qt.Key_J);
        }

        function test_focus_loss_releases_a_key_press_without_a_tap() {
            keyPress(Qt.Key_J);
            step(3);
            overlay.forceActiveFocus();
            verify(!keyAction.pressed);
            compare(keyAction.releases.length, 1);
            compare(keyAction.taps, 0, "the player did not let go");
            keyRelease(Qt.Key_J);
            player.forceActiveFocus();
            verify(!keyAction.pressed);
        }

        function test_a_disabled_action_ignores_input() {
            keyAction.enabled = false;
            keyPress(Qt.Key_J);
            verify(!keyAction.pressed);
            keyRelease(Qt.Key_J);
            keyAction.enabled = true;

            keyPress(Qt.Key_J);
            keyAction.enabled = false;
            verify(!keyAction.pressed, "disabling drops the press");
            compare(keyAction.taps, 0);
            keyRelease(Qt.Key_J);
            keyAction.enabled = true;
        }

        function test_without_a_world_it_runs_on_wall_clock() {
            // Wall clock under a loaded runner: lower bounds only.
            wallAction.bufferMs = 5000;
            verify(wallAction.press());
            wait(120);
            // heldMs follows the frames; the release reads the clock itself.
            verify(wallAction.heldMs > 0, "heldMs moves without a step");
            verify(wallAction.release());
            compare(wallAction.taps, 1);
            verify(wallAction.releases[0] >= 100, "held " + wallAction.releases[0]);
            verify(wallAction.consume(), "within bufferMs");
            wallAction.bufferMs = 150;
        }
    }
}
