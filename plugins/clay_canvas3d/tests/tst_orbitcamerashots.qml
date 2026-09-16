// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The rig as a camera operator: fit() composes a shot in screen space, and
// follow keeps a moving subject in the picture without cutting.
//
// frame() fits a sphere against the vertical field, which is safe and often
// loose; what a shot needs is every point INSIDE the picture with a margin,
// and the picture is not the whole window. Every case here reads the result
// back through project() - the rig's own projection, so the suite needs no
// View3D and no GPU - and asserts on where the points landed, not on where
// the camera went.
//
// `import ".."` picks up the plugin's QML sources directly, so the suite needs
// no compiled plugin and runs anywhere qmltestrunner does.

import QtQuick
import QtTest
import ".."

Item {
    width: 50; height: 50

    // Snaps, so a fit can be read back on the next line.
    OrbitCamera3D {
        id: rig
        pitch: 48; distance: 80
        minPitch: 22; maxPitch: 84
        minDistance: 5; maxDistance: 400; minHeight: 0
        smoothMs: 0
        followMs: 0
    }

    // The subject a follow keeps in frame. Moved by the tests.
    QtObject {
        id: probe
        property vector3d at: Qt.vector3d(0, 0, 0)
    }

    TestCase {
        name: "OrbitCamera3D shots"
        when: windowShown

        // A presenter beside a part: flat, wide, and taller on one side -
        // exactly the set a bounding sphere fits badly.
        readonly property var twoShot: [
            Qt.vector3d(-5, 0, -5), Qt.vector3d(5, 12, 5),
            Qt.vector3d(20, 0, 8), Qt.vector3d(26, 3, 14)
        ]

        function reset() {
            rig.follow = null
            rig.applyState({ yaw: 0, pitch: 48, distance: 80, px: 0, py: 0, pz: 0 })
        }
        function near(a, b, eps) { return Math.abs(a - b) < (eps === undefined ? 1e-3 : eps) }
        function extent(pts, goal) {
            let m = 0
            for (const p of pts) {
                const n = rig.project(p, goal)
                verify(n.depth > 0, "in front of the lens: " + JSON.stringify(n))
                m = Math.max(m, Math.abs(n.x), Math.abs(n.y))
            }
            return m
        }

        // --- project ---------------------------------------------------------

        function test_project_sees_what_the_camera_sees() {
            reset()
            // the pivot is on the axis, so it is the middle of the picture
            const c = rig.project(Qt.vector3d(0, 0, 0))
            verify(near(c.x, 0) && near(c.y, 0), "pivot at the centre: " + JSON.stringify(c))
            verify(near(c.depth, 80), "at the rig's distance: " + c.depth)
            // yaw 0 looks down -z, so +x is screen right and +y is up
            verify(rig.project(Qt.vector3d(10, 0, 0)).x > 0, "+x is right")
            verify(rig.project(Qt.vector3d(0, 10, 0)).y > 0, "+y is up")
            // a point nearer the camera than the pivot is lower on screen at
            // this pitch (the camera looks down at it)
            verify(rig.project(Qt.vector3d(0, 0, 20)).y < 0, "towards the camera is down")
            // behind the lens reports no depth, not a wild coordinate
            const behind = rig.project(Qt.vector3d(0, 200, 200))
            verify(behind.depth <= 0, "behind: " + JSON.stringify(behind))
        }

        // --- fit ------------------------------------------------------------

        function test_fit_puts_every_point_inside_and_as_close_as_that_allows() {
            reset()
            verify(rig.fit(twoShot, { pad: 1 }), "fit accepted the points")
            const m = extent(twoShot, true)
            verify(m <= 1 + 1e-4, "everything inside the picture: " + m)
            // tight: with no pad something is ON the edge, or the fit was loose
            verify(m > 0.98, "and something touches an edge: " + m)
        }

        function test_fit_pad_backs_off_by_that_factor() {
            reset()
            rig.fit(twoShot, { pad: 1 })
            const tight = rig.goalDistance
            rig.fit(twoShot, { pad: 1.3 })
            verify(near(rig.goalDistance, tight * 1.3, 1e-3),
                   "pad 1.3: " + rig.goalDistance + " vs " + tight * 1.3)
            verify(extent(twoShot, true) < 0.85, "padded shots have air around them")
        }

        function test_fit_keeps_the_points_out_of_the_chrome() {
            reset()
            // a bar along the bottom third: nothing may land there
            rig.fit(twoShot, { pad: 1, safe: { bottom: 0.3 } })
            let lowest = 1
            for (const p of twoShot) lowest = Math.min(lowest, rig.project(p, true).y)
            verify(lowest >= -0.4 - 1e-3, "nothing below the bar: " + lowest)
            verify(extent(twoShot, true) <= 1 + 1e-4, "and still all inside")
        }

        function test_fit_takes_the_angles_it_is_given() {
            reset()
            rig.fit(twoShot, { yaw: 30, pitch: 10 })
            compare(rig.goalYaw, 30)
            compare(rig.goalPitch, 22, "pitch is still clamped to minPitch")
            verify(extent(twoShot, true) <= 1 + 1e-4, "inside at the new angle too")
        }

        function test_fit_stops_at_max_distance() {
            reset()
            rig.fit([Qt.vector3d(-2000, 0, 0), Qt.vector3d(2000, 0, 0)])
            compare(rig.goalDistance, 400, "as far as it may, no further")
        }

        function test_fit_is_one_move_on_an_eased_rig() {
            reset()
            rig.smoothMs = 40
            rig.fit(twoShot, { pad: 1 })
            const goal = rig.state()
            verify(rig.travelling, "gliding")
            wait(160)
            verify(near(rig.distance, goal.distance, 1e-3), "arrived where it was headed")
            verify(near(rig.pivot.x, goal.px, 1e-3))
            rig.smoothMs = 0
        }

        // --- covers ---------------------------------------------------------

        function test_covers_asks_the_only_question_that_matters() {
            reset()
            rig.fit(twoShot, { pad: 1.2 })
            verify(rig.covers(twoShot, 0, true), "the fitted set is covered")
            verify(rig.covers(twoShot[0], 0.05, true), "a single point works too")
            verify(!rig.covers(twoShot, 0.4, true), "not with a margin the pad did not leave")
            verify(!rig.covers([Qt.vector3d(500, 0, 0)], 0, true), "not something far off to the side")
            verify(!rig.covers([], 0, true), "nothing is not covered")
        }

        // --- follow ---------------------------------------------------------

        function test_follow_holds_still_while_the_subject_is_inside() {
            reset()
            probe.at = Qt.vector3d(0, 0, 0)
            rig.follow = () => probe.at
            wait(120)
            compare(rig.goalPivot.x, 0, "a subject in the middle moves nothing")
            compare(rig.goalPivot.z, 0)
            rig.follow = null
        }

        function test_follow_pans_the_subject_back_to_the_edge_of_the_zone() {
            reset()
            rig.followSlack = 0.25
            rig.follow = () => probe.at
            // well outside the inner zone, to the right
            probe.at = Qt.vector3d(70, 0, 0)
            verify(rig.project(probe.at, true).x > 0.75, "starts outside the zone")
            wait(120)
            const n = rig.project(probe.at, true)
            verify(near(n.x, 0.75, 0.03), "panned exactly to the zone's edge: " + n.x)
            verify(rig.goalPivot.x > 0, "by moving the pivot towards it: " + rig.goalPivot.x)
            compare(rig.goalDistance, 80, "and never by zooming")
            // now towards the camera, which is down the picture: the pivot
            // comes towards the camera too, on the ground
            probe.at = Qt.vector3d(rig.goalPivot.x, 0, 60)
            wait(120)
            const m = rig.project(probe.at, true)
            verify(near(m.y, -0.75, 0.05), "and the same for the bottom edge: " + m.y)
            verify(rig.goalPivot.z > 0, "pivot moved towards the camera: " + rig.goalPivot.z)
            compare(rig.goalPivot.y, 0, "still on the ground")
            rig.follow = null
        }

        function test_follow_takes_an_array_and_switches_off_cleanly() {
            reset()
            rig.follow = () => [Qt.vector3d(0, 0, 0), Qt.vector3d(-70, 0, 0)]
            wait(120)
            verify(rig.goalPivot.x < 0, "the point off to the left pulled the frame")
            const x = rig.goalPivot.x
            rig.follow = null
            wait(80)
            compare(rig.goalPivot.x, x, "off means off")
        }
    }
}
