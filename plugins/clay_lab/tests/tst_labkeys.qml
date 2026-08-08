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

    // Stands in for an OrbitInput3D: the members LabKeys touches, with the
    // same rules - the modes a scene offers are a LIST, and one mode is no
    // switch at all.
    QtObject {
        id: pointer
        property string mode: "build"
        property bool springExplore: false
        property var modes: ["build", "explore", "measure"]
        property bool modeLocked: false
        readonly property var allowedModes: modeLocked ? [mode] : modes
        readonly property bool modeSwitchable: allowedModes.length > 1
        function cycleMode() {
            const a = allowedModes
            if (a.length < 2) return
            mode = a[(a.indexOf(mode) + 1) % a.length]
        }
    }

    // Stands in for a MeasureTool: a run of points and the two edits.
    QtObject {
        id: fakeMeasure
        property int count: 0
        function undo() { if (count > 0) count -= 1 }
        function clear() { count = 0 }
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
            keymap.measure = null
            keymap.helpVisible = false
            pointer.modes = ["build", "explore", "measure"]
            pointer.mode = "build"
            pointer.springExplore = false
            pointer.modeLocked = false
            fakeFlow.running = false
            fakeFlow.nexts = 0
            fakeMeasure.count = 0
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

        function test_b_walks_the_modes_for_good() {
            verify(keymap.handle(ev(Qt.Key_B)))
            compare(pointer.mode, "explore")
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "measure")
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "build", "and round again")
        }

        // A lab that offers two modes cycles two; the key does not have to know
        // which two they are.
        function test_b_only_walks_the_modes_the_lab_offers() {
            pointer.modes = ["explore", "measure"]
            pointer.mode = "explore"
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "measure")
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "explore", "build is never passed through")
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

        // A lab with a single mode has nothing to show or switch.
        function test_a_one_mode_pointer_has_no_mode_keys() {
            pointer.mode = "explore"
            pointer.modes = ["explore"]
            verify(!keymap.modeKeys)
            verify(!keymap.handle(ev(Qt.Key_B)), "B is not claimed")
            compare(pointer.mode, "explore")
            verify(!keymap.handle(ev(Qt.Key_Space)), "and Space is not either")
            verify(!pointer.springExplore)
        }

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

        // --- the tape measure's two keys -----------------------------------
        //
        // Both are keys a lab already uses for something else, which is why
        // they are gated on the mode rather than on the tool existing.

        function test_backspace_takes_the_last_point_back() {
            keymap.measure = fakeMeasure
            pointer.mode = "measure"
            fakeMeasure.count = 3
            verify(keymap.handle(ev(Qt.Key_Backspace)), "the key is claimed")
            compare(fakeMeasure.count, 2)
            keymap.handle(ev(Qt.Key_Delete))
            compare(fakeMeasure.count, 1, "Delete says the same thing")
        }

        function test_escape_ends_the_run() {
            keymap.measure = fakeMeasure
            pointer.mode = "measure"
            fakeMeasure.count = 3
            verify(keymap.handle(ev(Qt.Key_Escape)))
            compare(fakeMeasure.count, 0)
            verify(!keymap.handle(ev(Qt.Key_Escape)),
                   "with nothing measured Esc is the lab's again")
        }

        // The whole point of gating on the mode: street and electronics keep
        // Del for deleting what they built.
        function test_the_measure_keys_are_the_labs_again_outside_measure_mode() {
            keymap.measure = fakeMeasure
            fakeMeasure.count = 2
            pointer.mode = "build"
            verify(!keymap.handle(ev(Qt.Key_Backspace)), "Del is the lab's")
            compare(fakeMeasure.count, 2, "and nothing was measured away")
            verify(!keymap.handle(ev(Qt.Key_Escape)), "so is Esc")
        }

        // Help is on top of everything: Esc closes it first, and the
        // measurement is still there behind it.
        function test_help_closes_before_the_run_does() {
            keymap.measure = fakeMeasure
            pointer.mode = "measure"
            fakeMeasure.count = 2
            keymap.helpVisible = true
            verify(keymap.handle(ev(Qt.Key_Escape)))
            verify(!keymap.helpVisible, "the list closed")
            compare(fakeMeasure.count, 2, "the run survived it")
            verify(keymap.handle(ev(Qt.Key_Escape)))
            compare(fakeMeasure.count, 0, "and the next Esc ends it")
        }

        function test_the_map_documents_the_measure_keys() {
            compare(keymap.entries.map(e => e.label).indexOf("keys.unmeasure"), -1,
                    "a lab without a tape measure lists no tape measure keys")
            keymap.measure = fakeMeasure
            verify(keymap.entries.map(e => e.label).indexOf("keys.unmeasure") >= 0,
                   "and a lab with one does")
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
