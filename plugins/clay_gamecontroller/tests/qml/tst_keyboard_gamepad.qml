// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// The keyboard gamepad derives its axes from the set of held keys (#413).
Item {
    id: root
    width: 200; height: 200

    // Keys reach the controller the way games route them: a focused parent
    // forwards them.
    Item {
        id: player
        anchors.fill: parent
        focus: true
        Keys.forwardTo: ctrl
        GameController { id: ctrl; anchors.fill: parent }
    }

    // Takes the focus away, like an overlay or a menu would.
    Item { id: overlay }

    TestCase {
        name: "KeyboardGamepad"
        when: windowShown

        function init() {
            ctrl.selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
                                Qt.Key_J, Qt.Key_K);
            player.forceActiveFocus();
            verify(player.activeFocus);
        }

        function cleanup() {
            for (const k of [Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
                             Qt.Key_J, Qt.Key_K])
                keyRelease(k);
        }

        function test_releasing_one_direction_keeps_the_other() {
            keyPress(Qt.Key_A);
            compare(ctrl.axisX, -1);
            keyPress(Qt.Key_D);
            keyRelease(Qt.Key_D);
            compare(ctrl.axisX, -1);
            keyRelease(Qt.Key_A);
            compare(ctrl.axisX, 0);
        }

        function test_opposite_keys_cancel() {
            keyPress(Qt.Key_A);
            keyPress(Qt.Key_D);
            compare(ctrl.axisX, 0);
            keyPress(Qt.Key_W);
            keyPress(Qt.Key_S);
            compare(ctrl.axisY, 0);
            keyRelease(Qt.Key_S);
            compare(ctrl.axisY, 1);
        }

        function test_focus_loss_releases_all() {
            keyPress(Qt.Key_A);
            keyPress(Qt.Key_W);
            keyPress(Qt.Key_J);
            keyPress(Qt.Key_K);
            compare(ctrl.axisX, -1);
            compare(ctrl.axisY, 1);
            verify(ctrl.buttonAPressed);
            verify(ctrl.buttonBPressed);

            overlay.forceActiveFocus();
            verify(!player.activeFocus);
            compare(ctrl.axisX, 0);
            compare(ctrl.axisY, 0);
            verify(!ctrl.buttonAPressed);
            verify(!ctrl.buttonBPressed);

            // The releases land on the overlay; nothing comes back held.
            keyRelease(Qt.Key_A);
            keyRelease(Qt.Key_W);
            player.forceActiveFocus();
            compare(ctrl.axisX, 0);
            compare(ctrl.axisY, 0);
        }
    }
}
