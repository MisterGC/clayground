// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The six facial expressions, as the numbers that make them.
//
// Needs the BUILT module - a Head is made of Box3DGeometry, which is C++ in
// Canvas3D - so this is a half Windows has to skip (#192).
//
// The claim under test is the one a screenshot cannot make: that the six are
// distinct IN KIND, not merely in degree. Two failures this guards, both of
// which look fine in a still of any single face:
//
//   * a channel an expression never names. A ParallelAnimation that does not
//     mention eyeSquint does not reset it - it inherits whatever the last
//     face left there, so an expression is correct only when it is the first
//     one ever shown. Every expression here is checked from every other, not
//     just from neutral.
//   * two expressions that agree everywhere the eye looks first. Joy and
//     sadness used to share one brow component and differed only at the
//     mouth, which is precisely "different in degree".
//
// Distinctness is measured on the face's own ten parameters rather than on
// pixels, because those parameters ARE the face: it is drawn in a shader from
// nothing else.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    TestCase {
        id: tc
        name: "HeadExpressions"
        when: windowShown

        Head {
            id: head
            features: true
            // Short, so a test that has to visit six expressions is not
            // twelve seconds of waiting for eases.
            toEmotionDuration: 60
        }

        readonly property var all: [
            { name: "neutral",   activity: Head.Activity.Idle },
            { name: "happy",     activity: Head.Activity.ShowJoy },
            { name: "sad",       activity: Head.Activity.ShowSadness },
            { name: "angry",     activity: Head.Activity.ShowAnger },
            { name: "disgust",   activity: Head.Activity.ShowDisgust },
            { name: "surprised", activity: Head.Activity.ShowSurprise }
        ]

        // The ten animated channels, normalized so a step of 1 means the same
        // amount of face in each. The two brow lengths are divided by an eye
        // width (the unit they are authored in) and the angle by 30 degrees,
        // which is about as far as a brow ever goes.
        function signature() {
            return {
                cornerLift: head.mouthCornerLift,
                skew: head.mouthSkew,
                open: head.mouthOpen,
                wide: head.mouthWide,
                round: head.mouthRound,
                hood: head.eyeHood,
                squint: head.eyeSquint,
                browAngle: head.browAngle / 30,
                browRise: head.browRise / head.eyeWidth,
                browSkew: head.browSkew / head.eyeWidth
            }
        }

        readonly property var channels: ["cornerLift", "skew", "open", "wide",
                                         "round", "hood", "squint",
                                         "browAngle", "browRise", "browSkew"]

        function wear(activity) {
            head.activity = activity
            // The eases are 60 ms; give them room and then confirm the face
            // has actually settled rather than trusting a sleep.
            wait(260)
        }

        function init() {
            head.activity = Head.Activity.Idle
            wait(260)
        }

        // Neutral is all ten channels at rest. Everything below is a distance
        // from this, so if it drifts every other assertion drifts with it.
        function test_neutral_is_rest() {
            wear(Head.Activity.Idle)
            const s = tc.signature()
            for (let i = 0; i < tc.channels.length; ++i)
                fuzzyCompare(s[tc.channels[i]], 0, 0.001,
                             "channel " + tc.channels[i] + " is not at rest")
        }

        // The whole of the issue, as one assertion: every pair of the six
        // differs, and differs by more than a nudge, on at least two channels.
        // Two rather than one because one channel is a difference of degree -
        // the same face turned up - and it was possible to tell joy from
        // sadness by the mouth alone, which is what made a still of them so
        // easy to confuse.
        function test_every_pair_differs_in_kind() {
            const sigs = {}
            for (let i = 0; i < tc.all.length; ++i) {
                wear(tc.all[i].activity)
                sigs[tc.all[i].name] = tc.signature()
            }
            for (let a = 0; a < tc.all.length; ++a) {
                for (let b = a + 1; b < tc.all.length; ++b) {
                    const na = tc.all[a].name, nb = tc.all[b].name
                    let big = []
                    let total = 0
                    for (let c = 0; c < tc.channels.length; ++c) {
                        const k = tc.channels[c]
                        const d = Math.abs(sigs[na][k] - sigs[nb][k])
                        total += d
                        if (d >= 0.25) big.push(k + "=" + d.toFixed(2))
                    }
                    verify(big.length >= 2,
                           na + " and " + nb + " differ clearly on only "
                           + big.length + " channel(s) [" + big.join(", ")
                           + "], total " + total.toFixed(2))
                    verify(total >= 1.0,
                           na + " and " + nb + " are only " + total.toFixed(2)
                           + " apart in total")
                }
            }
        }

        // The pair the issue names first. They used to share a brow component,
        // so the brows agreed and only the mouth disagreed. The brows must now
        // hinge opposite ways: joy's inner ends do not fall, sadness's do not
        // rise.
        function test_joy_and_sadness_disagree_at_the_brow() {
            wear(Head.Activity.ShowJoy)
            const joy = tc.signature()
            wear(Head.Activity.ShowSadness)
            const sad = tc.signature()
            verify(joy.browAngle > 0.1,
                   "joy's brows are not tilted outward: " + joy.browAngle)
            verify(sad.browAngle < -0.5,
                   "sadness's brows are not tilted inward: " + sad.browAngle)
            // And at the lids, which is the other half of it: a smile closes
            // the eye from below, sadness from above.
            verify(joy.squint > joy.hood + 0.4, "joy is not squinting")
            verify(sad.hood > sad.squint + 0.3, "sadness is not hooded")
        }

        // Anger is a shout and sadness is not, so the mouths differ as well as
        // the brows - otherwise the two are one down-turned mouth under
        // different eyebrows.
        function test_anger_and_sadness_disagree_at_the_mouth() {
            wear(Head.Activity.ShowAnger)
            const angry = tc.signature()
            wear(Head.Activity.ShowSadness)
            const sad = tc.signature()
            verify(angry.open > sad.open + 0.3,
                   "anger's mouth is not open: " + angry.open + " vs " + sad.open)
            verify(angry.browAngle > 0.5 && sad.browAngle < -0.5,
                   "the brows hinge the same way")
        }

        // Disgust is the one lopsided face, and that is what keeps it from
        // being a quieter anger.
        function test_disgust_is_the_only_lopsided_face() {
            for (let i = 0; i < tc.all.length; ++i) {
                wear(tc.all[i].activity)
                const s = tc.signature()
                const lopsided = Math.abs(s.skew) + Math.abs(s.browSkew)
                if (tc.all[i].name === "disgust")
                    verify(lopsided > 0.8,
                           "disgust is symmetric: " + lopsided)
                else
                    fuzzyCompare(lopsided, 0, 0.001,
                                 tc.all[i].name + " is lopsided: " + lopsided)
            }
        }

        // Surprise is a round mouth under high brows with the eyes fully
        // open. A lid of any kind turns it into one of the other five.
        function test_surprise_is_round_high_and_wide_eyed() {
            wear(Head.Activity.ShowSurprise)
            const s = tc.signature()
            verify(s.round > 0.6, "the mouth is not rounded: " + s.round)
            verify(s.open > 0.6, "the mouth is not open: " + s.open)
            verify(s.browRise > 0.6, "the brows are not raised: " + s.browRise)
            fuzzyCompare(s.hood, 0, 0.001, "surprise is hooded")
            fuzzyCompare(s.squint, 0, 0.001, "surprise is squinting")
        }

        // The silent failure this file exists for. An expression that does not
        // name a channel does not reset it, so a face is correct only when it
        // follows neutral. Reached from every other expression, each of the
        // six has to arrive at the same place.
        function test_an_expression_does_not_inherit_the_last_one() {
            for (let target = 0; target < tc.all.length; ++target) {
                wear(Head.Activity.Idle)
                wear(tc.all[target].activity)
                const fromNeutral = tc.signature()
                for (let via = 0; via < tc.all.length; ++via) {
                    if (via === target) continue
                    wear(tc.all[via].activity)
                    wear(tc.all[target].activity)
                    const s = tc.signature()
                    for (let c = 0; c < tc.channels.length; ++c) {
                        const k = tc.channels[c]
                        fuzzyCompare(s[k], fromNeutral[k], 0.001,
                                     tc.all[target].name + " reached via "
                                     + tc.all[via].name + " kept a different "
                                     + k)
                    }
                }
            }
        }

        // Talking takes the mouth over and hands it back; the emotion it was
        // wearing has to survive that, because a character says a happy line
        // by talking with a happy face.
        function test_talking_leaves_the_eyes_and_the_corners_alone() {
            wear(Head.Activity.ShowJoy)
            const joy = tc.signature()
            head.activity = Head.Activity.Talk
            wait(300)
            fuzzyCompare(head.eyeSquint, joy.squint, 0.001)
            fuzzyCompare(head.mouthCornerLift, joy.cornerLift, 0.001)
            fuzzyCompare(head.browAngle / 30, joy.browAngle, 0.001)
            wear(Head.Activity.ShowJoy)
            fuzzyCompare(tc.signature().open, joy.open, 0.001,
                         "the mouth did not come back from talking")
        }

        // The enum's numbering is API. A saved character carries the number,
        // not the name, so inserting a value rather than appending one turns
        // every stored expression into its neighbour.
        function test_the_activity_numbering_did_not_move() {
            compare(Head.Activity.ShowJoy, 0)
            compare(Head.Activity.ShowAnger, 1)
            compare(Head.Activity.ShowSadness, 2)
            compare(Head.Activity.Talk, 3)
            compare(Head.Activity.Idle, 4)
            compare(Head.Activity.ShowDisgust, 5)
            compare(Head.Activity.ShowSurprise, 6)
        }
    }
}
