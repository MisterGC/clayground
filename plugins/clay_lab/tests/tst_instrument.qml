// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The instrument foundation's QML half. scale.test.js already checks the
// arithmetic with no engine running; what is left here is the wiring, which is
// where the failures are silent rather than wrong:
//
//   - a self-ranging scale re-selects its range as the reading grows, and
//     everything downstream (fraction, ticks, printed range) has to follow in
//     the same turn;
//   - a face is supposed to draw ANY scale, so a Gauge handed a shared one
//     must stop reading its own value property;
//   - a put-away instrument has to actually leave the column and come back
//     through the tray, and the visible set has to survive viewState().

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 400; height: 400

    InstrumentScale {
        id: meter
        value: 0.05
        unit: "A"
        ranges: [0.01, 0.1, 1, 10]
    }

    InstrumentScale {
        id: fixed
        value: -21
        unit: "dB"
        min: -48; max: 6
        okUntil: -6; warnUntil: 0
    }

    InstrumentScale {
        id: level
        value: 0.1
        min: 0; max: 1
        logScale: true
    }

    Gauge {
        id: ownGauge
        value: 0.5
        unit: "V"
        ranges: [1, 2]
    }

    Gauge {
        id: sharedGauge
        value: 999            // must be ignored: it was handed a scale
        scale: meter
    }

    BarFace { id: bar; width: 200; scale: fixed }
    ColumnFace { id: column; height: 200; scale: fixed }
    DigitFace { id: digits; scale: meter }

    InstrumentDock {
        id: dock
        itemWidth: 180
        DockedInstrument { id: dA; key: "a"; label: "ALPHA"; Item { width: 10; height: 20 } }
        DockedInstrument { id: dB; key: "b"; label: "BETA"; Item { width: 10; height: 20 } }
        DockedInstrument { id: dC; key: "c"; label: "GAMMA"; Item { width: 10; height: 20 } }
    }

    TestCase {
        name: "InstrumentFoundation"
        when: windowShown

        function init() { dock.showAll() }

        // --- the scale -----------------------------------------------------

        function test_selfRangingFollowsTheReading() {
            meter.value = 0.05
            compare(meter.hi, 0.1)
            compare(meter.lo, 0)
            verify(meter.autoRange)
            // the needle sits half way up the 100 mA range
            fuzzyCompare(meter.fraction, 0.5, 1e-6)

            // grown past it, the meter switches range and the needle drops
            // back - which is exactly what a bench meter does
            meter.value = 0.5
            compare(meter.hi, 1)
            fuzzyCompare(meter.fraction, 0.5, 1e-6)

            meter.value = 0.05
            compare(meter.hi, 0.1)
        }

        function test_theRangeIsPrintedInTheReadingsOwnUnit() {
            meter.value = 0.05
            compare(meter.valueText, "50.0 mA")
            verify(meter.rangeText.indexOf("mA") !== -1)
        }

        function test_aFixedScaleMapsAndGrades() {
            fixed.value = -21
            fuzzyCompare(fixed.fraction, 0.5, 1e-6)
            verify(fixed.graded)
            compare(fixed.severity, "ok")

            fixed.value = -3
            compare(fixed.severity, "warn")
            compare(fixed.severityColor, LabTheme.highlight)

            fixed.value = 4
            compare(fixed.severity, "alarm")
            compare(fixed.severityColor, LabTheme.alarm)
        }

        function test_anUngradedScaleKeepsItsAccent() {
            verify(!meter.graded)
            compare(meter.severity, "ok")
            compare(meter.severityColor, meter.accent)
        }

        function test_ticksStayInsideTheLimitsAndCarryNumbers() {
            fixed.value = 0
            verify(fixed.ticks.length > 2)
            for (const t of fixed.ticks) {
                verify(t.value >= fixed.lo - 1e-9)
                verify(t.value <= fixed.hi + 1e-9)
                verify(t.fraction >= -1e-9 && t.fraction <= 1 + 1e-9)
            }
            verify(fixed.ticks.some(t => t.major && t.text !== ""))
        }

        function test_theTicksFollowASwitchedRange() {
            meter.value = 0.05
            const small = meter.ticks[meter.ticks.length - 1].value
            meter.value = 5
            const large = meter.ticks[meter.ticks.length - 1].value
            verify(large > small)
            meter.value = 0.05
        }

        function test_aLogScalePutsEqualRatiosInEqualSpace() {
            level.value = 0.01
            const a = level.fraction
            level.value = 0.1
            const b = level.fraction
            level.value = 1
            const c = level.fraction
            fuzzyCompare(b - a, c - b, 1e-6)
        }

        // --- the faces -----------------------------------------------------

        function test_aGaugeWithoutAScaleBuildsItsOwn() {
            ownGauge.value = 0.5
            compare(ownGauge.fullScale, 1)
            fuzzyCompare(ownGauge._fraction, 0.5, 1e-6)
            ownGauge.value = 1.5
            compare(ownGauge.fullScale, 2)
        }

        function test_aGaugeHandedAScaleDrawsThatOne() {
            meter.value = 0.05
            // its own value property is 999 and must not appear anywhere
            compare(sharedGauge.fullScale, 0.1)
            fuzzyCompare(sharedGauge._fraction, 0.5, 1e-6)
            compare(sharedGauge.valueText, "50.0 mA")
        }

        function test_everyFaceOnOneScaleAgrees() {
            fixed.value = -21
            compare(bar.scale, column.scale)
            fuzzyCompare(bar._fraction, column._fraction, 1e-9)
            fuzzyCompare(bar._fraction, fixed.fraction, 1e-9)
        }

        function test_facesHaveASizeOfTheirOwn() {
            verify(bar.implicitHeight > 0)
            verify(column.implicitWidth > 0)
            verify(digits.implicitWidth > 0)
            verify(digits.implicitHeight > 0)
        }

        // --- the dock ------------------------------------------------------

        function test_everyInstrumentRegistersWithTheDock() {
            compare(dock.keys().length, 3)
            compare(dock.labelOf("b"), "BETA")
            compare(dock.labelOf("nope"), "nope")
        }

        function test_puttingOneAwayRemovesItFromTheColumn() {
            verify(dB.visible)
            dock.hide("b")
            verify(!dock.isShown("b"))
            verify(!dB.visible)
            verify(dA.visible && dC.visible)
            // and the tray can still name it, which is the point of the
            // registry: a walk of the column no longer finds it
            compare(dock.labelOf("b"), "BETA")

            dock.show("b")
            verify(dB.visible)
        }

        function test_theVisibleSetSurvivesViewState() {
            dock.hide("a")
            dock.hide("c")
            const s = dock.viewState()
            compare(s.hidden.length, 2)

            dock.showAll()
            verify(dock.isShown("a"))

            dock.applyViewState(s)
            verify(!dock.isShown("a"))
            verify(!dock.isShown("c"))
            verify(dock.isShown("b"))
        }

        function test_hidingTwiceIsNotTwoEntries() {
            dock.hide("a")
            dock.hide("a")
            compare(dock.hidden.length, 1)
        }

        // A Column re-lays out in the polish phase, not on assignment, so the
        // height read in the same turn is still the previous one.
        function test_theDockShrinksAroundWhatIsLeft() {
            dock.showAll()
            wait(50)
            const full = dock.height
            verify(full > 0)
            dock.hide("a"); dock.hide("b"); dock.hide("c")
            wait(50)
            verify(dock.height < full, "full " + full + " -> " + dock.height)
        }
    }
}
