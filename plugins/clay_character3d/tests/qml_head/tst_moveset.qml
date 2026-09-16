// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Loadable move sets (#238): a set that is loaded onto a character rather
// than instantiated with every one of them.
//
// This needs the BUILT module - a Character is made of Box3D, whose geometry
// is C++ in Canvas3D - so it is one of the halves Windows has to skip (#192).
// The angles themselves are checked by node in movesets/martialarts.test.js;
// what is left for this suite is everything that only exists once a set is
// actually loaded onto a running character: that loading and unloading work
// at all, that a move owns the joints while it runs and hands them back when
// it stops, that a knockdown STAYS on the floor, and that the set and the
// activity state machine do not fight over the body.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    TestCase {
        id: tc
        name: "MoveSet"
        when: windowShown

        Character {
            id: c
            legHeight: 5.0
            footHeight: 0.4
            hipHeight: 1.0
            torsoDepth: 1.2
        }

        function init() {
            // IdleAnim zeroes every joint over its first 200 ms; a test that
            // reads a joint before that has finished is reading under it.
            c.moveSet = ""
            c.activity = Character.Activity.Idle
            wait(300)
        }

        function cleanupTestCase() {
            c.moveSet = ""
        }

        function test_a_character_carries_no_set_until_one_is_loaded() {
            compare(c.moveSet, "")
            compare(c.moveSetName, "")
            compare(c.moves.length, 0)
            compare(c.activeMove, "")
            verify(!c.moveHolding)
            // And asking for a move without a set is a no-op rather than a
            // crash: a set is optional, so every call through it has to be.
            verify(!c.playMove("jab"))
            c.stopMove()
            compare(c.movePoseAt("jab", 0.5), null)
        }

        function test_the_shipped_set_loads_by_name() {
            verify(c.shippedMoveSets["martial arts"] !== undefined)
            c.moveSet = "martial arts"
            compare(c.moveSetName, "martial arts")
            // The fourteen of the reference sheet, and the same names the
            // model publishes.
            compare(c.moves.length, 14)
            compare(c.moves[0].name, "stance")
            let names = []
            for (let i = 0; i < c.moves.length; ++i)
                names.push(c.moves[i].name)
            verify(names.indexOf("roundhouse") >= 0)
            verify(names.indexOf("knockdown") >= 0)
            verify(names.indexOf("getUp") >= 0)
            // Loading is not playing: a set sits there until it is asked for
            // something.
            compare(c.activeMove, "")
            verify(!c.movePlaying)
        }

        function test_an_unknown_set_leaves_the_character_alone() {
            c.moveSet = "martial arts"
            compare(c.moves.length, 14)
            // The warning it prints is the point of the warning; what is
            // being checked here is that the character is left usable.
            c.moveSet = "no such set"
            compare(c.moves.length, 0)
            compare(c.moveSetName, "")
            verify(!c.playMove("jab"))
        }

        function test_unloading_gives_the_body_back() {
            c.moveSet = "martial arts"
            verify(c.playMove("stance"))
            verify(c.moveHolding)
            c.moveSet = ""
            compare(c.moves.length, 0)
            verify(!c.moveHolding)
            compare(c.activeMove, "")
            // The idle pose takes the joints back to standing.
            wait(400)
            fuzzyCompare(c.torso.eulerRotation.y, 0, 0.5)
        }

        function test_a_move_owns_the_body_while_it_runs() {
            c.moveSet = "martial arts"
            verify(c.playMove("stance"))
            compare(c.activeMove, "stance")
            verify(c.movePlaying)
            verify(c.moveHolding)
            // The blade is the whole of what a stance looks like from any
            // angle, and it lives on the trunk group.
            wait(300)
            verify(Math.abs(c.torso.eulerRotation.y) > 10)
            // A fighting set closes the hands, and it says so through the
            // same channel the boxing cycle does.
            compare(c.moveHandPose, "fist")
            compare(c.actionHandPose, "fist")
        }

        function test_an_unknown_move_does_nothing() {
            c.moveSet = "martial arts"
            verify(c.playMove("stance"))
            verify(!c.playMove("moonwalk"))
            compare(c.activeMove, "stance")
        }

        function test_a_one_shot_hands_back_to_the_stance() {
            c.moveSet = "martial arts"
            verify(c.playMove("jab"))
            compare(c.activeMove, "jab")
            // Long enough for the jab and the hand-back: the jab is under
            // half a second at the default effort.
            tryCompare(c, "activeMove", "stance", 3000)
            verify(c.movePlaying)
        }

        function test_the_finished_signal_names_the_move_that_ended() {
            c.moveSet = "martial arts"
            _finished.clear()
            c.playMove("jab")
            _finished.wait(3000)
            compare(_finished.signalArguments[0][0], "jab")
        }

        function test_a_knockdown_stays_on_the_floor() {
            c.moveSet = "martial arts"
            verify(c.playMove("knockdown"))
            // It ends, and having ended it is still holding: the next thing a
            // knocked-down figure does is get up, and that is another move.
            tryCompare(c, "movePlaying", false, 4000)
            verify(c.moveHolding)
            compare(c.activeMove, "knockdown")
            // Flat on its back: the whole trunk group is pitched backwards
            // and the figure has been dropped to the floor.
            verify(c.torso.eulerRotation.x < -60)
            verify(c.gaitLift < -0.8 * c.legHeight)
            // And the idle pose has been kept off it - a knockdown handed to
            // IdleAnim stands back up within a fifth of a second.
            wait(400)
            verify(c.torso.eulerRotation.x < -60)
        }

        function test_the_get_up_starts_where_the_knockdown_ended() {
            c.moveSet = "martial arts"
            const down = c.movePoseAt("knockdown", 1)
            const up = c.movePoseAt("getUp", 0)
            verify(down !== null && up !== null)
            compare(JSON.stringify(up), JSON.stringify(down))
            // And it ends on its feet.
            const end = c.movePoseAt("getUp", 1)
            fuzzyCompare(end.torso[0], 0, 0.001)
        }

        function test_stopping_a_held_move_releases_the_body() {
            c.moveSet = "martial arts"
            c.playMove("knockdown")
            tryCompare(c, "movePlaying", false, 4000)
            verify(c.moveHolding)
            c.stopMove()
            verify(!c.moveHolding)
            compare(c.activeMove, "")
            // The idle pose brings it upright again.
            tryVerify(function () { return c.torso.eulerRotation.x > -5 }, 2000)
        }

        function test_a_move_puts_the_activity_back_to_idle() {
            c.moveSet = "martial arts"
            c.activity = Character.Activity.Walking
            verify(c.playMove("stance"))
            compare(c.activity, Character.Activity.Idle)
        }

        function test_starting_another_activity_drops_the_move() {
            c.moveSet = "martial arts"
            verify(c.playMove("stance"))
            c.activity = Character.Activity.Walking
            verify(!c.moveHolding)
            compare(c.activeMove, "")
            c.activity = Character.Activity.Idle
        }

        function test_the_body_travels_over_its_own_feet_and_comes_back() {
            c.moveSet = "martial arts"
            const at = c.position
            verify(c.playMove("step"))
            // The step carries the whole figure forward of the character's
            // position and never moves the character itself.
            tryVerify(function () { return Math.abs(c.bodyDrift) > 0.1 }, 2000)
            compare(c.position, at)
            c.stopMove()
            c.moveSet = ""
            tryVerify(function () { return Math.abs(c.bodyDrift) < 0.05 }, 2000)
        }

        function test_the_pose_a_sheet_reads_is_the_pose_that_plays() {
            c.moveSet = "martial arts"
            // Pure: asking twice gives the same answer, and asking with
            // nothing running gives an answer at all.
            const a = c.movePoseAt("roundhouse", 0.55)
            const b = c.movePoseAt("roundhouse", 0.55)
            compare(JSON.stringify(a), JSON.stringify(b))
            verify(a.rightLeg !== undefined && a.lift !== undefined)
            // applyMovePose freezes the joints at that phase.
            c.applyMovePose("roundhouse", 0.55)
            fuzzyCompare(c.rightLeg.upperLeg.eulerRotation.x, a.rightLeg.upper[0], 0.001)
            fuzzyCompare(c.torso.eulerRotation.z, a.torso[2], 0.001)
        }

        function test_effort_changes_the_speed_and_not_the_pose_family() {
            c.moveSet = "martial arts"
            c.actionIntensity = 0.0
            const slow = c.movePoseAt("jab", 0.45)
            c.actionIntensity = 1.0
            const fast = c.movePoseAt("jab", 0.45)
            // Same joint, further out.
            verify(Math.abs(fast.leftArm.upper[0]) > Math.abs(slow.leftArm.upper[0]))
            c.actionIntensity = 0.5
        }

        SignalSpy {
            id: _finished
            target: c
            signalName: "moveFinished"
        }
    }
}
