// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The gait cycles against a stub body.
//
// WalkAnim and RunAnim ask their entity for a leg height, a gaitFactors
// vector and sixteen joints with an eulerRotation (the head with a poseEuler)
// - all answerable by QtObjects, so this runs with no built module, no
// window and no GPU, and on Windows (#192).
//
// gait.test.js pins the NUMBERS (neutral == legacy, to the digit). This half
// pins what only a running animation can show: that the joints the table
// names actually move - a Vector3dAnimation on a property that does not exist
// is silent, not an error - that the lift is zero at neutral and non-zero
// with a bounce, that a factor change reaches the cycle, and that the public
// Gait object composes the way its documentation says.

import QtQuick
import QtTest
import "../../animation"
import "../.."

Item {
    id: root
    width: 50; height: 50

    component Joint: QtObject {
        property vector3d eulerRotation: Qt.vector3d(0, 0, 0)
        function moved() { return eulerRotation.x !== 0 || eulerRotation.y !== 0 || eulerRotation.z !== 0 }
    }
    component StubHead: QtObject {
        property vector3d poseEuler: Qt.vector3d(0, 0, 0)
    }
    component StubLimb: QtObject {
        property Joint upperLeg: Joint {}
        property Joint lowerLeg: Joint {}
        property Joint foot: Joint {}
        property Joint upperArm: Joint {}
        property Joint lowerArm: Joint {}
        property Joint hand: Joint {}
    }
    component StubBody: QtObject {
        property real legHeight: 5.333
        property var gaitFactors: null
        property StubLimb rightLeg: StubLimb {}
        property StubLimb leftLeg: StubLimb {}
        property StubLimb rightArm: StubLimb {}
        property StubLimb leftArm: StubLimb {}
        property Joint torso: Joint {}
        property Joint hip: Joint {}
        property StubHead head: StubHead {}
        function reset() {
            for (const l of [rightLeg, leftLeg, rightArm, leftArm])
                for (const j of [l.upperLeg, l.lowerLeg, l.foot, l.upperArm, l.lowerArm, l.hand])
                    j.eulerRotation = Qt.vector3d(0, 0, 0)
            torso.eulerRotation = Qt.vector3d(0, 0, 0)
            hip.eulerRotation = Qt.vector3d(0, 0, 0)
            head.poseEuler = Qt.vector3d(0, 0, 0)
        }
    }

    TestCase {
        id: tc
        name: "Gait"
        when: windowShown

        StubBody { id: body }

        WalkAnim { id: walk; entity: body; running: false; loops: Animation.Infinite }
        RunAnim { id: run; entity: body; running: false; loops: Animation.Infinite }

        function init() {
            walk.stop()
            run.stop()
            body.gaitFactors = null
            body.reset()
        }

        // --- the legacy numbers reach the cycle ---------------------------------

        // The planted foot's travel over a step, knee included - what the
        // speed is derived from now (the old straight-leg arc skated).
        function ankleZ(hip, knee) {
            const rad = Math.PI / 180, L = 5.333 / 2
            return -L * Math.sin(hip * rad) - L * Math.sin((hip + knee) * rad)
        }

        function test_neutral_walk_is_the_legacy_walk() {
            const stride = (ankleZ(-25, 15) - ankleZ(20, 45)) * 2
            fuzzyCompare(walk.derivedWalkSpeed, stride / 0.8, 1e-9)
            compare(walk.cycleMs, 800)
            compare(walk.duration, 400)
            compare(walk.table.hipFwd, 25)
            compare(walk.table.kneeLift, 45)
            compare(walk.table.elbow, 10)
            compare(walk.table.lean, 0)
        }

        function test_neutral_run_is_the_legacy_run() {
            const stride = (ankleZ(-55, run.table.kneeExtend) - ankleZ(45, run.table.kneeLift)) * 2
            fuzzyCompare(run.derivedRunSpeed, stride / 0.45, 1e-9)
            compare(run.cycleMs, 450)
            compare(run.duration, 225)
            compare(run.table.lean, 12)
            compare(run.table.elbow, 70)
        }

        // --- the joints the table names actually move -----------------------------

        function test_walk_moves_every_gait_joint() {
            walk.start()
            tryVerify(() => body.rightLeg.upperLeg.moved(), 1000)
            tryVerify(() => body.leftLeg.upperLeg.moved(), 1000)
            tryVerify(() => body.rightLeg.lowerLeg.moved(), 1000)
            tryVerify(() => body.rightLeg.foot.moved(), 1000)
            tryVerify(() => body.rightArm.upperArm.moved(), 1000)
            tryVerify(() => body.leftArm.upperArm.moved(), 1000)
            tryVerify(() => body.rightArm.lowerArm.moved(), 1000)
            // A neutral walk holds the torso, hip and head level throughout.
            wait(450)
            verify(!body.torso.moved())
            verify(!body.hip.moved())
            compare(body.head.poseEuler, Qt.vector3d(0, 0, 0))
            compare(walk.lift, 0)
        }

        function test_run_leans_and_bends_the_elbows() {
            run.start()
            tryVerify(() => Math.abs(body.torso.eulerRotation.x - 12) < 0.01, 1000)
            tryVerify(() => Math.abs(body.rightArm.lowerArm.eulerRotation.x + 70) < 0.01, 1000)
        }

        // --- factors reach the cycle -------------------------------------------

        function test_bounce_lifts_and_neutral_does_not() {
            body.gaitFactors = { bounce: 0.05 }
            compare(walk.table.bounce, 0.05)
            walk.start()
            // Peak is bounce x legHeight, at mid-step.
            tryVerify(() => walk.lift > 0.2, 1000)
            walk.stop()
            compare(walk.lift, 0)
        }

        function test_posture_factors_reach_the_joints() {
            body.gaitFactors = { lean: 8, headPitch: 15, sway: 6, rock: 4 }
            walk.start()
            tryVerify(() => Math.abs(body.torso.eulerRotation.x - 8) < 0.05, 1000)
            tryVerify(() => Math.abs(body.head.poseEuler.x - 15) < 0.05, 1000)
            // The hip counters the waist lean so the legs stay planted.
            tryVerify(() => Math.abs(body.hip.eulerRotation.x + 8) < 0.05, 1000)
            tryVerify(() => Math.abs(Math.abs(body.hip.eulerRotation.y) - 6) < 0.05, 1500)
            tryVerify(() => Math.abs(Math.abs(body.torso.eulerRotation.z) - 4) < 0.05, 1500)
        }

        function test_tempo_and_stride_change_the_speed() {
            const neutral = walk.derivedWalkSpeed
            body.gaitFactors = { tempo: 0.5 }
            compare(walk.cycleMs, 1600)
            compare(walk.duration, 800)
            fuzzyCompare(walk.derivedWalkSpeed, neutral / 2, 1e-9)
            body.gaitFactors = { stride: 0.5 }
            verify(walk.derivedWalkSpeed < neutral)
            compare(walk.table.hipFwd, 12.5)
        }

        function test_the_cycle_survives_a_factor_change_while_running() {
            walk.start()
            tryVerify(() => body.rightLeg.upperLeg.moved(), 1000)
            body.gaitFactors = { tempo: 1.5, elbow: 20 }
            compare(walk.duration, 267)
            tryVerify(() => Math.abs(body.rightArm.lowerArm.eulerRotation.x + 30) < 0.05, 1500)
            verify(walk.running)
        }

        // --- the public Gait object --------------------------------------------

        Gait { id: plain }
        Gait { id: elderlyQuick; preset: "elderly"; tempo: 1.2 }
        Gait { id: unknown; preset: "moonwalk" }

        function test_gait_object_composes_preset_and_factors() {
            compare(plain.presetKnown, true)
            compare(plain.factors.tempo, 1)
            compare(plain.factors.lean, 0)
            fuzzyCompare(elderlyQuick.factors.tempo, 0.72 * 1.2, 1e-9)
            compare(elderlyQuick.factors.lean, 8)
            compare(elderlyQuick.presetKnown, true)
            compare(unknown.presetKnown, false)
            compare(unknown.factors.tempo, 1)
            verify(plain.presetNames.indexOf("sneak") >= 0)
        }

        function test_gait_object_feeds_the_cycle() {
            body.gaitFactors = elderlyQuick.factors
            fuzzyCompare(walk.cycleMs, 800 / (0.72 * 1.2), 1e-6)
            compare(walk.table.lean, 8)
            verify(walk.table.kneeLift < 45)
        }
    }
}
