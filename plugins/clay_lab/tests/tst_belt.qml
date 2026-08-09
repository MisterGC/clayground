// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The belt: what is on it, what is in the hand, and the two rules that make
// "navigation is never taken away" true in practice rather than on paper.
//
// The first is that picking is on exactly when something is held - the belt is
// the only writer of that flag, so this is where it can be checked at all.
//
// The second is the one case where the hand and the mode are not independent.
// Building and holding an instrument are two claims on the same short click,
// and a state where both are true is a tool that silently does nothing while
// the hint bar describes it working. That was a real render, not a
// hypothetical, which is why it has a case here.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // Stands in for an OrbitInput3D: the members the belt touches, with the
    // same rules about which modes exist.
    QtObject {
        id: pointer
        property string mode: "build"
        property bool picking: false
        property var modes: ["build", "use"]
        function allows(m) { return modes.indexOf(m) >= 0 }
        function setMode(m) { if (allows(m)) mode = m }
        signal picked(var pick)
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
            pointer.mode = "build"
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

        // --- the one input that changes meaning -------------------------------

        function test_picking_is_on_exactly_while_something_is_held() {
            verify(!pointer.picking, "an empty hand picks nothing")
            belt.takeNamed("dist")
            verify(pointer.picking, "and a full one does")
            belt.putAway()
            verify(!pointer.picking, "and it goes off again")
        }

        function test_a_pick_reaches_the_instrument_in_hand_and_no_other() {
            belt.takeNamed("dist")
            pointer.picked(pickAt(1, 2))
            compare(belt.held.count, 1)
            const other = belt.instruments[1]
            compare(other.count, 0, "the one on the belt heard nothing")
        }

        function test_a_pick_with_an_empty_hand_goes_nowhere() {
            pointer.picked(pickAt(1, 2))
            for (const i of belt.instruments) compare(i.count, 0, i.name)
        }

        // --- the coupling -----------------------------------------------------

        function test_taking_an_instrument_hands_the_pointer_over() {
            compare(pointer.mode, "build")
            belt.takeNamed("dist")
            compare(pointer.mode, "use",
                    "an instrument in a building hand would be a dead tool")
        }

        function test_going_back_to_building_puts_the_instrument_away() {
            belt.takeNamed("dist")
            pointer.mode = "build"
            verify(belt.empty, "the click is the lab's again, so the hand is empty")
            verify(!pointer.picking)
        }

        // A lab with nothing to build never enters that state, and the
        // coupling must not invent a mode it does not have.
        function test_a_lab_that_cannot_build_is_unaffected() {
            pointer.modes = ["use"]
            pointer.mode = "use"
            belt.takeNamed("dist")
            compare(pointer.mode, "use")
            verify(pointer.picking)
            pointer.modes = ["build", "use"]
        }
    }
}
