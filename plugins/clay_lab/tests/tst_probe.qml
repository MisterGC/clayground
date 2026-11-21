// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A probe is sampled on the clock's sample grid, not on frames: that grid is
// what makes two runs' series line up sample for sample (#532).

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 50; height: 50

    property real level: 0

    SimClock { id: clock; seed: 5; timeScale: 0; sampleInterval: 0.25 }

    Probe { id: levelProbe; name: "tstLevel"; unit: "m"; expr: () => root.level }
    Probe { id: gappy; name: "tstGappy"; expr: () => root.level > 0.4 ? NaN : root.level }
    Probe { id: small; name: "tstSmall"; capacity: 3; expr: () => root.level }

    TestCase {
        name: "Probe"

        function init() {
            clock.sampleInterval = 0.25
            root.level = 0
            clock.reset()
        }

        function times(p) { return p.samples.map(s => s.t) }

        function test_registeredWithLab() {
            compare(Lab.probe("tstLevel"), levelProbe)
            verify(Lab.probeNames.indexOf("tstLevel") !== -1)
        }

        function test_samplesAtTheSampleInterval() {
            // frames of 1/60 do not divide 0.25: the grid must not follow them
            for (let i = 0; i < 60; ++i) {
                root.level = clock.time
                clock._advance(1 / 60)
            }
            const t = times(levelProbe)
            compare(t.length, 5, "t = 0, 0.25, 0.5, 0.75, 1.0 in one second")
            for (let i = 0; i < t.length; ++i)
                fuzzyCompare(t[i], i * 0.25, 1e-9)
        }

        function test_followsAChangedInterval() {
            clock.sampleInterval = 0.1
            clock.reset()
            for (let i = 0; i < 10; ++i) clock._advance(0.05)
            compare(times(levelProbe).length, 6, "0 .. 0.5 at 0.1")
        }

        function test_oneLongAdvanceStillFillsTheGrid() {
            clock._advance(1.0)
            compare(times(levelProbe).length, 5)
        }

        function test_valueIsTheLatestSample() {
            root.level = 3
            clock._advance(0.3)
            compare(levelProbe.value, 3)
            compare(levelProbe.summary().count, 2)
            compare(levelProbe.summary().last, 3)
        }

        function test_resetClearsSamples() {
            clock._advance(1)
            verify(levelProbe.samples.length > 0)
            clock.reset()
            compare(levelProbe.samples.length, 0)
            compare(levelProbe.value, 0)
        }

        // a reading that is not a number is a dropout, not a zero
        function test_nonFiniteIsNotRecorded() {
            root.level = 0.5
            clock._advance(1)
            compare(gappy.samples.length, 0)
            compare(levelProbe.samples.length, 5)
        }

        function test_capacityKeepsTheNewest() {
            clock._advance(1)
            compare(times(small).length, 3)
            fuzzyCompare(small.samples[2].t, 1.0, 1e-9)
        }
    }
}
