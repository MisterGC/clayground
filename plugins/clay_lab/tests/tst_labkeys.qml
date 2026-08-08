// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The half of the key map that changes what the MOUSE means, which is the half
// worth guarding: a stuck hand tool (Space held, focus lost, release never
// delivered) leaves every drag moving the scene with nothing on screen saying
// why, and a mode key that a running narration steals leaves the learner
// pressing Space and watching the tour skip ahead.
//
// The events are plain objects rather than synthesized key presses: handle()
// reads three fields off them, and building a real event would test QtTest's
// delivery, not this contract.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50
    id: fakeLab

    // Stands in for an OrbitInput3D: the three members LabKeys touches.
    QtObject {
        id: pointer
        property string mode: "build"
        property bool springExplore: false
        property bool modeLocked: false
        function toggleMode() {
            if (modeLocked) return
            mode = (mode === "explore") ? "build" : "explore"
        }
    }

    QtObject {
        id: fakeFlow
        property bool running: false
        property int nexts: 0
        function next() { nexts += 1 }
        function prev() {}
        function stop() { running = false }
        function start() { running = true }
    }

    LabKeys {
        id: keymap
        lab: fakeLab
        pointer: pointer
    }

    TestCase {
        name: "LabKeys.modes"

        function init() {
            keymap.flow = null
            pointer.mode = "build"
            pointer.springExplore = false
            pointer.modeLocked = false
            fakeFlow.running = false
            fakeFlow.nexts = 0
        }

        function ev(key, mods, repeat) {
            return { key: key, modifiers: mods === undefined ? 0 : mods,
                     isAutoRepeat: repeat === true }
        }

        function test_space_is_a_quasimode() {
            verify(keymap.handle(ev(Qt.Key_Space)), "the key is consumed")
            verify(pointer.springExplore, "explore while held")
            compare(pointer.mode, "build", "and the sticky mode is untouched")
            verify(keymap.handleRelease(ev(Qt.Key_Space)), "the release too")
            verify(!pointer.springExplore, "back to building on release")
        }

        // A held key repeats as press/release pairs on some platforms; taken at
        // face value the hand flickers on and off through the whole drag.
        function test_autorepeat_does_not_drop_the_hand() {
            keymap.handle(ev(Qt.Key_Space))
            keymap.handle(ev(Qt.Key_Space, 0, true))
            verify(pointer.springExplore, "still held")
            keymap.handleRelease(ev(Qt.Key_Space, 0, true))
            verify(pointer.springExplore, "an auto-repeat release is not a release")
            keymap.handleRelease(ev(Qt.Key_Space))
            verify(!pointer.springExplore, "the real one is")
        }

        function test_b_switches_the_mode_for_good() {
            verify(keymap.handle(ev(Qt.Key_B)))
            compare(pointer.mode, "explore")
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "build")
        }

        // Space belongs to a narration while one is on screen: in every lab it
        // is "next step" there, and a reader is not reaching for the hand.
        function test_a_running_flow_keeps_space() {
            keymap.flow = fakeFlow
            fakeFlow.running = true
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "the flow advanced")
            verify(!pointer.springExplore, "and nothing sprang")
            fakeFlow.running = false
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "with the flow stopped it is the hand's")
            verify(pointer.springExplore)
        }

        // A lab with nothing to build has no mode to show or switch.
        function test_a_locked_pointer_has_no_mode_keys() {
            pointer.mode = "explore"
            pointer.modeLocked = true
            verify(!keymap.modeKeys)
            verify(!keymap.handle(ev(Qt.Key_B)), "B is not claimed")
            compare(pointer.mode, "explore")
            verify(!keymap.handle(ev(Qt.Key_Space)), "and Space is not either")
            verify(!pointer.springExplore)
        }

        function test_the_map_documents_the_mode_keys() {
            const labels = keymap.entries.map(e => e.label)
            verify(labels.indexOf("keys.mode") >= 0, "the toggle is listed")
            verify(labels.indexOf("keys.explore") >= 0, "and the quasimode")
            pointer.modeLocked = true
            const locked = keymap.entries.map(e => e.label)
            compare(locked.indexOf("keys.mode"), -1, "a locked lab lists neither")
            compare(locked.indexOf("keys.explore"), -1)
        }

        // The release that never comes: focus goes elsewhere mid-hold.
        function test_releasing_the_springs_clears_a_stuck_hand() {
            keymap.handle(ev(Qt.Key_Space))
            verify(pointer.springExplore)
            keymap.releaseSprings()
            verify(!pointer.springExplore)
        }
    }
}
