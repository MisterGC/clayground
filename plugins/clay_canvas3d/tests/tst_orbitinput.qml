// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The gesture contract, in the one place it is decided: wants().
//
// Every lab forwards its presses through it, so "in build mode the left button
// is the domain's" is true exactly as long as this suite is green - the labs
// themselves cannot state it, they can only obey it.
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
        id: picks
        target: nav
        signalName: "pickedAt"
    }

    TestCase {
        name: "OrbitInput3D"
        when: windowShown

        function init() {
            nav.modes = ["build", "explore", "measure"]
            nav.mode = "build"
            nav.springExplore = false
            nav.modeLocked = false
            nav.cancel()
            picks.clear()
            rig.applyState({ yaw: 0, pitch: 45, distance: 100, px: 0, py: 0, pz: 0 })
        }

        function near(a, b, eps) { return Math.abs(a - b) < (eps === undefined ? 1e-3 : eps) }
        function copyOf(v) { return Qt.vector3d(v.x, v.y, v.z) }
        function apart(a, b) { return Math.hypot(a.x - b.x, a.y - b.y, a.z - b.z) }

        // --- the contract ----------------------------------------------------

        function test_build_mode_leaves_the_two_buttons_to_the_scene() {
            compare(nav.wants(Qt.LeftButton, 0), "", "the left button is the tool's")
            compare(nav.wants(Qt.RightButton, 0), "", "and so is the right one")
            compare(nav.wants(Qt.LeftButton, Qt.ShiftModifier), "",
                    "no leftovers, not even under a modifier")
        }

        function test_the_middle_button_pans_in_both_modes() {
            compare(nav.wants(Qt.MiddleButton, 0), "pan", "build")
            nav.mode = "explore"
            compare(nav.wants(Qt.MiddleButton, 0), "pan", "explore")
        }

        function test_explore_mode_takes_the_whole_pointer() {
            nav.mode = "explore"
            compare(nav.wants(Qt.LeftButton, 0), "pan", "left drags the world along")
            compare(nav.wants(Qt.RightButton, 0), "orbit", "right turns it")
        }

        // The quasimode: held, not switched - and it must not leave the sticky
        // mode changed behind it.
        function test_the_spring_explores_only_while_it_is_held() {
            compare(nav.wants(Qt.LeftButton, 0), "")
            nav.springExplore = true
            compare(nav.effectiveMode, "explore")
            compare(nav.wants(Qt.LeftButton, 0), "pan", "while held")
            nav.springExplore = false
            compare(nav.wants(Qt.LeftButton, 0), "", "and back afterwards")
            compare(nav.mode, "build", "the sticky mode never moved")
        }

        // B walks the modes the scene declared, in the order it declared them,
        // and comes back round.
        function test_cycling_walks_the_modes_and_wraps() {
            nav.cycleMode()
            compare(nav.mode, "explore")
            nav.cycleMode()
            compare(nav.mode, "measure")
            nav.cycleMode()
            compare(nav.mode, "build", "and round again")
        }

        function test_toggle_is_still_the_cycle() {
            nav.toggleMode()
            compare(nav.mode, "explore", "the old name still moves the mode on")
        }

        function test_setting_and_locking() {
            nav.setMode("measure")
            compare(nav.mode, "measure")
            nav.modeLocked = true
            nav.cycleMode()
            compare(nav.mode, "measure", "a locked scene stays where it is")
            nav.setMode("build")
            compare(nav.mode, "measure")
            verify(!nav.modeSwitchable, "and says so, for the chrome")
        }

        // The lock generalized: sensor-fusion has nothing to build but plenty
        // to measure, which one boolean could not say.
        function test_a_scene_can_offer_only_some_of_the_modes() {
            nav.modes = ["explore", "measure"]
            nav.mode = "explore"
            verify(nav.modeSwitchable, "two modes are still a switch")
            verify(!nav.allows("build"), "but build is not one of them")
            nav.cycleMode()
            compare(nav.mode, "measure")
            nav.cycleMode()
            compare(nav.mode, "explore", "it never passes through build")
            nav.setMode("build")
            compare(nav.mode, "explore", "and cannot be put there either")
        }

        function test_one_mode_is_no_mode_control() {
            nav.modes = ["explore"]
            nav.mode = "explore"
            verify(!nav.modeSwitchable, "nothing to switch between")
            nav.cycleMode()
            compare(nav.mode, "explore")
        }

        // A list narrowed while the scene sits in a mode it no longer offers
        // must not strand the cycle.
        function test_a_mode_outside_the_list_cycles_back_in() {
            nav.mode = "build"
            nav.modes = ["explore", "measure"]
            nav.cycleMode()
            compare(nav.mode, "explore", "the first one it does offer")
        }

        // The pointer says which mode you are in before you press anything.
        function test_the_cursor_shows_the_mode() {
            compare(nav.cursorShape, Qt.ArrowCursor, "build")
            nav.mode = "explore"
            compare(nav.cursorShape, Qt.OpenHandCursor, "explore, idle")
            nav.begin(10, 10, Qt.LeftButton, 0)
            compare(nav.cursorShape, Qt.ClosedHandCursor, "explore, dragging")
            nav.cancel()
            compare(nav.cursorShape, Qt.OpenHandCursor)
        }

        // --- what a drag then does -------------------------------------------

        function test_a_build_mode_left_drag_moves_nothing() {
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "", "declined")
            compare(nav.move(200, 90), false, "and the move is the scene's too")
            verify(apart(before, rig.goalPivot) < 1e-6, "the camera did not stir")
        }

        function test_the_middle_button_pans_while_building() {
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.MiddleButton, 0), "pan")
            verify(nav.move(200, 40), "the drag is the camera's")
            nav.cancel()
            verify(apart(before, rig.goalPivot) > 1, "and the world moved with it")
        }

        function test_an_explore_left_drag_pans() {
            nav.mode = "explore"
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "pan")
            nav.move(60, 40)
            nav.cancel()
            verify(rig.goalPivot.x > before.x + 1,
                   "dragging left carries the ground with it: " + rig.goalPivot.x)
        }

        // The vertical half of grab-the-world: dy grows DOWNWARD, so the
        // screen-opposite move is +dy on the away axis, not -dy. This is the
        // sign that shipped wrong once - the ground followed the hand
        // left-right yet fought it up-down.
        function test_an_explore_down_drag_pulls_the_ground_down() {
            nav.mode = "explore"
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "pan")
            nav.move(120, 140)
            nav.cancel()
            verify(rig.goalPivot.z < before.z - 1,
                   "dragging down walks the pivot away: " + rig.goalPivot.z)
        }

        // --- measure mode -----------------------------------------------------
        //
        // One button, two meanings, and only the distance travelled tells them
        // apart: a click drops a point, anything further is explore's pan.

        function test_measure_answers_the_pointer_like_explore_does() {
            nav.mode = "measure"
            compare(nav.wants(Qt.LeftButton, 0), "pan", "left still drags the world")
            compare(nav.wants(Qt.RightButton, 0), "orbit", "right still turns it")
            compare(nav.wants(Qt.MiddleButton, 0), "pan", "and the middle is universal")
        }

        function test_a_measure_click_reports_the_point_under_it() {
            nav.mode = "measure"
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(60, -40, Qt.LeftButton, 0), "pan",
                    "the press is taken as a pan - a click is not knowable yet")
            nav.end()
            compare(picks.count, 1, "and comes out as a point")
            const p = picks.signalArguments[0][0]
            verify(near(p.x, 60) && near(p.z, -40), "where it was clicked: " + p)
            verify(apart(before, rig.goalPivot) < 1e-6, "and the camera never stirred")
        }

        // The point is taken at the PRESS: a click that trembles still pans a
        // pixel or two, which moves the ground the release would ask about.
        function test_a_trembling_click_still_measures_where_it_pressed() {
            nav.mode = "measure"
            nav.begin(60, -40, Qt.LeftButton, 0)
            nav.move(62, -39)
            nav.end()
            compare(picks.count, 1)
            const p = picks.signalArguments[0][0]
            verify(near(p.x, 60) && near(p.z, -40),
                   "the pressed point, not the released one: " + p)
        }

        function test_a_measure_drag_pans_and_measures_nothing() {
            nav.mode = "measure"
            const before = copyOf(rig.goalPivot)
            compare(nav.begin(120, 40, Qt.LeftButton, 0), "pan")
            nav.move(60, 40)
            nav.end()
            compare(picks.count, 0, "a drag is not a click")
            verify(rig.goalPivot.x > before.x + 1,
                   "and it carried the ground: " + rig.goalPivot.x)
        }

        function test_a_right_drag_still_orbits_while_measuring() {
            nav.mode = "measure"
            compare(nav.begin(60, -40, Qt.RightButton, 0), "orbit")
            verify(nav.anchor !== null, "anchored at the cursor as ever")
            nav.move(90, -40)
            nav.cancel()
            verify(!near(rig.goalYaw, 0), "and it turned: " + rig.goalYaw)
            compare(picks.count, 0, "the right button never measures")
        }

        function test_only_measure_mode_measures() {
            for (const m of ["build", "explore"]) {
                nav.mode = m
                nav.begin(60, -40, Qt.LeftButton, 0)
                nav.end()
                compare(picks.count, 0, m + ": a click means what it always did")
            }
        }

        // The quasimode borrows the camera, and while it is held the click is
        // explore's - i.e. nothing. A held key must not drop points.
        function test_the_spring_suspends_measuring() {
            nav.mode = "measure"
            nav.springExplore = true
            nav.begin(60, -40, Qt.LeftButton, 0)
            nav.end()
            compare(picks.count, 0, "nothing measured while the hand is borrowed")
            nav.springExplore = false
            nav.begin(60, -40, Qt.LeftButton, 0)
            nav.end()
            compare(picks.count, 1, "and it measures again when it comes back")
        }

        function test_the_middle_button_never_measures() {
            nav.mode = "measure"
            nav.begin(60, -40, Qt.MiddleButton, 0)
            nav.end()
            compare(picks.count, 0, "the pan button pans, whatever the mode")
        }

        function test_the_cursor_shows_measure_too() {
            nav.mode = "measure"
            compare(nav.cursorShape, Qt.CrossCursor, "a crosshair aims")
            nav.begin(10, 10, Qt.RightButton, 0)
            compare(nav.cursorShape, Qt.ClosedHandCursor, "and a drag grabs")
            nav.cancel()
        }

        function test_a_measure_click_off_the_plane_reports_nothing() {
            nav.view = null
            nav.mode = "measure"
            nav.begin(60, -40, Qt.LeftButton, 0)
            nav.end()
            compare(picks.count, 0, "no ray, no point - and no crash")
            nav.view = fakeView
        }

        // --- the anchored orbit ----------------------------------------------

        // Press over a point and the rig re-anchors there WITHOUT the picture
        // changing - the property the whole gesture stands on.
        function test_a_right_drag_anchors_at_the_cursor_without_a_jump() {
            nav.mode = "explore"
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
            nav.mode = "explore"
            nav.anchorOrbit = false
            const pivot = copyOf(rig.goalPivot)
            nav.begin(60, -40, Qt.RightButton, 0)
            nav.cancel()
            verify(apart(pivot, rig.goalPivot) < 1e-6, "the pivot stayed home")
            nav.anchorOrbit = true
        }

        // --- the wheel -------------------------------------------------------

        function test_the_wheel_zooms_towards_the_cursor_in_both_modes() {
            for (const m of ["build", "explore"]) {
                rig.applyState({ yaw: 0, pitch: 45, distance: 100, px: 0, py: 0, pz: 0 })
                nav.mode = m
                nav.wheel(120, 80, 60)
                verify(rig.goalDistance < 100, m + ": it came in")
                verify(rig.goalPivot.x > 1 && rig.goalPivot.z > 1,
                       m + ": and towards the corner, not the middle: " + rig.goalPivot)
            }
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

        // --- double-click focus, in either mode -------------------------------

        function test_double_click_focus_survives_the_modes() {
            for (const m of ["build", "explore"]) {
                rig.applyState({ yaw: 0, pitch: 45, distance: 100, px: 0, py: 0, pz: 0 })
                nav.mode = m
                verify(nav.recenterAt(35, -25), m + ": it focused")
                verify(near(rig.goalPivot.x, 35) && near(rig.goalPivot.z, -25),
                       m + ": on the point clicked: " + rig.goalPivot)
            }
        }

        // A scene with no view can still be driven; it simply loses the two
        // gestures that need a world point, rather than throwing.
        function test_no_view_costs_the_anchor_but_nothing_else() {
            nav.view = null
            nav.mode = "explore"
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
