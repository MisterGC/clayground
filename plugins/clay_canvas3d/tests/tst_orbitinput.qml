// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The gesture contract, in the one place it is decided: wants().
//
// There is one rule now and this suite exists to hold it: THE LEFT BUTTON IS
// NEVER THE CAMERA'S. It used to pan, and every mode this layer ever had
// existed to take it back for a scene that needed it. The modes are gone; what
// replaces them is that the answer for the left button is "" in every state
// this layer can be in, which is a thing a suite can actually check - and the
// labs cannot state it, they can only obey it.
//
// The two ways out of the rule are both explicit and both tested: a scene puts
// Qt.LeftButton in panButtons itself, or Space is held.
//
// The view is faked rather than built: a real View3D needs a GPU and a window,
// while all this layer asks of it is "what world point is under this pixel".
// The fake answers (x, 0, y), which makes every world assertion below readable
// by eye.
//
// `import ".."` picks up the plugin's QML sources directly, so the suite needs
// no compiled plugin and runs anywhere qmltestrunner does.

import QtQuick
import QtTest
import ".."

Item {
    width: 50; height: 50

    OrbitCamera3D {
        id: rig
        yaw: 0; pitch: 45; distance: 100
        minDistance: 10; maxDistance: 400; minHeight: 0
        smoothMs: 0
    }

    // Pixel (x, y) is world (x, 0, y): the ray goes straight down through it.
    QtObject {
        id: fakeView
        property var camera: ({ real: false })
        property real height: 600
        function mapTo3DScene(v) {
            return Qt.vector3d(v.x, v.z === 1 ? 100 : -100, v.y)
        }
    }

    OrbitInput3D {
        id: nav
        rig: rig
        view: fakeView
    }

    SignalSpy {
        id: cancels
        target: nav
        signalName: "cancelled"
    }

    TestCase {
        name: "OrbitInput3D"
        when: windowShown

        function init() {
            nav.springNav = false
            nav.panButtons = Qt.MiddleButton
            nav.panModifiers = Qt.NoModifier
            nav.cancel()
            nav.clearHover()
            cancels.clear()
            rig.applyState({ yaw: 0, pitch: 45, distance: 100, px: 0, py: 0, pz: 0 })
        }

        function near(a, b, eps) { return Math.abs(a - b) < (eps === undefined ? 1e-3 : eps) }
        function copyOf(v) { return Qt.vector3d(v.x, v.y, v.z) }
        function apart(a, b) { return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z) }

        // --- the rule ---------------------------------------------------------

        function test_the_left_button_is_never_the_cameras() {
            compare(nav.wants(Qt.LeftButton, 0), "", "idle")
            compare(nav.wants(Qt.LeftButton, Qt.ShiftModifier), "",
                    "no leftovers, not even under a modifier")
            compare(nav.wants(Qt.LeftButton, Qt.ControlModifier | Qt.AltModifier), "",
                    "nor under two")
        }

        // The state the modes used to hide in was "something is in the hand",
        // and it is the state this layer no longer has: there is nothing to
        // set, so there is nothing that could make the answer differ.
        function test_no_state_here_can_take_the_left_button() {
            const idle = nav.wants(Qt.LeftButton, 0)
            nav.hoverAt(20, 20)
            compare(nav.wants(Qt.LeftButton, 0), idle, "a hover changes nothing")
            nav.begin(10, 10, Qt.RightButton, 0)
            compare(nav.wants(Qt.LeftButton, 0), idle, "nor does a running orbit")
            nav.cancel()
            nav.begin(10, 10, Qt.MiddleButton, 0)
            compare(nav.wants(Qt.LeftButton, 0), idle, "nor a running pan")
            nav.cancel()
        }

        function test_the_right_button_turns_and_the_middle_one_pans() {
            compare(nav.wants(Qt.RightButton, 0), "orbit")
            compare(nav.wants(Qt.MiddleButton, 0), "pan")
        }

        // The first of the two explicit ways out: a scene with nothing to
        // select spends the left button on the view, in its own declaration.
        function test_a_scene_may_buy_the_left_button_back() {
            nav.panButtons = Qt.LeftButton | Qt.MiddleButton
            compare(nav.wants(Qt.LeftButton, 0), "pan", "because the scene asked")
            compare(nav.wants(Qt.RightButton, 0), "orbit", "and the rest is unchanged")
        }

        // The second: held, not switched, and it leaves nothing behind.
        function test_space_pans_on_the_left_button_while_it_is_held() {
            compare(nav.wants(Qt.LeftButton, 0), "")
            nav.springNav = true
            compare(nav.wants(Qt.LeftButton, 0), "pan", "while held")
            compare(nav.wants(Qt.RightButton, 0), "orbit", "the right button is unaffected")
            nav.springNav = false
            compare(nav.wants(Qt.LeftButton, 0), "", "and back afterwards")
        }

        function test_a_spring_held_left_drag_actually_pans() {
            nav.springNav = true
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "pan")
            nav.move(60, 40)
            nav.cancel()
            verify(rig.goalPivot.x > before.x + 1,
                   "dragging left carries the ground with it: " + rig.goalPivot.x)
        }

        // A modifier a scene declared is still a pan - the escape hatch is
        // opt-in, and it is checked before the buttons so it works on any.
        function test_a_declared_modifier_pans_on_any_button() {
            nav.panModifiers = Qt.ShiftModifier
            compare(nav.wants(Qt.LeftButton, Qt.ShiftModifier), "pan")
            compare(nav.wants(Qt.RightButton, Qt.ShiftModifier), "pan",
                    "it outranks the orbit, which is what an escape hatch is for")
            compare(nav.wants(Qt.LeftButton, 0), "", "and only under the modifier")
        }

        // --- what a drag then does -------------------------------------------

        function test_a_left_drag_moves_nothing() {
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "", "declined")
            compare(nav.move(200, 90), false, "and the move is the scene's too")
            verify(apart(before, rig.goalPivot) < 1e-6, "the camera did not stir")
        }

        function test_the_middle_button_pans() {
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.MiddleButton, 0), "pan")
            verify(nav.move(200, 40), "the drag is the camera's")
            nav.cancel()
            verify(apart(before, rig.goalPivot) > 1, "and the world moved with it")
        }

        // The vertical half of grab-the-world: dy grows DOWNWARD, so the
        // screen-opposite move is +dy on the away axis, not -dy. This is the
        // sign that shipped wrong once - the ground followed the hand
        // left-right yet fought it up-down.
        function test_a_down_drag_pulls_the_ground_down() {
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.MiddleButton, 0), "pan")
            nav.move(120, 140)
            nav.cancel()
            verify(rig.goalPivot.z < before.z - 1,
                   "dragging down walks the pivot away: " + rig.goalPivot.z)
        }

        // The input layer is what takes the grip, for exactly the length of the
        // gesture: the rig itself has no idea whether a hand is on it.
        function test_a_drag_grips_the_rig_and_lets_go_after() {
            verify(!rig.gripped, "idle")
            nav.begin(120, 40, Qt.MiddleButton, 0)
            verify(rig.gripped, "a drag holds it")
            nav.move(100, 40)
            verify(rig.gripped, "still")
            nav.cancel()
            verify(!rig.gripped, "and lets go")
        }

        function test_a_declined_press_does_not_grip() {
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "", "the scene's press")
            verify(!rig.gripped, "so the rig was never taken")
        }

        // The cursor has almost nothing left to say, which is the point: with
        // no modes there is no camera state for it to announce.
        function test_the_cursor_only_reports_a_running_drag() {
            compare(nav.cursorShape, Qt.ArrowCursor, "idle")
            nav.begin(10, 10, Qt.RightButton, 0)
            compare(nav.cursorShape, Qt.ClosedHandCursor, "dragging")
            nav.cancel()
            compare(nav.cursorShape, Qt.ArrowCursor)
        }

        // --- the right click --------------------------------------------------
        //
        // One button, two meanings, and only the distance travelled tells them
        // apart - the same click-versus-drag rule the scenes apply to theirs.

        function test_a_right_click_cancels() {
            const before = copyOf(rig.goalPosition)
            compare(nav.begin(60, -40, Qt.RightButton, 0), "orbit",
                    "the press is taken as an orbit - a click is not knowable yet")
            nav.end()
            compare(cancels.count, 1, "and comes out as a cancel")
            verify(apart(before, rig.goalPosition) < 1e-3,
                   "with the camera where it was: " + apart(before, rig.goalPosition))
        }

        function test_a_trembling_right_click_still_cancels() {
            nav.begin(60, -40, Qt.RightButton, 0)
            nav.move(62, -39)
            nav.end()
            compare(cancels.count, 1, "a hand that trembles is not a drag")
        }

        function test_a_right_drag_orbits_and_cancels_nothing() {
            compare(nav.begin(60, -40, Qt.RightButton, 0), "orbit")
            nav.move(90, -40)
            nav.end()
            compare(cancels.count, 0, "a drag is not a click")
            verify(!near(rig.goalYaw, 0), "and it turned: " + rig.goalYaw)
        }

        function test_the_other_buttons_never_cancel() {
            nav.begin(60, -40, Qt.MiddleButton, 0)
            nav.end()
            compare(cancels.count, 0, "the middle button pans, and says nothing")
            nav.begin(60, -40, Qt.LeftButton, 0)
            nav.end()
            compare(cancels.count, 0, "and the left one is not this layer's at all")
        }

        // --- what is under the cursor -----------------------------------------

        function test_a_pick_carries_a_place_and_a_thing() {
            const p = nav.pickAt(60, -40)
            verify(near(p.point.x, 60) && near(p.point.z, -40), "where: " + p.point)
            compare(p.object, null, "with nothing under it in a fake view")
            compare(p.x, 60, "and the pixel it was asked about")
        }

        function test_hovering_follows_the_cursor() {
            compare(nav.hovering, null, "nothing has been asked yet")
            nav.hoverAt(60, -40)
            verify(near(nav.hovering.point.x, 60), "it landed: " + nav.hovering.point)
            nav.hoverAt(10, 20)
            verify(near(nav.hovering.point.x, 10), "and it moves with the cursor")
            nav.clearHover()
            compare(nav.hovering, null, "and the scene can drop it")
        }

        // Mid-drag the cursor is driving the camera rather than pointing at
        // anything: a preview that chased it would run across the whole scene.
        function test_a_running_gesture_suppresses_the_hover() {
            nav.hoverAt(60, -40)
            const held = nav.hovering
            nav.begin(10, 10, Qt.MiddleButton, 0)
            nav.hoverAt(200, 200)
            compare(nav.hovering, held, "the hover stayed where the drag began")
            nav.cancel()
            nav.hoverAt(200, 200)
            verify(near(nav.hovering.point.x, 200), "and follows again once it ends")
        }

        function test_a_hover_with_no_view_is_nothing_rather_than_a_crash() {
            nav.view = null
            nav.hoverAt(60, -40)
            compare(nav.hovering, null, "no ray, no answer")
            compare(nav.pickAt(60, -40), null)
            nav.view = fakeView
        }

        // --- the anchored orbit ----------------------------------------------

        // Press over a point and the rig re-anchors there WITHOUT the picture
        // changing - the property the whole gesture stands on.
        function test_a_right_drag_anchors_at_the_cursor_without_a_jump() {
            const before = copyOf(rig.goalPosition)
            const d0 = Math.hypot(60 - before.x, 0 - before.y, -40 - before.z)
            compare(nav.begin(60, -40, Qt.RightButton, 0), "orbit")
            verify(nav.anchor !== null, "the press took an anchor")
            verify(apart(before, rig.goalPosition) < 1e-3,
                   "the camera stayed put: " + apart(before, rig.goalPosition))
            // the pivot lands at the picked point's DEPTH: the offset from it
            // to the point is square across the view, so a turn from here
            // circles what the cursor was on
            const pv = copyOf(rig.goalPivot)
            const dir = Qt.vector3d(rig.goalPosition.x - pv.x,
                                    rig.goalPosition.y - pv.y,
                                    rig.goalPosition.z - pv.z).normalized()
            const off = Qt.vector3d(60 - pv.x, 0 - pv.y, -40 - pv.z)
            verify(near(off.dotProduct(dir), 0, 1e-3),
                   "square across the view: " + off.dotProduct(dir))
            verify(apart(pv, Qt.vector3d(0, 0, 0)) > 1, "and it did move: " + pv)
            nav.move(90, -40)
            verify(!near(rig.goalYaw, 0), "then the drag turned it: " + rig.goalYaw)
            // and the point pressed on is still where it was, in camera terms:
            // the whole rig turned about it
            const c = copyOf(rig.goalPosition)
            verify(near(Math.hypot(60 - c.x, 0 - c.y, -40 - c.z), d0, 1e-2),
                   "the anchor kept its distance from the camera")
            nav.cancel()
            verify(nav.anchor === null, "and the anchor is dropped with the drag")
        }

        function test_anchoring_can_be_switched_off() {
            nav.anchorOrbit = false
            const pivot = copyOf(rig.goalPivot)
            nav.begin(60, -40, Qt.RightButton, 0)
            nav.cancel()
            verify(apart(pivot, rig.goalPivot) < 1e-6, "the pivot stayed home")
            nav.anchorOrbit = true
        }

        // --- the wheel -------------------------------------------------------

        function test_the_wheel_zooms_towards_the_cursor() {
            nav.wheel(120, 80, 60)
            verify(rig.goalDistance < 100, "it came in")
            verify(rig.goalPivot.x > 1 && rig.goalPivot.z > 1,
                   "and towards the corner, not the middle: " + rig.goalPivot)
        }

        function test_the_wheel_without_a_position_zooms_at_the_pivot() {
            nav.wheel(120)
            verify(rig.goalDistance < 100, "it came in")
            verify(near(rig.goalPivot.x, 0) && near(rig.goalPivot.z, 0),
                   "and nothing travelled")
        }

        function test_the_wheel_backs_out_away_from_the_cursor() {
            nav.wheel(-120, 80, 60)
            verify(rig.goalDistance > 100, "it backed off")
            verify(rig.goalPivot.x < -1, "away from the point: " + rig.goalPivot)
        }

        // --- double-click focus -----------------------------------------------

        function test_double_click_focuses_where_it_landed() {
            verify(nav.recenterAt(35, -25), "it focused")
            verify(near(rig.goalPivot.x, 35) && near(rig.goalPivot.z, -25),
                   "on the point clicked: " + rig.goalPivot)
        }

        // A scene with no view can still be driven; it simply loses the two
        // gestures that need a world point, rather than throwing.
        function test_no_view_costs_the_anchor_but_nothing_else() {
            nav.view = null
            compare(nav.begin(60, -40, Qt.RightButton, 0), "orbit")
            nav.move(90, -40)
            nav.cancel()
            verify(!near(rig.goalYaw, 0), "the orbit still ran")
            nav.wheel(120, 80, 60)
            verify(rig.goalDistance < 100, "and the wheel fell back to a plain zoom")
            verify(near(rig.goalPivot.x, 0), "with no travel")
            nav.view = fakeView
        }
    }
}
