// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Clayground.GameController

// A GameController's layout decides which inputs its sources set (#463).
Item {
    id: root
    width: 200; height: 200

    Item {
        id: player
        anchors.fill: parent
        focus: true
        Keys.forwardTo: ctrl
        GameController { id: ctrl; anchors.fill: parent }
    }

    // Stands in for the Dojo's ClayInputCtrl.
    QtObject {
        id: agent
        property bool active: false
        property var gamepad: ({})
        signal stateChanged()
        function set(state) {
            gamepad = state;
            active = true;
            stateChanged();
        }
    }
    GameController { id: agentCtrl }
    SyntheticGamepad { id: synth; gameController: agentCtrl; source: agent }

    readonly property var fullKeys: ({
        axisX: [Qt.Key_A, Qt.Key_D], axisY: [Qt.Key_S, Qt.Key_W],
        axisRightX: [Qt.Key_J, Qt.Key_L], axisRightY: [Qt.Key_K, Qt.Key_I],
        buttonA: Qt.Key_M, buttonB: Qt.Key_N, buttonX: Qt.Key_U,
        buttonY: Qt.Key_O, buttonL1: Qt.Key_Q, buttonR1: Qt.Key_E,
        triggerL2: Qt.Key_1, triggerR2: Qt.Key_3,
        buttonStart: Qt.Key_Return, buttonSelect: Qt.Key_Backspace
    })

    // The key that drives an input to its non-neutral value
    function onKey(name) {
        const k = fullKeys[name];
        return Array.isArray(k) ? k[1] : k;
    }

    function pressed(name) { return name.startsWith("button") ? true : 1; }
    function neutral(name) { return name.startsWith("button") ? false : 0; }

    TestCase {
        name: "GameControllerLayout"
        when: windowShown

        function init() {
            ctrl.layout = "nes";
            agentCtrl.layout = "nes";
            player.forceActiveFocus();
        }

        function cleanup() {
            for (const name in fullKeys) keyRelease(onKey(name));
        }

        function test_nes_is_the_default_with_stick_and_two_buttons() {
            const fresh = createTemporaryObject(
                Qt.createComponent("Clayground.GameController", "GameController"), root);
            compare(fresh.layout, "nes");
            compare(fresh.inputs, ["axisX", "axisY", "buttonA", "buttonB"]);
        }

        function test_full_has_every_input() {
            ctrl.layout = "full";
            compare(ctrl.inputs.length, 14);
            for (const name in fullKeys)
                verify(ctrl.inputs.indexOf(name) !== -1, name);
        }

        function test_keyboard_sets_every_input_of_full() {
            ctrl.layout = "full";
            ctrl.selectKeyboard(fullKeys);
            for (const name of ctrl.inputs) {
                compare(ctrl.inputValue(name), neutral(name), name);
                keyPress(onKey(name));
                compare(ctrl.inputValue(name), pressed(name), name);
                keyRelease(onKey(name));
                compare(ctrl.inputValue(name), neutral(name), name);
            }
            // The negative key of each axis
            keyPress(Qt.Key_J);
            compare(ctrl.axisRightX, -1);
            keyRelease(Qt.Key_J);
            keyPress(Qt.Key_K);
            compare(ctrl.axisRightY, -1);
            keyRelease(Qt.Key_K);
        }

        function test_keyboard_sets_only_stick_and_ab_under_nes() {
            ctrl.selectKeyboard(fullKeys);
            for (const name in fullKeys) keyPress(onKey(name));
            compare(ctrl.axisX, 1);
            compare(ctrl.axisY, 1);
            verify(ctrl.buttonAPressed);
            verify(ctrl.buttonBPressed);
            compare(ctrl.axisRightX, 0);
            compare(ctrl.axisRightY, 0);
            verify(!ctrl.buttonXPressed);
            verify(!ctrl.buttonYPressed);
            verify(!ctrl.buttonL1Pressed);
            verify(!ctrl.buttonR1Pressed);
            compare(ctrl.triggerL2, 0);
            compare(ctrl.triggerR2, 0);
            verify(!ctrl.buttonStartPressed);
            verify(!ctrl.buttonSelectPressed);
        }

        function test_switching_layout_applies_held_keys_and_neutralises_the_rest() {
            ctrl.selectKeyboard(fullKeys);
            keyPress(Qt.Key_U);
            keyPress(Qt.Key_L);
            verify(!ctrl.buttonXPressed);
            ctrl.layout = "full";
            verify(ctrl.buttonXPressed);
            compare(ctrl.axisRightX, 1);
            ctrl.layout = "nes";
            verify(!ctrl.buttonXPressed);
            compare(ctrl.axisRightX, 0);
        }

        // The six-key form keeps its order under full: the fifth key is B.
        function test_six_keys_still_map_stick_and_two_buttons() {
            ctrl.layout = "full";
            ctrl.selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
                                Qt.Key_M, Qt.Key_N);
            keyPress(Qt.Key_M);
            verify(ctrl.buttonBPressed);
            verify(!ctrl.buttonAPressed);
            keyPress(Qt.Key_N);
            verify(ctrl.buttonAPressed);
            keyPress(Qt.Key_U);
            verify(!ctrl.buttonXPressed);
            keyRelease(Qt.Key_M);
            keyRelease(Qt.Key_N);
            keyRelease(Qt.Key_U);
        }

        function test_unknown_layout_behaves_as_nes() {
            ignoreWarning(/unknown layout 'snes'/);
            ctrl.layout = "snes";
            compare(ctrl.inputs, ["axisX", "axisY", "buttonA", "buttonB"]);
        }

        function test_dojo_input_sets_every_input_of_full() {
            agentCtrl.layout = "full";
            const state = {};
            for (const name of agentCtrl.inputs) state[name] = pressed(name);
            agent.set(state);
            for (const name of agentCtrl.inputs)
                compare(agentCtrl.inputValue(name), pressed(name), name);
            agent.set({});
            for (const name of agentCtrl.inputs)
                compare(agentCtrl.inputValue(name), neutral(name), name);
        }

        function test_dojo_input_sets_only_stick_and_ab_under_nes() {
            agent.set({axisX: -1, buttonB: true, buttonX: true,
                       axisRightY: 1, triggerR2: 0.5, buttonStart: true});
            compare(agentCtrl.axisX, -1);
            verify(agentCtrl.buttonBPressed);
            verify(!agentCtrl.buttonXPressed);
            compare(agentCtrl.axisRightY, 0);
            compare(agentCtrl.triggerR2, 0);
            verify(!agentCtrl.buttonStartPressed);
            agentCtrl.layout = "full";
            verify(agentCtrl.buttonXPressed);
            compare(agentCtrl.triggerR2, 0.5);
            agent.set({});
        }
    }
}
