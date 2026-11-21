// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Lab.run() and Lab.schema() (#567): one call runs an experiment, one call
// says what a lab can be asked. What a run must not do is start from what the
// previous one left behind - a parameter still set, a clock still running on,
// samples of the warm-up in its summary.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 50; height: 50

    // timeScale 0: the frame ticker adds nothing, sim time moves only where
    // a test (or Lab.run) moves it
    SimClock { id: clock; seed: 7; sampleInterval: 0.1; timeScale: 0 }

    Parameter {
        id: pGain
        name: "tstRunGain"; value: 2; from: 0; to: 10; stepSize: 0.5
        unit: "V"; description: "how loud the signal is"
    }
    Parameter { id: pOffset; name: "tstRunOffset"; value: 0; from: -10; to: 10 }

    Probe { name: "tstRunSignal"; unit: "V"; expr: () => pOffset.value + pGain.value * clock.random() }
    Probe { name: "tstRunTime"; unit: "s"; expr: () => clock.time }

    ScenarioSet {
        id: scenarioSet
        Scenario { name: "tstRunCalm" }
        // a scenario that sets a parameter of its own: a run's reset to the
        // defaults must come before it, not undo it
        Scenario { name: "tstRunLoud"; script: () => Lab.set("tstRunOffset", 5) }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }

    TestCase {
        name: "LabRun"

        property var wasHost: null
        property var wasClock: null

        function init() {
            wasHost = Lab.host; wasClock = Lab.clock
            Lab.host = root; Lab.clock = clock
            Lab.resetParameters()
        }
        function cleanup() { Lab.host = wasHost; Lab.clock = wasClock }

        function opts(extra) {
            return Object.assign({ scenario: "tstRunCalm", seed: 3,
                                   probes: ["tstRunSignal", "tstRunTime"],
                                   warmupSteps: 60, steps: 120 }, extra ?? {})
        }

        function test_schemaListsParametersProbesAndScenarios() {
            const s = Lab.schema()
            const g = s.params.find(p => p.name === "tstRunGain")
            compare(g, { name: "tstRunGain", value: 2, defaultValue: 2, from: 0,
                         to: 10, stepSize: 0.5, unit: "V",
                         description: "how loud the signal is" })
            compare(s.probes.find(p => p.name === "tstRunSignal"),
                    { name: "tstRunSignal", unit: "V" })
            compare(s.scenarios, ["tstRunCalm", "tstRunLoud"])
            compare(s.clock, { seed: clock.seed, sampleInterval: 0.1, fixedStep: 0 })
        }

        function test_summaryIsOverTheRecordedStepsOnly() {
            const r = Lab.run(opts())
            verify(!r.error, r.error)
            compare(r.scenario, "tstRunCalm")
            compare(r.seed, 3)
            compare(r.steps, 120)
            compare(r.warmupSteps, 60)
            const t = r.probes.tstRunTime
            // warm-up ends at 1 s, the sample AT 1 s is the warm-up's; the
            // recorded ones are 1.1 .. 3.0
            compare(t.count, 20)
            fuzzyCompare(t.first, 1.1, 1e-9)
            fuzzyCompare(t.last, 3.0, 1e-9)
            compare(t.unit, "s")
            fuzzyCompare(r.duration, 2, 1e-9)
            verify(r.series === undefined, "no series unless asked")
            compare(Object.keys(r.probes).sort(), ["tstRunSignal", "tstRunTime"])
        }

        function test_aRunIsRepeatableAndLeavesNothingBehind() {
            const a = Lab.run(opts({ params: { tstRunGain: 4 } }))
            // whatever happens between runs: time on, a parameter changed
            clock._advance(3.3)
            Lab.set("tstRunOffset", 9)
            const b = Lab.run(opts({ params: { tstRunGain: 4 } }))
            compare(JSON.stringify(b), JSON.stringify(a))
            compare(b.params.tstRunOffset, 0, "an unnamed parameter starts from its default")
            compare(b.params.tstRunGain, 4)
        }

        function test_theSeedDecides() {
            const a = Lab.run(opts({ seed: 1 }))
            const b = Lab.run(opts({ seed: 2 }))
            verify(a.probes.tstRunSignal.mean !== b.probes.tstRunSignal.mean)
        }

        function test_aScenarioMaySetParametersOfItsOwn() {
            const r = Lab.run(opts({ scenario: "tstRunLoud" }))
            compare(r.params.tstRunOffset, 5)
            verify(r.probes.tstRunSignal.min >= 5)
        }

        function test_aRunLongerThanTheRingIsSummarizedInFull() {
            // 0.1 s samples over 150 s, the one at 0 included (without a
            // warm-up the start is part of the run, as in a record) = 1501
            // samples; a probe keeps 1200
            const r = Lab.run(opts({ warmupSteps: 0, steps: 9000, series: true }))
            compare(r.probes.tstRunTime.count, 1501)
            compare(r.series.tstRunTime.length, 1501)
            compare(r.series.tstRunTime[0][0], 0)
            fuzzyCompare(r.probes.tstRunTime.mean, 75, 1e-4)   // time is a running float sum
            compare(Lab.probe("tstRunTime").samples.length, 1200)
        }

        function test_stepHzSetsTheStep() {
            const r = Lab.run(opts({ warmupSteps: 0, steps: 10, stepHz: 10 }))
            compare(r.stepSize, 0.1)
            compare(r.probes.tstRunTime.count, 11, "0 s to 1 s at 0.1 s")
            fuzzyCompare(r.duration, 1, 1e-9)
        }

        function test_wrongOptionsRunNothing() {
            Lab.run(opts())
            const before = clock.time
            const cases = [
                [{ params: { tstRunGain: 12 } }, /tstRunGain cannot be 12 - its range is 0 to 10/],
                [{ params: { tstRunNowhere: 1 } }, /no parameter 'tstRunNowhere'/],
                [{ probes: ["tstRunNowhere"] }, /no probe 'tstRunNowhere'/],
                [{ scenario: "tstRunNowhere" }, /no scenario 'tstRunNowhere'; the lab has: \[tstRunCalm, tstRunLoud\]/],
                [{ steps: 1.5 }, /steps must be a whole number/],
                [{ stepHz: 0 }, /stepHz must be above 0/]
            ]
            for (const [extra, want] of cases) {
                const r = Lab.run(opts(extra))
                verify(want.test(r.error), JSON.stringify(extra) + " -> " + r.error)
                compare(Object.keys(r), ["error"])
            }
            compare(clock.time, before, "nothing was stepped")
        }

        function test_aScenarioNeedsAHost() {
            Lab.host = null
            const r = Lab.run(opts())
            verify(/no host/.test(r.error), r.error)
        }
    }
}
