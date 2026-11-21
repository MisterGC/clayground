// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The clock every lab's determinism rests on (#532): its random stream, its
// reset and its fixed steps.
//
// The clocks here are driven by hand through _advance(), the one call both of
// the clock's own drivers (physics steps, the frame ticker) end in. timeScale 0
// keeps the frame ticker running but moving nothing, so a test sees only the
// time it advanced itself.

import QtQuick
import QtTest
import Clayground.Common
import Clayground.Lab

Item {
    width: 50; height: 50

    SimClock { id: a; seed: 7; timeScale: 0 }
    SimClock { id: b; seed: 7; timeScale: 0 }

    SimClock {
        id: stepper
        seed: 1
        timeScale: 0
        fixedStep: 1 / 60
        property int count: 0
        property real stepped_: 0
        onStepped: (dt) => { count++; stepped_ += dt }
        function rewind() { reset(); count = 0; stepped_ = 0 }
    }

    // Created on demand, so it is the clock Lab knows while it lives - the
    // inspector's step request is answered by the clock without a world.
    Component {
        id: liveClock
        SimClock { seed: 3; timeScale: 0; fixedStep: 1 / 60
                   property int count: 0; onStepped: count++ }
    }

    function draws(clock, n) {
        const out = []
        for (let i = 0; i < n; ++i) out.push(clock.random())
        return out
    }

    TestCase {
        name: "SimClock"

        function init() {
            a.seed = 7; b.seed = 7
            a.reset(); b.reset()
            stepper.fixedStep = 1 / 60
            stepper.maxStepsPerAdvance = 8
            stepper.rewind()
        }

        function test_sameSeedSameSequence() {
            const sa = draws(a, 50), sb = draws(b, 50)
            compare(sa, sb, "two clocks of one seed draw the same numbers")
            for (const v of sa) verify(v >= 0 && v < 1, "random() is in [0, 1): " + v)
            verify(sa[0] !== sa[1], "and they are not one number repeated")
        }

        function test_otherSeedOtherSequence() {
            b.seed = 8
            verify(JSON.stringify(draws(a, 10)) !== JSON.stringify(draws(b, 10)))
        }

        function test_resetStartsTheSequenceAgain() {
            const first = draws(a, 20)
            a._advance(0.5)
            compare(a.time, 0.5)
            a.reset()
            compare(a.time, 0, "reset rewinds time")
            compare(draws(a, 20), first, "and the random stream")
        }

        function test_seedChangeResets() {
            const first = draws(a, 5)
            a._advance(1)
            a.seed = 9
            compare(a.time, 0)
            a.seed = 7
            compare(draws(a, 5), first)
        }

        function test_rangeAndGaussianComeFromTheStream() {
            const r1 = [a.randomRange(2, 4), a.randomGaussian()]
            const r2 = [b.randomRange(2, 4), b.randomGaussian()]
            compare(r1, r2)
            verify(r1[0] >= 2 && r1[0] < 4)
            verify(isFinite(r1[1]))
        }

        // The clock's own step size is 1/60, the same as the inspector's step.
        // Time is a running float sum, and without a tolerance an advance of
        // exactly one step now and then arrived as a hair less than one.
        function test_oneStepPerAdvanceOfOneStep() {
            for (let i = 0; i < 6000; ++i) {
                stepper._advance(1 / 60)
                if (stepper.count !== i + 1)
                    fail("advance " + (i + 1) + " gave " + stepper.count + " steps")
            }
            fuzzyCompare(stepper.stepped_, stepper.time, 1e-9,
                         "the steps add up to the clock's time")
        }

        function test_finerStepsLoseNoTime() {
            stepper.fixedStep = 0.01
            for (let i = 0; i < 1000; ++i) stepper._advance(1 / 60)
            compare(stepper.count, Math.floor(stepper.time / 0.01 + 1e-6))
            verify(stepper.time - stepper.stepped_ < 0.01, "less than one step is owed")
        }

        // An advance that uses up exactly the budget still owes the part of a
        // step it did not reach - which the clock used to throw away.
        function test_exactlyTheCapKeepsTheRemainder() {
            stepper.fixedStep = 0.1
            stepper.maxStepsPerAdvance = 8
            stepper._advance(0.85)          // 8 steps and half of the ninth
            compare(stepper.count, 8)
            stepper._advance(0.05)          // the other half
            compare(stepper.count, 9, "the half step carried over")
            fuzzyCompare(stepper.stepped_, stepper.time, 1e-9)
        }

        // Past the budget the backlog of whole steps is dropped (a hitch must
        // not turn into a freeze), and the step grid keeps its phase.
        function test_overTheCapDropsWholeStepsOnly() {
            stepper.fixedStep = 0.1
            stepper.maxStepsPerAdvance = 8
            stepper._advance(1.25)          // 12.5 steps due, 8 allowed
            compare(stepper.count, 8)
            stepper._advance(0.05)          // completes the half step
            compare(stepper.count, 9, "the dropped part was whole steps, not the half")
            stepper._advance(0.05)
            compare(stepper.count, 9)
        }

        function test_resetIsNeverASteppedBackwards() {
            stepper._advance(0.5)
            const n = stepper.count
            stepper.reset()
            stepper._advance(0)
            compare(stepper.count, n, "a rewind is swallowed, not replayed")
            stepper._advance(1 / 60)
            compare(stepper.count, n + 1)
        }

        // The inspector's time/step action, for a lab with no world: one
        // fixed 1/60 advance per frame asked for.
        function test_stepRequestAdvancesExactFrames() {
            const c = createTemporaryObject(liveClock, this)
            verify(c)
            compare(Lab.clock, c)
            Clayground.physicsStep(30)
            fuzzyCompare(c.time, 0.5, 1e-12)
            compare(c.count, 30)
        }
    }
}
