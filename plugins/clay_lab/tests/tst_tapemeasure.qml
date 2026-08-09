// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The tape measure's STATE - what a click adds, what an edit takes away, and
// the rule that a measurement is a question being asked now: it does not
// survive being put down, and it is not in any viewState.
//
// The arithmetic it reports is measure.js', checked by node; what is checked
// here is the wiring between a pick and that arithmetic - and, since the
// handheld contract landed, that the tape takes its picks as the belt hands
// them over rather than reaching for a pointer of its own.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // A view that projects a world point to (x, z) pixels and calls anything
    // past `horizon` on the z axis BEHIND the camera - which is the one thing
    // about projection the overlay has to react to.
    QtObject {
        id: fakeView
        property real horizon: 1e9
        property real width: 800
        property real height: 600
        property QtObject camera: QtObject {
            property vector3d scenePosition: Qt.vector3d(0, 0, 0)
            property quaternion sceneRotation: Qt.quaternion(1, 0, 0, 0)
        }
        function mapFrom3DScene(v) {
            return Qt.vector3d(v.x, v.z, v.z > horizon ? -1 : 1)
        }
    }

    TapeMeasure {
        id: tape
        unit: "m"
        held: true
    }

    TestCase {
        name: "TapeMeasure"

        function init() {
            tape.held = true
            tape.view = null
            fakeView.horizon = 1e9
            tape.clear()
        }

        function p(x, z) { return Qt.vector3d(x, 0, z) }

        // What the belt hands an instrument: a place AND a thing, of which
        // this one uses the place.
        function pick(x, z) { return { point: p(x, z), object: null, x: x, y: z } }

        function test_a_click_chains_a_point_onto_the_run() {
            verify(tape.empty, "nothing measured yet")
            tape.add(pick(0, 0))
            compare(tape.count, 1)
            verify(tape.empty === false)
            tape.add(pick(4, 0))
            compare(tape.count, 2, "the second chains to the first")
            compare(tape.lengths.length, 1, "which is one leg")
            fuzzyCompare(tape.lengths[0], 4, 1e-6)
            fuzzyCompare(tape.total, 4, 1e-6)
        }

        // The 3-4-5 corner, as the labs' drivers measure it.
        function test_three_points_carry_two_legs_a_corner_and_a_total() {
            tape.add(pick(4, 0))
            tape.add(pick(0, 0))
            tape.add(pick(4, 3))
            compare(tape.lengths.length, 2)
            fuzzyCompare(tape.lengths[0], 4, 1e-6)
            fuzzyCompare(tape.lengths[1], 5, 1e-6)
            compare(tape.angles.length, 1, "one interior corner")
            fuzzyCompare(tape.angles[0], 36.8698976, 1e-5)
            fuzzyCompare(tape.total, 9, 1e-6)
            // the kernel's quantity rule, unit and all: significant digits by
            // magnitude, so a long road does not print four decimals
            compare(tape.readout.segments[0].text, "4.00 m", "in the lab's unit")
            compare(tape.readout.vertices[0].text, "36.9°")
            compare(tape.readout.totalText, "9.00 m")
        }

        // A single leg needs no total: it would repeat the one number above it.
        function test_a_single_leg_has_no_total_to_write() {
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            compare(tape.readout.totalAt, null)
            tape.add(pick(4, 3))
            verify(tape.readout.totalAt !== null, "two legs are worth adding up")
        }

        function test_undo_takes_the_last_point_back() {
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            tape.undo()
            compare(tape.count, 1)
            tape.undo()
            compare(tape.count, 0)
            tape.undo()
            compare(tape.count, 0, "and an empty run stays empty")
        }

        function test_clear_ends_the_run() {
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            tape.clear()
            verify(tape.empty)
            compare(tape.total, 0)
        }

        // A measurement outlives being put down. It did not always: while
        // measuring was a MODE of its own, leaving the mode was leaving the
        // question, so the run went with it. There is no such mode now, and
        // the case that matters runs the other way - measure the gap, then
        // pick up the road tool and build to it. Only Esc or a clear ends a
        // run.
        function test_putting_the_tape_down_keeps_the_run() {
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            tape.held = false
            compare(tape.count, 2, "still measured")
            tape.held = true
            compare(tape.count, 2, "and picking it up again finds it there")
        }

        // Which is a policy, not a law: an instrument whose subject cannot
        // outlive the holding says so.
        function test_an_instrument_may_end_its_run_when_put_down() {
            tape.clearOnPutAway = true
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            tape.held = false
            verify(tape.empty, "ended")
            tape.clearOnPutAway = false
            tape.held = true
        }

        // A pick with no ground point under it - the ray missed the plane -
        // still arrives, because the object half may have been the point of
        // it. An instrument that measures places ignores it rather than
        // storing a hole.
        function test_a_pick_with_no_place_is_ignored() {
            tape.add(pick(0, 0))
            tape.add({ point: null, object: null, x: 0, y: 0 })
            compare(tape.count, 1, "nothing was added")
        }

        function test_it_reports_itself_to_a_driver() {
            tape.add(pick(4, 0))
            tape.add(pick(0, 0))
            tape.add(pick(4, 3))
            const i = tape.info()
            compare(i.name, "dist")
            compare(i.kind, "point")
            compare(i.count, 3)
            compare(i.unit, "m")
            compare(i.texts.length, 2)
            compare(i.angleTexts[0], "36.9°")
            fuzzyCompare(i.total, 9, 1e-6)
        }

        // With no view there is nothing to project onto, and the overlay must
        // sit quietly rather than throw: the measurement is still valid data.
        function test_no_view_costs_the_drawing_not_the_measurement() {
            tape.add(pick(0, 0))
            tape.add(pick(4, 0))
            compare(tape.plan.segs.length, 0, "nothing to draw")
            fuzzyCompare(tape.total, 4, 1e-6, "but it still measures")
        }

        // --- the projection ------------------------------------------------

        function test_the_run_is_projected_into_view_pixels() {
            tape.view = fakeView
            tape.add(pick(0, 0))
            tape.add(pick(4, 6))
            compare(tape.plan.pts.length, 2)
            compare(tape.plan.segs.length, 1)
            fuzzyCompare(tape.plan.segs[0].bx, 4, 1e-6)
            fuzzyCompare(tape.plan.segs[0].by, 6, 1e-6, "z is the screen's y")
            fuzzyCompare(tape.plan.segs[0].mx, 2, 1e-6, "and the label is midway")
            verify(tape.plan.segs[0].ok)
        }

        // Walking past your own tape measure must not delete it: the segment
        // stops being DRAWN, the measurement is untouched.
        function test_a_point_behind_the_camera_drops_its_drawing_only() {
            tape.view = fakeView
            tape.add(pick(0, 0))
            tape.add(pick(0, 10))
            tape.add(pick(8, 10))
            fakeView.horizon = 5           // everything past z = 5 is behind us
            compare(tape.plan.pts.filter(q => q.ok).length, 1, "one point left in front")
            compare(tape.plan.segs.filter(s => s.ok).length, 0, "so neither leg is drawn")
            verify(!tape.plan.verts[0].ok, "nor the corner")
            verify(!tape.plan.total.ok, "nor the total, which sits on a lost point")
            compare(tape.count, 3, "and the run itself is all still there")
            fuzzyCompare(tape.total, 18, 1e-6)
            fuzzyCompare(tape.angles[0], 90, 1e-6)
        }

        function test_the_corner_arc_spans_the_two_legs_on_screen() {
            tape.view = fakeView
            tape.add(pick(10, 0))     // due right of the corner
            tape.add(pick(0, 0))
            tape.add(pick(0, 10))     // due down from it
            const v = tape.plan.verts[0]
            fuzzyCompare(v.x, 0, 1e-6)
            fuzzyCompare(v.start, 0, 1e-6, "starts along the first leg")
            fuzzyCompare(v.sweep, Math.PI / 2, 1e-6, "and sweeps the quarter turn")
            compare(v.text, "90.0°")
        }
    }
}
