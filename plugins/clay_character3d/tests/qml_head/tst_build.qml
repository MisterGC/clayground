// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// How much of the build a HAND takes (#235).
//
// This needs the BUILT module - a ParametricCharacter is made of Box3D, whose
// geometry is C++ in Canvas3D - so it is one of the halves Windows has to
// skip (#192).
//
// The claim it pins is one that is otherwise only ever judged by eye, and was
// judged wrongly for a long time: the hand must NOT take the whole of the
// build's width. It used to, because the palm is a fixed fraction of the arm
// and nothing sat in between, so the two width sliders scaled a hand over a
// spread of two and a half from end to end - claws on a thin figure, mittens
// on a heavy one. A hand is nearly the same object on every adult; it is the
// limb around it that changes.
//
// Everything here is a RATIO, never a length, so it survives a change to the
// proportion tables that moves both numbers together.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    // The two ends of the two width sliders and the middle, as three figures
    // built the same way in everything else.
    component Build: ParametricCharacter {
        bodyHeight: 10
        maturity: 0.5
        femininity: 0.5
    }

    Build { id: thin;    mass: 0.0; muscle: 0.0 }
    Build { id: neutral; mass: 0.5; muscle: 0.5 }
    Build { id: heavy;   mass: 1.0; muscle: 1.0 }

    // The same three with the damping turned off, which is the behaviour this
    // replaced: kept as the control, so "it used to be worse" is measured
    // rather than remembered.
    Build { id: thinRaw;  mass: 0.0; muscle: 0.0; handBuildResponse: 1.0 }
    Build { id: heavyRaw; mass: 1.0; muscle: 1.0; handBuildResponse: 1.0 }

    // And with it off the other way: a hand the build cannot touch at all.
    Build { id: thinFixed;  mass: 0.0; muscle: 0.0; handBuildResponse: 0.0 }
    Build { id: heavyFixed; mass: 1.0; muscle: 1.0; handBuildResponse: 0.0 }

    TestCase {
        name: "HandBuild"
        when: windowShown

        // How wide the palm is against the arm it hangs off. Arm sizes the
        // palm at 1.05 of the arm's own width, so that is what an undamped
        // hand reads at whatever the build.
        function palmPerArm(c) { return c.handWidth / c.armWidth }

        function test_neutral_is_untouched() {
            // The damping is defined as a pull toward the NEUTRAL build, so at
            // the neutral build it has nothing to do - a figure in the middle
            // of both sliders must come out exactly as it did before this
            // existed, whatever the response is set to.
            fuzzyCompare(palmPerArm(neutral), 1.05, 1e-6)
            fuzzyCompare(neutral.handDepth / neutral.armDepth, 0.34, 1e-6)
        }

        function test_undamped_hand_is_glued_to_the_arm() {
            // The control. With the response at 1 the hand tracks the arm
            // exactly, at every build - which is why it used to shrink and
            // swell with it.
            fuzzyCompare(palmPerArm(thinRaw), 1.05, 1e-6)
            fuzzyCompare(palmPerArm(heavyRaw), 1.05, 1e-6)
            verify(thinRaw.handWidth < neutral.handWidth * 0.7)
            verify(heavyRaw.handWidth > neutral.handWidth * 1.4)
        }

        function test_a_thin_figure_keeps_a_hand() {
            // Relatively wider than the arm, which is what a thin person's
            // hand looks like - and wider than the undamped one in absolute
            // terms, which is the claw that was being fixed.
            verify(palmPerArm(thin) > 1.05)
            verify(thin.handWidth > thinRaw.handWidth)
            // ...but still a hand on that arm, not a paddle.
            verify(palmPerArm(thin) < 1.6)
        }

        function test_a_heavy_figure_does_not_get_mittens() {
            verify(palmPerArm(heavy) < 1.05)
            verify(heavy.handWidth < heavyRaw.handWidth)
            verify(palmPerArm(heavy) > 0.75)
        }

        function test_the_hand_moves_less_than_the_arm_does() {
            const armSpread = heavy.armWidth / thin.armWidth
            const handSpread = heavy.handWidth / thin.handWidth
            // The arm still spans the whole build - nothing here touches it.
            verify(armSpread > 2.0)
            // The hand spans much less of it. This is the whole change.
            verify(handSpread < armSpread * 0.75)
            // Depth follows width, or a damped hand would be a flat one.
            fuzzyCompare(heavy.handDepth / heavy.handWidth,
                         thin.handDepth / thin.handWidth, 1e-6)
        }

        function test_response_zero_takes_the_build_away_entirely() {
            fuzzyCompare(thinFixed.handWidth, heavyFixed.handWidth, 1e-6)
            fuzzyCompare(thinFixed.handWidth, neutral.handWidth, 1e-6)
        }

        function test_hand_length_is_not_a_build_matter() {
            // Length comes off the arm's LENGTH, which follows maturity and
            // body height rather than the width sliders - so the three figures
            // agree about it and the damping has nothing to say.
            fuzzyCompare(thin.handHeight, heavy.handHeight, 1e-6)
            fuzzyCompare(thin.handHeight, neutral.handHeight, 1e-6)
        }
    }
}
