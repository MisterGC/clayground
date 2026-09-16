// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The two-segment torso: a belly and a chest on a waist joint (#227).
//
// This needs the BUILT module - the segments are Box3D, whose geometry is C++
// in Canvas3D - so it is one of the halves Windows has to skip (#192).
//
// The claim it exists to pin is the one a screenshot can only suggest: at the
// default bellyRatio, bellyBulge, chestSwell and waistPinch the two boxes
// trace EXACTLY the tapered box the torso used to be - same shoulders, same
// waist, same depth, same total height, and the two of them meeting on the
// line between shoulder and waist rather than near it. Everything above the
// trunk (the shoulder joints, the head) has to come out at the same place
// too, because the arm solver, the gesture layer and the camera director all
// start from those anchors.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    TestCase {
        id: tc
        name: "Torso"
        when: windowShown

        // Plain numbers rather than the defaults, so a changed default cannot
        // make an assertion vacuous.
        Character {
            id: c
            shoulderWidth: 4.0
            waistWidth: 3.0
            torsoHeight: 2.5
            torsoDepth: 1.2
            hipHeight: 1.0
            hipWidth: 3.0
            legHeight: 5.0
            footHeight: 0.4
            neckHeight: 0.5
        }

        function init() {
            // IdleAnim zeroes every joint over its first 200 ms; a test that
            // writes a joint before that has finished is writing under it.
            wait(300)
            c.bellyRatio = 0.45
            c.bellyBulge = 1.0
            c.chestSwell = 1.0
            c.waistPinch = 0.0
            c.gait.lean = 0
            c.gait.spineCurve = 0
            c.belly.eulerRotation = Qt.vector3d(0, 0, 0)
            c.chest.eulerRotation = Qt.vector3d(0, 0, 0)
            c.torso.eulerRotation = Qt.vector3d(0, 0, 0)
            c.hip.eulerRotation = Qt.vector3d(0, 0, 0)
        }

        // --- the silhouette is the one the single box drew ----------------------

        function test_the_two_segments_add_up_to_the_torso() {
            fuzzyCompare(c.belly.height + c.chest.height, c.torsoHeight, 1e-6)
            fuzzyCompare(c.belly.height, c.torsoHeight * 0.45, 1e-6)
            compare(c.chest.width, c.shoulderWidth)
        }

        // Bottom of the belly is the waist, top of the chest is the shoulders,
        // and the joint between them sits on the straight line between the two
        // - which is what makes the pair trace the old trapezoid rather than
        // merely resemble it.
        function test_the_outline_is_the_old_trapezoid() {
            // The belly is measured at its bottom (the hip) and scaled at its
            // top (the joint); the chest the other way round.
            fuzzyCompare(c.belly.width, c.waistWidth, 1e-6)
            const joint = c.waistWidth + (c.shoulderWidth - c.waistWidth) * 0.45
            fuzzyCompare(c.belly.width * c.belly.faceScale.x, joint, 1e-6)
            // and the chest's bottom is the belly's top, so there is no step
            fuzzyCompare(c.chest.width * c.chest.faceScale.x, joint, 1e-6)
        }

        function test_the_depth_is_the_torso_depth_all_the_way_up() {
            fuzzyCompare(c.belly.depth, c.torsoDepth, 1e-6)
            fuzzyCompare(c.belly.depth * c.belly.faceScale.y, c.torsoDepth, 1e-6)
            fuzzyCompare(c.chest.depth, c.torsoDepth, 1e-6)
            fuzzyCompare(c.chest.depth * c.chest.faceScale.y, c.torsoDepth, 1e-6)
        }

        // The anchors the rest of the framework aims from. They used to be
        // sums over the single torso; they are sums over the trunk chain now
        // and have to answer with the same numbers.
        function test_the_anchors_did_not_move() {
            const trunkBottom = c.legHeight + c.footHeight + c.hipHeight
            fuzzyCompare(c.rightShoulderPos.y, trunkBottom + c.torsoHeight, 1e-6)
            fuzzyCompare(c.rightShoulderPos.x, c.shoulderWidth * 0.5, 1e-6)
            fuzzyCompare(c.rightShoulderPos.z, 0, 1e-6)
            fuzzyCompare(c.leftShoulderPos.x, -c.shoulderWidth * 0.5, 1e-6)
            fuzzyCompare(c.headPos.y, trunkBottom + c.torsoHeight + c.neckHeight, 1e-6)
            fuzzyCompare(c.headPos.z, 0, 1e-6)
        }

        // --- what the split buys ------------------------------------------------

        function test_a_bulging_belly_hangs_over_the_hip_and_leaves_the_rest_alone() {
            const joint = c.waistWidth + (c.shoulderWidth - c.waistWidth) * 0.45
            c.bellyBulge = 1.4
            // It is widest and deepest at the BOTTOM, where the hip is, so it
            // overhangs the belt instead of tapering into it.
            verify(c.belly.depth > c.torsoDepth)
            verify(c.belly.width > c.waistWidth)
            // Its top is still the plain joint section, so the ribcage above
            // is not dragged wider with it.
            fuzzyCompare(c.belly.width * c.belly.faceScale.x, joint, 1e-6)
            fuzzyCompare(c.belly.depth * c.belly.faceScale.y, c.torsoDepth, 1e-6)
            // and it is in front of the body rather than around it
            verify(c.belly.basePos.z > 0)
            // The chest keeps its own section and still meets the joint.
            fuzzyCompare(c.chest.depth, c.torsoDepth, 1e-6)
            fuzzyCompare(c.chest.width * c.chest.faceScale.x, joint, 1e-6)
            fuzzyCompare(c.chest.depth * c.chest.faceScale.y, c.torsoDepth, 1e-6)
            // and nothing above or below the waist has moved
            fuzzyCompare(c.headPos.z, 0, 1e-6)
            fuzzyCompare(c.rightShoulderPos.z, 0, 1e-6)
            fuzzyCompare(c.hip.basePos.z + c.belly.basePos.z, 0, 1e-6)
        }

        function test_a_swelled_chest_is_depth_and_not_shoulders() {
            c.chestSwell = 1.25
            verify(c.chest.depth > c.torsoDepth)
            compare(c.chest.width, c.shoulderWidth)
            fuzzyCompare(c.belly.depth, c.torsoDepth, 1e-6)
            fuzzyCompare(c.rightShoulderPos.x, c.shoulderWidth * 0.5, 1e-6)
        }

        // The one shape a single tapered box could not make: narrow in the
        // middle, wider at both ends.
        function test_a_pinch_narrows_the_joint_and_nothing_else() {
            const joint = c.waistWidth + (c.shoulderWidth - c.waistWidth) * 0.45
            const shoulders = c.chest.width
            c.waistPinch = 0.2
            verify(c.belly.width * c.belly.faceScale.x < joint)
            fuzzyCompare(c.chest.width * c.chest.faceScale.x,
                         c.belly.width * c.belly.faceScale.x, 1e-6)
            compare(c.chest.width, shoulders)
            fuzzyCompare(c.belly.width, c.waistWidth, 1e-6)
        }

        function test_the_ratio_moves_the_joint() {
            c.bellyRatio = 0.7
            fuzzyCompare(c.belly.height, c.torsoHeight * 0.7, 1e-6)
            fuzzyCompare(c.belly.height + c.chest.height, c.torsoHeight, 1e-6)
            // The joint is further up, so it is wider - still on the line.
            fuzzyCompare(c.belly.width * c.belly.faceScale.x,
                         c.waistWidth + (c.shoulderWidth - c.waistWidth) * 0.7, 1e-6)
        }

        // --- the joint bends ----------------------------------------------------

        // What makes a waist joint a joint: everything above it hangs off the
        // chest and everything below off the belly, so bending either carries
        // the right half of the body. Asserted as the parent chain rather than
        // as scene positions, because a node outside a View3D never syncs one -
        // scenePosition answers with whatever it held at construction, which is
        // a test that passes for the wrong reason as easily as it fails.
        function test_the_chest_carries_the_head_and_the_arms() {
            compare(c.chest.parent, c.belly)
            compare(c.head.parent, c.chest)
            compare(c.rightArm.parent, c.chest)
            compare(c.leftArm.parent, c.chest)
        }

        function test_the_belly_carries_the_hip_and_the_legs() {
            compare(c.belly.parent, c.torso)
            compare(c.hip.parent, c.belly)
            compare(c.rightLeg.parent, c.hip)
            compare(c.leftLeg.parent, c.hip)
        }

        // --- a gait pose lands on the segments ----------------------------------

        function test_applyGaitPose_puts_the_lean_in_the_spine() {
            c.gait.lean = 10
            c.gait.spineCurve = 18
            c.applyGaitPose("walk", 0.25)
            fuzzyCompare(c.belly.eulerRotation.x + c.chest.eulerRotation.x, 10, 0.01)
            verify(c.chest.eulerRotation.x - c.belly.eulerRotation.x > 15)
            compare(c.torso.eulerRotation.x, 0)
            // the legs stay planted: the hip gives the belly's bend back
            fuzzyCompare(c.belly.eulerRotation.x + c.hip.eulerRotation.x, 0, 0.01)
        }
    }

    // --- the build reaches the trunk -------------------------------------------

    TestCase {
        name: "TorsoBuild"
        when: windowShown

        ParametricCharacter { id: p }

        function init() {
            p.mass = 0.5
            p.muscle = 0.5
            p.femininity = 0.5
        }

        function test_the_defaults_change_nothing() {
            fuzzyCompare(p.bellyBulge, 1.0, 1e-9)
            fuzzyCompare(p.chestSwell, 1.0, 1e-9)
            fuzzyCompare(p.waistPinch, 0.0, 1e-9)
        }

        function test_mass_is_the_belly_and_muscle_is_the_chest() {
            p.mass = 1.0
            verify(p.bellyBulge > 1.1)
            fuzzyCompare(p.chestSwell, 1.0, 1e-9)
            p.mass = 0.0
            verify(p.bellyBulge < 1.0)
            p.mass = 0.5

            p.muscle = 1.0
            verify(p.chestSwell > 1.1)
            fuzzyCompare(p.bellyBulge, 1.0, 1e-9)
            p.muscle = 0.0
            verify(p.chestSwell < 1.0)
        }

        function test_a_waist_comes_from_muscle_and_goes_with_mass() {
            p.muscle = 1.0
            verify(p.waistPinch > 0.05)
            p.mass = 1.0
            fuzzyCompare(p.waistPinch, 0.0, 1e-9)
        }
    }
}
