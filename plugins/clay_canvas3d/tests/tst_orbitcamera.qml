// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The rig's mutators, checked against a rig that EASES its distance.
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
        Behavior on distance { NumberAnimation { duration: 40 } }
    }

    // The same rig without the easing - the control every case is measured against.
    OrbitCamera3D {
        id: plain
        pitch: 48; distance: 80
        minPitch: 22; maxPitch: 84
        minDistance: 20; maxDistance: 170; minHeight: 9
    }

    TestCase {
        name: "OrbitCamera3D"
        when: windowShown

        // comfortably longer than the Behavior above, so a move has landed
        readonly property real settle: 120

        function reset() {
            for (const r of [eased, plain])
                r.applyState({ yaw: 0, pitch: 48, distance: 80, px: 0, py: 0, pz: 0 })
            wait(settle)
        }
        function near(a, b) { return Math.abs(a - b) < 1e-3 }

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
    }
}
