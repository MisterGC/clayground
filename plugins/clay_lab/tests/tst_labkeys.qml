// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The half of the key map that changes what the MOUSE means, which is the half
// worth guarding: a stuck hand tool (Space held, focus lost, release never
// delivered) leaves every drag moving the scene with nothing on screen saying
// why, and a mode key that a running narration steals leaves the learner
// pressing Space and watching the tour skip ahead.
//
// Since the modes collapsed there are two of them - build and use - and what
// used to be a third is an instrument on a belt. So the cases below come in
// two halves: which mode the pointer is in, and what is in the hand. They are
// independent on purpose, and one case here says exactly that.
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
        property bool springNav: false
        property bool picking: false
        property var modes: ["build", "use"]
        property bool modeLocked: false
        readonly property var allowedModes: modeLocked ? [mode] : modes
        readonly property bool modeSwitchable: allowedModes.length > 1
        function cycleMode() {
            const a = allowedModes
            if (a.length < 2) return
            mode = a[(a.indexOf(mode) + 1) % a.length]
        }
    }

    // Stands in for one instrument: a subject and the two edits.
    QtObject {
        id: fakeTape
        property string name: "dist"
        property int count: 0
        readonly property bool pinnable: count > 0
        function undo() { if (count > 0) count -= 1 }
        function clear() { count = 0 }
    }

    // Stands in for an InstrumentBelt: what is in the hand, and the prompt.
    QtObject {
        id: fakeBelt
        property int heldIndex: -1
        property bool pinning: false
        readonly property var held: heldIndex === 0 ? fakeTape : null
        readonly property bool empty: held === null
        function cycle() { heldIndex = heldIndex + 1 >= 1 ? -1 : heldIndex + 1 }
        function putAway() { heldIndex = -1 }
        function beginPin() { pinning = true }
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
            keymap.hands = null
            keymap.helpVisible = false
            pointer.modes = ["build", "use"]
            pointer.mode = "build"
            pointer.springNav = false
            pointer.modeLocked = false
            fakeFlow.running = false
            fakeFlow.nexts = 0
            fakeTape.count = 0
            fakeBelt.heldIndex = -1
            fakeBelt.pinning = false
        }

        function ev(key, mods, repeat) {
            return { key: key, modifiers: mods === undefined ? 0 : mods,
                     isAutoRepeat: repeat === true }
        }

        function test_space_is_a_quasimode() {
            verify(keymap.handle(ev(Qt.Key_Space)), "the key is consumed")
            verify(pointer.springNav, "the view moves while held")
            compare(pointer.mode, "build", "and the sticky mode is untouched")
            verify(keymap.handleRelease(ev(Qt.Key_Space)), "the release too")
            verify(!pointer.springNav, "back to building on release")
        }

        // A held key repeats as press/release pairs on some platforms; taken at
        // face value the hand flickers on and off through the whole drag.
        function test_autorepeat_does_not_drop_the_hand() {
            keymap.handle(ev(Qt.Key_Space))
            keymap.handle(ev(Qt.Key_Space, 0, true))
            verify(pointer.springNav, "still held")
            keymap.handleRelease(ev(Qt.Key_Space, 0, true))
            verify(pointer.springNav, "an auto-repeat release is not a release")
            keymap.handleRelease(ev(Qt.Key_Space))
            verify(!pointer.springNav, "the real one is")
        }

        function test_b_turns_building_on_and_off() {
            verify(keymap.handle(ev(Qt.Key_B)))
            compare(pointer.mode, "use")
            keymap.handle(ev(Qt.Key_B))
            compare(pointer.mode, "build", "and back again")
        }

        // A lab with a single mode has nothing to show or switch.
        function test_a_one_mode_pointer_has_no_mode_keys() {
            pointer.mode = "use"
            pointer.modes = ["use"]
            verify(!keymap.modeKeys)
            verify(!keymap.handle(ev(Qt.Key_B)), "B is not claimed")
            compare(pointer.mode, "use")
            verify(!keymap.handle(ev(Qt.Key_Space)), "and Space is not either")
            verify(!pointer.springNav)
        }

        function test_a_locked_pointer_has_no_mode_keys() {
            pointer.mode = "use"
            pointer.modeLocked = true
            verify(!keymap.modeKeys)
            verify(!keymap.handle(ev(Qt.Key_B)), "B is not claimed")
            compare(pointer.mode, "use")
            verify(!keymap.handle(ev(Qt.Key_Space)), "and Space is not either")
            verify(!pointer.springNav)
        }

        // Space belongs to a narration while one is on screen: in every lab it
        // is "next step" there, and a reader is not reaching for the hand.
        function test_a_running_flow_keeps_space() {
            keymap.flow = fakeFlow
            fakeFlow.running = true
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "the flow advanced")
            verify(!pointer.springNav, "and nothing sprang")
            fakeFlow.running = false
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "with the flow stopped it is the hand's")
            verify(pointer.springNav)
        }

        function test_the_map_documents_the_mode_keys() {
            const labels = keymap.entries.map(e => e.label)
            verify(labels.indexOf("keys.mode") >= 0, "the toggle is listed")
            verify(labels.indexOf("keys.nav") >= 0, "and the quasimode")
            pointer.modeLocked = true
            const locked = keymap.entries.map(e => e.label)
            compare(locked.indexOf("keys.mode"), -1, "a locked lab lists neither")
            compare(locked.indexOf("keys.nav"), -1)
        }

        // --- the belt --------------------------------------------------------

        function test_h_walks_the_belt_and_ends_empty_handed() {
            keymap.hands = fakeBelt
            verify(keymap.handle(ev(Qt.Key_H)), "the key is claimed")
            compare(fakeBelt.heldIndex, 0, "the first instrument is out")
            keymap.handle(ev(Qt.Key_H))
            compare(fakeBelt.heldIndex, -1, "and past the last one the hand empties")
        }

        // The hand and the mode are separate controls, but they cannot both
        // claim the short click - so the belt couples them in the one place
        // where they would otherwise produce a dead tool. LabKeys does not:
        // it presses the keys, and the belt decides what that means. (The
        // coupling itself is checked where it lives, in tst_belt.)
        function test_the_keys_stay_out_of_the_coupling() {
            keymap.hands = fakeBelt
            keymap.handle(ev(Qt.Key_H))
            compare(fakeBelt.heldIndex, 0, "H took an instrument")
            compare(pointer.mode, "build",
                    "and the key itself changed no mode - the belt's business")
        }

        function test_p_asks_what_to_call_the_reading() {
            keymap.hands = fakeBelt
            keymap.handle(ev(Qt.Key_H))
            verify(!keymap.handle(ev(Qt.Key_P)), "nothing measured, nothing to keep")
            verify(!fakeBelt.pinning)
            fakeTape.count = 2
            verify(keymap.handle(ev(Qt.Key_P)), "with a reading it is claimed")
            verify(fakeBelt.pinning, "and the prompt is open")
        }

        // While the prompt is open the keyboard is the prompt's: typing a name
        // that contains a b or an h must not switch modes underneath it.
        function test_the_prompt_owns_the_keyboard_while_it_is_open() {
            keymap.hands = fakeBelt
            keymap.handle(ev(Qt.Key_H))
            fakeBelt.pinning = true
            verify(!keymap.handle(ev(Qt.Key_H)), "H is the prompt's")
            verify(!keymap.handle(ev(Qt.Key_B)), "and so is B")
            compare(fakeBelt.heldIndex, 0)
            compare(pointer.mode, "build")
        }

        // --- the tape measure's two keys -------------------------------------
        //
        // Both are keys a lab already uses for something else, which is why
        // they are gated on something being in the hand rather than on the belt
        // existing.

        function test_backspace_takes_the_last_point_back() {
            keymap.hands = fakeBelt
            fakeBelt.heldIndex = 0
            fakeTape.count = 3
            verify(keymap.handle(ev(Qt.Key_Backspace)), "the key is claimed")
            compare(fakeTape.count, 2)
            keymap.handle(ev(Qt.Key_Delete))
            compare(fakeTape.count, 1, "Delete says the same thing")
        }

        // One key, walked back one step at a time.
        function test_escape_ends_the_run_then_puts_the_instrument_away() {
            keymap.hands = fakeBelt
            fakeBelt.heldIndex = 0
            fakeTape.count = 3
            verify(keymap.handle(ev(Qt.Key_Escape)))
            compare(fakeTape.count, 0, "the measurement went first")
            compare(fakeBelt.heldIndex, 0, "the instrument is still out")
            verify(keymap.handle(ev(Qt.Key_Escape)))
            compare(fakeBelt.heldIndex, -1, "and the second Esc puts it away")
            verify(!keymap.handle(ev(Qt.Key_Escape)),
                   "with an empty hand Esc is the lab's again")
        }

        // The whole point of gating on the hand: street and electronics keep
        // Del for deleting what they built.
        function test_the_measure_keys_are_the_labs_again_with_an_empty_hand() {
            keymap.hands = fakeBelt
            fakeTape.count = 2
            verify(!keymap.handle(ev(Qt.Key_Backspace)), "Del is the lab's")
            compare(fakeTape.count, 2, "and nothing was measured away")
            verify(!keymap.handle(ev(Qt.Key_Escape)), "so is Esc")
        }

        // Help is on top of everything: Esc closes it first, and the
        // measurement is still there behind it.
        function test_help_closes_before_the_run_does() {
            keymap.hands = fakeBelt
            fakeBelt.heldIndex = 0
            fakeTape.count = 2
            keymap.helpVisible = true
            verify(keymap.handle(ev(Qt.Key_Escape)))
            verify(!keymap.helpVisible, "the list closed")
            compare(fakeTape.count, 2, "the run survived it")
            verify(keymap.handle(ev(Qt.Key_Escape)))
            compare(fakeTape.count, 0, "and the next Esc ends it")
        }

        function test_the_map_documents_the_belt_keys() {
            const bare = keymap.entries.map(e => e.label)
            compare(bare.indexOf("keys.hand"), -1,
                    "a lab without a belt lists no belt keys")
            compare(bare.indexOf("keys.unmeasure"), -1)
            keymap.hands = fakeBelt
            const withBelt = keymap.entries.map(e => e.label)
            verify(withBelt.indexOf("keys.hand") >= 0, "and a lab with one does")
            verify(withBelt.indexOf("keys.pin") >= 0)
            verify(withBelt.indexOf("keys.unmeasure") >= 0)
        }

        // The release that never comes: focus goes elsewhere mid-hold.
        function test_releasing_the_springs_clears_a_stuck_hand() {
            keymap.handle(ev(Qt.Key_Space))
            verify(pointer.springNav)
            keymap.releaseSprings()
            verify(!pointer.springNav)
        }
    }
}
