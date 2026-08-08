// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The rig's mutators, checked against a rig that EASES its moves.
//
// A Behavior defers the write: the property still reports the old value on the
// next line. Anything that wrote and then read back - `distance *= f; clamp()` -
// clamped against the stale value and silently cancelled its own move, which is
// how electronics-101 lost its zoom on desktop and in the browser alike.
//
// So every case here runs the same operation on two rigs, one eased and one
// not, and asserts they END UP IN THE SAME PLACE. That is the relationship;
// how long the eased one takes to get there is its own business.
//
// Since the exploration layer landed the easing is the rig's own (`smoothMs`),
// which is what lets the goal pose exist: mid-glide the pose properties hold an
// interpolant while goalYaw/goalPitch/goalDistance/goalPivot hold the move that
// was asked for. That distinction is what the second half of this suite is for
// - a rig read back mid-flight has to serialize its destination, or a reload
// taken while the camera was still moving lands somewhere nobody chose.
//
// `import ".."` picks up the plugin's QML sources directly, so the suite needs
// no compiled plugin and runs anywhere qmltestrunner does.

import QtQuick
import QtTest
import ".."

Item {
    width: 50; height: 50

    // The shape that broke: electronics-101's rig, easing its zoom.
    OrbitCamera3D {
        id: eased
        pitch: 48; distance: 80
        minPitch: 22; maxPitch: 84
        minDistance: 20; maxDistance: 170; minHeight: 9
        smoothMs: 40
    }

    // The same rig without the easing - the control every case is measured against.
    OrbitCamera3D {
        id: plain
        pitch: 48; distance: 80
        minPitch: 22; maxPitch: 84
        minDistance: 20; maxDistance: 170; minHeight: 9
        smoothMs: 0
    }

    // A rig that may not wander: the pan leash, on its own so the cases above
    // stay free to move.
    OrbitCamera3D {
        id: tethered
        pitch: 45; distance: 60
        minDistance: 5; maxDistance: 400; minHeight: 0
        smoothMs: 0
        homePivot: Qt.vector3d(0, 0, 0)
        panLeash: 100
        leashSoftness: 0.25
        viewpoints: ({
            "top": { pitch: 84, distance: 200 },
            "corner": { yaw: 45, pitch: 30, distance: 90, px: 10, py: 0, pz: 10 }
        })
    }

    TestCase {
        name: "OrbitCamera3D"
        when: windowShown

        // comfortably longer than the easing above, so a move has landed
        readonly property real settle: 160

        function reset() {
            for (const r of [eased, plain])
                r.applyState({ yaw: 0, pitch: 48, distance: 80, px: 0, py: 0, pz: 0 })
            wait(settle)
        }
        function near(a, b, eps) { return Math.abs(a - b) < (eps === undefined ? 1e-3 : eps) }

        // THE REGRESSION.
        function test_zoom_survives_the_easing() {
            reset()
            eased.zoomBy(0.7); plain.zoomBy(0.7)
            wait(settle)
            verify(near(plain.distance, 56), "control moved: " + plain.distance)
            verify(near(eased.distance, plain.distance),
                   "eased " + eased.distance + " vs plain " + plain.distance)
        }

        function test_limits_still_hold() {
            reset()
            eased.zoomBy(0.001); wait(settle)
            compare(eased.distance, 20, "zoom in stops at minDistance")
            eased.zoomBy(1000); wait(settle)
            compare(eased.distance, 170, "zoom out stops at maxDistance")
        }

        // The leash: flattening the angle backs the rig off rather than letting
        // it sink through the floor.
        function test_the_leash_holds_on_an_eased_rig() {
            reset()
            eased.setDistance(20); wait(settle)
            eased.orbitBy(0, -90); wait(settle)
            compare(eased.pitch, 22, "pitch clamps to minPitch")
            const h = eased.distance * Math.sin(eased.pitch * Math.PI / 180)
            verify(h >= 9 - 1e-3, "height above the pivot plane: " + h)
        }

        // frame() and applyState() write the distance too, so they take the
        // same path and would have been cancelled the same way.
        function test_frame_fits_an_eased_rig() {
            reset()
            const box = [Qt.vector3d(-30, 0, -30), Qt.vector3d(30, 0, 30)]
            eased.frame(box, 1.3); plain.frame(box, 1.3)
            wait(settle)
            verify(!near(plain.distance, 80), "control moved: " + plain.distance)
            verify(near(eased.distance, plain.distance),
                   "eased " + eased.distance + " vs plain " + plain.distance)
        }

        function test_applystate_restores_an_eased_rig() {
            reset()
            eased.applyState({ yaw: 10, pitch: 40, distance: 123, px: 0, py: 0, pz: 0 })
            wait(settle)
            verify(near(eased.distance, 123), "distance: " + eased.distance)
            compare(eased.pitch, 40)
        }

        // --- the goal pose --------------------------------------------------

        // What a reload taken mid-flight has to get back. state() reports the
        // destination while the pose properties are still on their way to it.
        function test_state_is_the_destination_not_the_interpolant() {
            reset()
            eased.applyState({ yaw: 90, pitch: 30, distance: 140, px: 20, py: 0, pz: -10 })
            const s = eased.state()          // read immediately: still gliding
            verify(eased.travelling, "the rig is still moving")
            verify(!near(eased.distance, 140), "and has not arrived: " + eased.distance)
            compare(s.yaw, 90, "state() reports the destination")
            compare(s.distance, 140)
            compare(s.px, 20)
            wait(settle)
            verify(near(eased.distance, 140), "which is where it ends up")
        }

        // Successive steps of one gesture must accumulate on the destination.
        // Adding to the interpolant instead is the drag that goes slower the
        // faster you move it, because every step throws away the pending part
        // of the last one.
        function test_a_burst_of_moves_accumulates_on_the_goal() {
            reset()
            for (let i = 0; i < 10; ++i) { eased.orbitBy(4, 0); plain.orbitBy(4, 0) }
            compare(eased.goalYaw, 40, "ten 4-degree steps are 40 degrees")
            wait(settle)
            verify(near(eased.yaw, plain.yaw), "and it gets there: " + eased.yaw)
        }

        // A pose written declaratively (an initial value, a lab moving its own
        // pivot) is adopted, so the next relative move does not spring back.
        function test_a_direct_write_becomes_the_goal() {
            reset()
            plain.yaw = 33
            compare(plain.goalYaw, 33, "the goal followed the write")
            plain.orbitBy(7, 0)
            compare(plain.goalYaw, 40, "and the next step counts from there")
        }

        // --- panning --------------------------------------------------------

        function test_pan_moves_along_the_ground_in_screen_directions() {
            tethered.homePivot = Qt.vector3d(0, 0, 0)
            tethered.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 3, pz: 0 })
            tethered.panBy(10, 0)
            verify(near(tethered.goalPivot.x, 10), "screen-right is +x at yaw 0")
            verify(near(tethered.goalPivot.z, 0), "and nothing else moved")
            verify(near(tethered.goalPivot.y, 3), "a pan never changes the height")
            tethered.panBy(-10, 10)
            verify(near(tethered.goalPivot.z, -10), "screen-up is -z at yaw 0")

            tethered.applyState({ yaw: 90, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            tethered.panBy(10, 0)
            verify(near(tethered.goalPivot.z, -10),
                   "turned a quarter, screen-right is -z: " + tethered.goalPivot.z)
        }

        // Soft, and therefore bounded: pushing far past the leash never gets
        // further than the leash plus its slack, and never stops dead either.
        function test_the_pan_leash_is_soft_and_bounded() {
            tethered.homePivot = Qt.vector3d(0, 0, 0)
            tethered.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            tethered.panBy(90, 0)
            verify(near(tethered.goalPivot.x, 90), "inside the leash nothing is compressed")

            tethered.panBy(40, 0)
            const r1 = tethered.goalPivot.x
            verify(r1 > 100, "past the leash it still moves: " + r1)
            verify(r1 < 125 + 1e-6, "but not past leash + slack: " + r1)

            for (let i = 0; i < 50; ++i) tethered.panBy(100, 0)
            verify(tethered.goalPivot.x <= 125 + 1e-6,
                   "and it can never escape: " + tethered.goalPivot.x)
            verify(tethered.goalPivot.x > r1, "though it did keep giving")
        }

        function test_leash_measures_from_home_in_the_ground_plane() {
            tethered.homePivot = Qt.vector3d(50, 0, 0)
            tethered.applyState({ yaw: 0, pitch: 45, distance: 60, px: 50, py: 0, pz: 0 })
            tethered.panBy(90, 0)
            verify(near(tethered.goalPivot.x, 140), "90 from home is inside the leash")
            tethered.homePivot = Qt.vector3d(0, 0, 0)
        }

        // --- viewpoints -----------------------------------------------------

        function test_goto_travels_to_a_named_pose() {
            tethered.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            verify(tethered.goTo("corner", 0), "the name resolves")
            compare(tethered.goalYaw, 45)
            compare(tethered.goalPitch, 30)
            verify(near(tethered.goalPivot.x, 10))
            verify(!tethered.goTo("nowhere", 0), "an unknown name is refused")
            compare(tethered.goalYaw, 45, "and changes nothing")
        }

        // A partial viewpoint is a legal "from wherever you are".
        function test_a_viewpoint_may_name_only_part_of_the_pose() {
            tethered.applyState({ yaw: 17, pitch: 45, distance: 60, px: 4, py: 0, pz: 6 })
            tethered.goTo("top", 0)
            compare(tethered.goalPitch, 84, "the pitch it named")
            compare(tethered.goalYaw, 17, "the yaw it did not")
            verify(near(tethered.goalPivot.x, 4), "and the pivot it did not")
        }

        // Turned three times over, a viewpoint at yaw 45 is 45 degrees away,
        // not 1125 - otherwise the camera unwinds the whole way round.
        function test_goto_takes_the_short_way_round() {
            tethered.applyState({ yaw: 720, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            tethered.goTo("corner", 0)
            compare(tethered.goalYaw, 765, "720 + 45, not back down to 45")
        }

        // --- focus ----------------------------------------------------------

        // A single point has no extent to fit, and framing it as if it did
        // dives the camera into the floor.
        function test_focus_on_a_point_recentres_without_diving() {
            tethered.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            tethered.focusOn(Qt.vector3d(20, 0, 30), 1.3, 0)
            verify(near(tethered.goalPivot.x, 20))
            verify(near(tethered.goalPivot.z, 30))
            compare(tethered.goalDistance, 60, "the distance is left alone")
        }

        function test_focus_on_a_set_frames_it() {
            tethered.applyState({ yaw: 0, pitch: 45, distance: 300, px: 0, py: 0, pz: 0 })
            tethered.focusOn([Qt.vector3d(-10, 0, -10), Qt.vector3d(10, 0, 10)], 1.2, 0)
            verify(tethered.goalDistance < 300, "it came in: " + tethered.goalDistance)
            verify(near(tethered.goalPivot.x, 0))
        }
    }
}
