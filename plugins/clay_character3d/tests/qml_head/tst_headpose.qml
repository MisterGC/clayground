// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The head's rotation channels, and the blink.
//
// This half needs the BUILT module - a Head is made of Box3DGeometry, which
// is C++ in Canvas3D - so it is the half Windows has to skip (#192). Which is
// why it is only the tests that cannot be written any other way.
//
// The one worth having most guards a failure that is completely silent: a
// Vector3dAnimation naming a property that does not exist is not an error,
// it just does nothing. Rename poseEuler and every character in the framework
// freezes its neck while the suite stays green - unless something asserts
// that the animation actually moves it.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    TestCase {
        id: tc
        name: "HeadPose"
        when: windowShown

        Head { id: head; features: true }

        // Stands in for a body animator: same component, same property.
        HeadEulerAnim {
            id: aim
            target: head
            duration: 120
            to: Qt.vector3d(11, 22, 0)
        }

        function init() {
            aim.stop()
            head.poseEuler = Qt.vector3d(0, 0, 0)
            head.offsetEuler = Qt.vector3d(0, 0, 0)
            head.baseEuler = Qt.vector3d(0, 0, 0)
            wait(50)
        }

        function test_rotation_is_the_sum_of_its_channels() {
            head.baseEuler = Qt.vector3d(1, 2, 3)
            head.poseEuler = Qt.vector3d(10, 20, 30)
            head.offsetEuler = Qt.vector3d(100, 200, 300)
            compare(head.eulerRotation.x, 111)
            compare(head.eulerRotation.y, 222)
            compare(head.eulerRotation.z, 333)
        }

        // The whole reason the split exists. Before it, an aim and a nod were
        // alternatives and whichever wrote last erased the other.
        function test_a_nod_does_not_lose_the_aim() {
            head.poseEuler = Qt.vector3d(-3, 45, 0)
            head.nod(8)
            tryVerify(function() { return head.nodAmount > 4 }, 1000)
            // The aim is untouched while the nod is at its deepest...
            compare(head.poseEuler.y, 45)
            verify(head.eulerRotation.x > head.poseEuler.x + 3,
                   "euler.x=" + head.eulerRotation.x)
            compare(head.eulerRotation.y, 45)
            // ...and the head is given back afterwards.
            tryVerify(function() { return head.nodAmount === 0 }, 2000)
            compare(head.eulerRotation.x, -3)
            compare(head.eulerRotation.y, 45)
        }

        function test_a_nod_is_its_own_channel() {
            // Not readable from offsetEuler, so that a caller's own offset and
            // a nod can both be true rather than the last writer taking the
            // whole vector.
            head.offsetEuler = Qt.vector3d(0, 7, 0)
            head.nod(8)
            tryVerify(function() { return head.nodAmount > 4 }, 1000)
            compare(head.offsetEuler.y, 7)
            compare(head.eulerRotation.y, 7)
            tryVerify(function() { return head.nodAmount === 0 }, 2000)
        }

        function test_nod_takes_a_depth_and_a_count() {
            head.nod(14)
            tryVerify(function() { return head.nodAmount > 10 }, 1000)
            tryVerify(function() { return head.nodAmount === 0 }, 2000)
        }

        // The silent one.
        function test_a_body_animator_moves_the_pose_channel() {
            compare(head.poseEuler.y, 0)
            aim.start()
            tryVerify(function() { return head.poseEuler.y > 15 }, 2000,
                      "HeadEulerAnim did not move poseEuler - has the property "
                      + "been renamed? An animation on a missing property is "
                      + "not an error, it is silence.")
            // And the sum follows it.
            compare(head.eulerRotation.y, head.poseEuler.y)
        }

        function test_blink_shuts_and_opens() {
            compare(head.blinkAmount, 0)
            head.blink()
            tryVerify(function() { return head.blinkAmount > 0.8 }, 1000)
            tryVerify(function() { return head.blinkAmount === 0 }, 1000)
        }

        function test_autoblink_keeps_going() {
            head.blinkInterval = 400
            head.autoBlink = true
            let seen = 0
            for (var i = 0; i < 60 && seen < 2; ++i) {
                wait(50)
                if (head.blinkAmount > 0.5) {
                    seen++
                    // wait out this blink so it is not counted twice
                    tryVerify(function() { return head.blinkAmount === 0 }, 1000)
                }
            }
            head.autoBlink = false
            verify(seen >= 2, "only " + seen + " blink(s)")
        }

        function test_brow_flash_is_additive_and_returns() {
            compare(head.browFlash, 0)
            head.flashBrows(0.3)
            tryVerify(function() { return head.browFlash > 0 }, 1000)
            tryVerify(function() { return head.browFlash === 0 }, 1500)
        }

        // Deterministic-but-irregular: two heads with a seed blink in step,
        // two seeds do not. Evenly spaced blinks read as a metronome - the eye
        // notices the beat long before it notices the blink - and a wall clock
        // would make two clayrender comparisons of the same scene disagree.
        //
        // Three heads run AT ONCE and their blink onsets are recorded, rather
        // than one head timed three times: the assertion is about agreement
        // between them, and running them together makes that a comparison of
        // one clock instead of three.
        function test_blink_spacing_is_seeded_not_even_and_not_random() {
            // Above the 400 ms floor the spacing is clamped to. Set an
            // interval near it - 300 was the first try - and every seed comes
            // out at 400, which looks exactly like a broken seed and is not.
            const a = headComp.createObject(root, {blinkSeed: 3, blinkInterval: 900})
            const b = headComp.createObject(root, {blinkSeed: 3, blinkInterval: 900})
            const c = headComp.createObject(root, {blinkSeed: 8, blinkInterval: 900})
            const ha = [], hb = [], hc = []
            const wasA = {v: false}, wasB = {v: false}, wasC = {v: false}
            a.autoBlink = true; b.autoBlink = true; c.autoBlink = true

            function sample(h, log, was, t) {
                const shut = h.blinkAmount > 0.5
                if (shut && !was.v) log.push(t)
                was.v = shut
            }
            for (var t = 0; t < 4200; t += 25) {
                wait(25)
                sample(a, ha, wasA, t)
                sample(b, hb, wasB, t)
                sample(c, hc, wasC, t)
            }
            a.destroy(); b.destroy(); c.destroy()

            verify(ha.length >= 3, "only " + ha.length + " blink(s) recorded")
            // Not a metronome: the gaps must not all be the same.
            const gaps = []
            for (var i = 1; i < ha.length; ++i)
                gaps.push(ha[i] - ha[i - 1])
            verify(gaps.length >= 2, "not enough gaps to judge evenness")
            var even = true
            for (var j = 1; j < gaps.length; ++j)
                if (gaps[j] !== gaps[0]) even = false
            verify(!even, "blinks were evenly spaced: " + gaps.join(","))

            compare(hb.join(","), ha.join(","))
            verify(hc.join(",") !== ha.join(","),
                   "two seeds blinked alike: " + ha.join(","))
        }

        property Component headComp: Component { Head {} }
    }
}
