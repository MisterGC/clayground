// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The half of the key map that touches the MOUSE, which is the half worth
// guarding: a stuck hand tool (Space held, focus lost, release never delivered)
// leaves every drag moving the scene with nothing on screen saying why, and a
// key that a running narration steals leaves the learner pressing Space and
// watching the tour skip ahead.
//
// There is one such key left. B is gone with the modes it switched: a tool is
// something you pick up now, so the only key that lends the mouse to the camera
// is Space, and it lends it only for as long as it is held. What remains
// besides is the belt - H, P and the editing keys - which is a separate half
// and does not negotiate with anything.
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

    // Stands in for an OrbitInput3D - and it is this small on purpose: the one
    // member LabKeys writes is springNav.
    QtObject {
        id: pointer
        property bool springNav: false
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
        name: "LabKeys.pointer"

        function init() {
            keymap.flow = null
            keymap.hands = null
            keymap.helpVisible = false
            pointer.springNav = false
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

        function test_space_lends_the_view_while_it_is_held() {
            verify(keymap.handle(ev(Qt.Key_Space)), "the key is consumed")
            verify(pointer.springNav, "the left button pans while held")
            verify(keymap.handleRelease(ev(Qt.Key_Space)), "the release too")
            verify(!pointer.springNav, "and it leaves nothing behind")
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

        // The mode key is gone, and B is now free for whatever a lab wants:
        // this map does not claim it, and nothing happens to the pointer.
        function test_b_is_nobodys_key_any_more() {
            verify(!keymap.handle(ev(Qt.Key_B)), "B is not claimed")
            verify(!pointer.springNav, "and it moved nothing")
            const labels = keymap.entries.map(e => e.label)
            compare(labels.indexOf("keys.mode"), -1, "nor is it in the help")
        }

        // A lab that hands over no pointer has no Space either - it is the
        // camera's key, and there is no camera.
        function test_no_pointer_no_space() {
            keymap.pointer = null
            verify(!keymap.navKeys)
            verify(!keymap.handle(ev(Qt.Key_Space)), "Space is not claimed")
            const labels = keymap.entries.map(e => e.label)
            compare(labels.indexOf("keys.nav"), -1, "and it is not documented")
            keymap.pointer = pointer
        }

        // Space belongs to a narration while one is on screen: in every lab it
        // is "next step" there, and a reader is not reaching for the view.
        function test_a_running_flow_keeps_space() {
            keymap.flow = fakeFlow
            fakeFlow.running = true
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "the flow advanced")
            verify(!pointer.springNav, "and nothing sprang")
            fakeFlow.running = false
            verify(keymap.handle(ev(Qt.Key_Space)))
            compare(fakeFlow.nexts, 1, "with the flow stopped it is the view's")
            verify(pointer.springNav)
        }

        function test_the_map_documents_the_one_pointer_key() {
            const labels = keymap.entries.map(e => e.label)
            verify(labels.indexOf("keys.nav") >= 0, "the quasimode is listed")
        }

        // --- the belt --------------------------------------------------------

        function test_h_walks_the_belt_and_ends_empty_handed() {
            keymap.hands = fakeBelt
            verify(keymap.handle(ev(Qt.Key_H)), "the key is claimed")
            compare(fakeBelt.heldIndex, 0, "the first instrument is out")
            keymap.handle(ev(Qt.Key_H))
            compare(fakeBelt.heldIndex, -1, "and past the last one the hand empties")
        }

        // H used to have to negotiate with B, because taking an instrument out
        // had to take the pointer back off the lab's tool. It does not any more:
        // the belt and the camera share nothing.
        function test_taking_an_instrument_moves_nothing_but_the_belt() {
            keymap.hands = fakeBelt
            keymap.handle(ev(Qt.Key_H))
            compare(fakeBelt.heldIndex, 0, "H took an instrument")
            verify(!pointer.springNav, "and the camera never heard about it")
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
        // that contains an h must not empty the hand underneath it.
        function test_the_prompt_owns_the_keyboard_while_it_is_open() {
            keymap.hands = fakeBelt
            keymap.handle(ev(Qt.Key_H))
            fakeBelt.pinning = true
            verify(!keymap.handle(ev(Qt.Key_H)), "H is the prompt's")
            verify(!keymap.handle(ev(Qt.Key_Space)), "and so is Space")
            compare(fakeBelt.heldIndex, 0)
            verify(!pointer.springNav)
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
