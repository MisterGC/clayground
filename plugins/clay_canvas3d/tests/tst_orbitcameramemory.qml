// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The rig's two memories: the jumplist and the sticky return frame.
//
// Both exist because an endless ground has nothing to navigate back by, and
// both are only worth anything if they distinguish a JUMP from TRAVEL. That
// distinction is what most of this suite is about: a jumplist that recorded
// every drag would have nothing recognisable left in it, and a return pose
// that survived a reset would fly the viewer to a place that no longer exists.
//
// The poses are goal poses, so one case here takes a jump mid-glide - the same
// doctrine tst_orbitcamera.qml checks for state(), stated again where it is
// easiest to lose it.
//
// `import ".."` picks up the plugin's QML sources directly, so the suite needs
// no compiled plugin and runs anywhere qmltestrunner does.

import QtQuick
import QtTest
import ".."

Item {
    width: 50; height: 50

    // Deliberately roomy limits: a pose that gets clamped on the way back is a
    // failure of the limits, not of the memory, and would only obscure both.
    OrbitCamera3D {
        id: rig
        yaw: 0; pitch: 45; distance: 60
        minPitch: 5; maxPitch: 85
        minDistance: 2; maxDistance: 1000; minHeight: 0
        smoothMs: 0
        viewpoints: ({ "top": { pitch: 84, distance: 200 },
                       "corner": { yaw: 45, pitch: 30, distance: 90 } })
    }

    // The same rig, easing - for the one case that has to be taken mid-flight.
    OrbitCamera3D {
        id: eased
        yaw: 0; pitch: 45; distance: 60
        minPitch: 5; maxPitch: 85
        minDistance: 2; maxDistance: 1000; minHeight: 0
        smoothMs: 40; travelMs: 40
    }

    TestCase {
        name: "OrbitCamera3DMemory"
        when: windowShown

        readonly property real settle: 160

        readonly property var boxA: [Qt.vector3d(-10, 0, -10), Qt.vector3d(10, 0, 10)]
        readonly property var boxB: [Qt.vector3d(90, 0, 90), Qt.vector3d(110, 0, 110)]

        // Walking the list cannot empty it - back and forward only move an entry
        // from one side to the other - which is exactly why clearJumps() exists.
        function reset() {
            rig.clearJumps()
            rig.clearReturn()
            rig.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            compare(rig.jumpsBack, 0, "the list starts empty")
            compare(rig.jumpsAhead, 0)
        }

        function same(a, b) {
            return Math.abs(a.yaw - b.yaw) < 1e-3 && Math.abs(a.pitch - b.pitch) < 1e-3
                   && Math.abs(a.distance - b.distance) < 1e-3
                   && Math.abs(a.px - b.px) < 1e-3 && Math.abs(a.py - b.py) < 1e-3
                   && Math.abs(a.pz - b.pz) < 1e-3
        }

        // --- what does NOT push ------------------------------------------------
        //
        // THE RULE. Everything else in the jumplist follows from it.
        function test_travel_leaves_no_trace() {
            reset()
            rig.panBy(20, -15)
            rig.orbitBy(30, -5)
            rig.zoomBy(0.8)
            rig.setDistance(70)
            rig.setPivot(Qt.vector3d(5, 0, 5))
            rig.reanchor(Qt.vector3d(30, 0, 30))
            rig.orbitAround(Qt.vector3d(30, 0, 30), 20, 5)
            rig.zoomToward(Qt.vector3d(30, 0, 30), 0.9)
            compare(rig.jumpsBack, 0, "travel is not a jump")
            verify(!rig.jumpBack(), "and there is nothing to go back to")
        }

        // A jump that did not happen must not be recorded either, or the first
        // Ctrl+O after a typo goes somewhere nobody asked for.
        function test_a_refused_jump_records_nothing() {
            reset()
            verify(!rig.goTo("nowhere"), "no such viewpoint")
            rig.focusOn(null)
            rig.focusOn([])
            compare(rig.jumpsBack, 0)
        }

        // --- the walk ----------------------------------------------------------

        function test_focus_pushes_and_back_restores_it_exactly() {
            reset()
            rig.orbitBy(35, -10)                 // somewhere characteristic
            const before = rig.state()
            rig.focusOn(Qt.vector3d(120, 0, -40))
            compare(rig.jumpsBack, 1)
            verify(!same(rig.state(), before), "the focus moved the rig")
            verify(rig.jumpBack(), "there was somewhere to go")
            verify(same(rig.state(), before),
                   "back to " + JSON.stringify(before) + " got " + JSON.stringify(rig.state()))
            verify(!rig.jumpBack(), "and the end of the list refuses")
        }

        function test_goto_pushes() {
            reset()
            const before = rig.state()
            verify(rig.goTo("top"))
            compare(rig.jumpsBack, 1)
            verify(rig.goTo("corner"))
            compare(rig.jumpsBack, 2)
            verify(rig.jumpBack())
            verify(Math.abs(rig.goalPitch - 84) < 1e-3, "back at top: " + rig.goalPitch)
            verify(rig.jumpBack())
            verify(same(rig.state(), before), "and back where it started")
        }

        function test_forward_walks_the_list_back_up() {
            reset()
            const p0 = rig.state()
            rig.goTo("top"); const p1 = rig.state()
            rig.goTo("corner"); const p2 = rig.state()
            verify(rig.jumpBack()); verify(same(rig.state(), p1), "one back")
            verify(rig.jumpBack()); verify(same(rig.state(), p0), "two back")
            compare(rig.jumpsAhead, 2)
            verify(rig.jumpForward()); verify(same(rig.state(), p1), "one forward")
            verify(rig.jumpForward()); verify(same(rig.state(), p2), "two forward")
            verify(!rig.jumpForward(), "the top of the list refuses")
        }

        function test_a_new_jump_drops_what_was_ahead() {
            reset()
            rig.goTo("top")
            rig.goTo("corner")
            verify(rig.jumpBack())
            compare(rig.jumpsAhead, 1, "there is a way forward...")
            rig.focusOn(Qt.vector3d(200, 0, 200))
            compare(rig.jumpsAhead, 0, "...until a new jump replaces it")
            verify(!rig.jumpForward())
        }

        // The place you are standing on is not a place you left.
        function test_jumping_to_where_you_already_are_does_not_stack_up() {
            reset()
            rig.goTo("top")
            compare(rig.jumpsBack, 1)
            rig.goTo("top")
            compare(rig.jumpsBack, 1, "the second press added nothing")
        }

        function test_the_list_is_bounded() {
            reset()
            for (var i = 0; i < rig.jumpDepth + 20; ++i)
                rig.focusOn(Qt.vector3d(i * 7 + 3, 0, i * 3 + 1))
            compare(rig.jumpsBack, rig.jumpDepth, "the depth holds")
            var guard = 0
            while (rig.jumpBack()) if (++guard > rig.jumpDepth + 5) break
            compare(guard, rig.jumpDepth, "and the walk is exactly that long")
        }

        // External code jumps too - a hint label selected and flown to, a flow
        // step aiming the camera, a lab's reset key.
        function test_push_jump_is_available_to_the_scene() {
            reset()
            const before = rig.state()
            rig.pushJump()
            rig.frame(boxB, 1.3)              // a plain frame does not push...
            compare(rig.jumpsBack, 1, "...so the one push is the caller's")
            verify(rig.jumpBack())
            verify(same(rig.state(), before))
        }

        // The doctrine, where it is easiest to lose: a jump taken while the rig
        // is still gliding must record where it was HEADED.
        function test_a_jump_mid_glide_records_the_destination() {
            eased.clearJumps()
            eased.clearReturn()
            eased.applyState({ yaw: 0, pitch: 45, distance: 60, px: 0, py: 0, pz: 0 })
            wait(settle)
            eased.orbitBy(60, -20)
            const goal = eased.state()
            verify(eased.travelling, "still on its way")
            verify(Math.abs(eased.yaw - goal.yaw) > 1e-3, "and not there yet: " + eased.yaw)
            eased.focusOn(Qt.vector3d(150, 0, 0))
            wait(settle)
            verify(eased.jumpBack())
            wait(settle)
            verify(same(eased.state(), goal),
                   "recorded the goal " + JSON.stringify(goal) + " got " + JSON.stringify(eased.state()))
        }

        // --- the sticky return frame -------------------------------------------

        function test_framing_the_same_thing_twice_is_a_round_trip() {
            reset()
            rig.orbitBy(25, -8)
            const overview = rig.state()
            verify(rig.frameWithReturn(boxA, 1.3))
            verify(rig.hasReturnPose, "the way home is remembered")
            verify(!same(rig.state(), overview), "and the rig dived")
            rig.orbitBy(15, 3)                 // look around down there
            rig.zoomBy(0.9)
            verify(rig.frameWithReturn(boxA, 1.3))
            verify(same(rig.state(), overview),
                   "home is exact: " + JSON.stringify(rig.state()))
            verify(!rig.hasReturnPose, "and forgotten afterwards")
        }

        // The loop closes where it began, however far the excursion wandered.
        function test_reframing_onto_something_else_keeps_the_original_way_home() {
            reset()
            const overview = rig.state()
            verify(rig.frameWithReturn(boxA, 1.3))
            const atA = rig.state()
            verify(rig.frameWithReturn(boxB, 1.3))
            verify(!same(rig.state(), atA), "it did reframe")
            verify(rig.hasReturnPose, "and kept a way home")
            verify(rig.frameWithReturn(boxB, 1.3))
            verify(same(rig.state(), overview),
                   "which is still the original overview, not " + JSON.stringify(atA))
        }

        // Esc clears the selection, F still comes home - a dive one cannot leave
        // is a trap.
        function test_with_nothing_selected_it_comes_home() {
            reset()
            const overview = rig.state()
            verify(rig.frameWithReturn(boxA, 1.3))
            verify(rig.frameWithReturn([], 1.3))
            verify(same(rig.state(), overview))
            verify(!rig.frameWithReturn([], 1.3), "and then there is nothing to do")
        }

        function test_a_reset_ends_the_excursion() {
            reset()
            verify(rig.frameWithReturn(boxA, 1.3))
            rig.frame(boxB, 1.3)                       // the lab's frame-all
            verify(!rig.hasReturnPose, "a reset is a departure")
        }

        function test_a_jump_ends_the_excursion() {
            reset()
            verify(rig.frameWithReturn(boxA, 1.3))
            rig.goTo("top")
            verify(!rig.hasReturnPose, "a named place is a departure")
            verify(rig.frameWithReturn(boxA, 1.3))
            verify(rig.jumpBack())
            verify(!rig.hasReturnPose, "and so is walking the jumplist")
        }

        // The dive is itself a jump, so the two memories compose rather than
        // fight: Ctrl+O after coming home dives back in.
        function test_the_dive_and_the_way_home_are_both_on_the_jumplist() {
            reset()
            const overview = rig.state()
            verify(rig.frameWithReturn(boxA, 1.3))
            const atA = rig.state()
            verify(rig.frameWithReturn(boxA, 1.3))
            verify(same(rig.state(), overview), "home")
            verify(rig.jumpBack())
            verify(same(rig.state(), atA), "and back down to the close-up")
        }
    }
}
