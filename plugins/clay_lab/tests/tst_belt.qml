// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The belt: what is on it, what is in the hand, and the rule that decides what
// a left click means.
//
// That last one used to live in OrbitInput3D, gated on a mode, and the mode is
// why the switch on a circuit board could not be flipped: the camera took the
// press. The camera no longer takes the left button at all, so nothing gates
// the hand any more - which moves the click-versus-drag decision here, where it
// is the belt's own arithmetic and can be checked without a camera.
//
// The pointer below is a fake with just two members: pickAt, which the belt
// asks, and nothing else. That it is that small IS the contract - the belt
// writes no state on the pointer, so there is no state to get stuck.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // Stands in for an OrbitInput3D. Pixel (x, y) is world (x, 0, y), so every
    // assertion below is readable by eye.
    QtObject {
        id: pointer
        property int asked: 0
        function pickAt(x, y) {
            asked += 1
            return { point: Qt.vector3d(x, 0, y), object: null, x: x, y: y }
        }
    }

    InstrumentBelt {
        id: belt
        pointer: pointer
        unit: "m"
    }

    TestCase {
        name: "InstrumentBelt"

        function init() {
            belt.putAway()
            belt.release()          // no press left running from a failed case
            pointer.asked = 0
            for (const i of belt.instruments) if (i.clear) i.clear()
        }

        function pickAt(x, z) { return { point: Qt.vector3d(x, 0, z), object: null } }

        // --- what is on it ----------------------------------------------------

        function test_every_lab_has_the_kernels_instruments() {
            const names = belt.instruments.map(i => i.name)
            verify(names.indexOf("dist") >= 0, "a tape measure, undeclared: " + names)
            verify(names.indexOf("time") >= 0, "and a stopwatch")
        }

        function test_the_lab_says_what_unit_its_world_is_in() {
            belt.takeNamed("dist")
            belt.held.add(pickAt(3, 4))
            belt.held.add(pickAt(0, 0))
            compare(belt.held.readout.segments[0].text, "5.00 m",
                    "the belt's unit reached the instrument")
        }

        // --- what is in the hand ----------------------------------------------

        function test_taking_and_putting_down() {
            verify(belt.empty)
            belt.take(0)
            compare(belt.held, belt.instruments[0])
            verify(belt.held.held, "the instrument knows it is out")
            belt.putAway()
            verify(belt.empty)
            verify(!belt.instruments[0].held)
        }

        // Empty is a position on the belt, so the plain camera is always one
        // more press away rather than needing a key of its own.
        function test_cycling_ends_empty_handed() {
            const n = belt.instruments.length
            for (var i = 0; i < n; ++i) {
                belt.cycle()
                compare(belt.heldIndex, i)
            }
            belt.cycle()
            compare(belt.heldIndex, -1, "past the last one, the hand empties")
        }

        // Taking an instrument out writes NOTHING on the pointer. It used to
        // set a flag and switch a mode, and both were only there because the
        // camera might otherwise have eaten the click.
        function test_taking_an_instrument_touches_the_pointer_not_at_all() {
            belt.takeNamed("dist")
            compare(pointer.asked, 0, "nothing was asked of it")
            belt.putAway()
            compare(pointer.asked, 0)
        }

        // --- the click, versus the drag ---------------------------------------

        function test_a_click_reaches_the_instrument_in_hand() {
            belt.takeNamed("dist")
            belt.press(60, -40)
            verify(belt.release(), "the press was a click")
            compare(belt.held.count, 1, "and it landed")
            const p = belt.held.picks[0]
            verify(Math.abs(p.x - 60) < 1e-3 && Math.abs(p.z + 40) < 1e-3,
                   "where it was clicked: " + p)
        }

        // A drag with a tape measure in hand is somebody dragging, not
        // measuring: the lab may be doing something else with that gesture, and
        // a stray point is the more annoying of the two mistakes.
        function test_a_drag_hands_over_nothing() {
            belt.takeNamed("dist")
            belt.press(60, -40)
            belt.move(120, -40)
            verify(!belt.release(), "not a click")
            compare(belt.held.count, 0, "so nothing was measured")
            compare(pointer.asked, 0, "and the pointer was never even asked")
        }

        // A hand that trembles is not a drag.
        function test_a_trembling_click_is_still_a_click() {
            belt.takeNamed("dist")
            belt.press(60, -40)
            belt.move(62, -39)
            verify(belt.release())
            compare(belt.held.count, 1)
            const p = belt.held.picks[0]
            verify(Math.abs(p.x - 60) < 1e-3,
                   "the pressed pixel, not the released one: " + p)
        }

        // Distance FROM THE PRESS, not path length: a drag that wanders out and
        // comes back is still a drag.
        function test_a_drag_that_returns_home_is_still_a_drag() {
            belt.takeNamed("dist")
            belt.press(60, -40)
            belt.move(160, -40)
            belt.move(60, -40)
            verify(!belt.release())
            compare(belt.held.count, 0)
        }

        function test_a_click_with_an_empty_hand_goes_nowhere() {
            belt.press(60, -40)
            verify(!belt.release(), "nothing is holding it")
            for (const i of belt.instruments) compare(i.count, 0, i.name)
            compare(pointer.asked, 0)
        }

        function test_a_pick_reaches_the_instrument_in_hand_and_no_other() {
            belt.takeNamed("dist")
            belt.press(1, 2)
            belt.release()
            compare(belt.held.count, 1)
            const other = belt.instruments[1]
            compare(other.count, 0, "the one on the belt heard nothing")
        }

        // A release with no press before it is not a click - the lab forwards
        // every release it gets, including the ones that began on the camera.
        function test_a_release_without_a_press_is_nothing() {
            belt.takeNamed("dist")
            verify(!belt.release())
            compare(belt.held.count, 0)
            verify(!belt.move(10, 10), "and a move outside a press says so too")
        }

        // A measurement survives NAVIGATING, which is the thing that used to
        // destroy it: looking around meant leaving the measuring mode, and
        // leaving the mode put the tape away. Nothing here reaches the camera
        // any more, so the run cannot be collateral damage.
        //
        // (Putting the tape down still ends the run - HandheldInstrument's
        // clearOnPutAway, which tst_tapemeasure owns.)
        function test_a_reading_survives_everything_the_pointer_does() {
            belt.takeNamed("dist")
            belt.press(0, 0); belt.release()
            belt.press(3, 4); belt.release()
            compare(belt.held.count, 2)
            // presses the camera took: the lab never forwards them, so the belt
            // sees a release with no press - and must not mistake it for a click
            belt.release()
            belt.move(200, 200)
            compare(belt.held.count, 2, "the measurement is untouched")
        }
    }
}
