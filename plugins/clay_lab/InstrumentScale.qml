// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import "scale.js" as Scale

/*!
    \qmltype InstrumentScale
    \inqmlmodule Clayground.Lab
    \brief What a reading means - the measurement model every instrument face draws.

    An instrument is a model and a face, not a widget. This is the model: a
    quantity, the limits it is read against, where the round numbers are,
    whether it sits in a good, a warned or an alarming part of the scale, and
    how a real movement lags and holds its peak. \l Gauge, \l BarFace,
    \l ColumnFace and \l DigitFace only \e draw it, and any of them renders any
    scale - a music VU meter is a \l BarFace on a log scale with peak-hold, not
    a new component.

    It is not visual and has no size. Declare one beside the thing it measures
    and hand it to as many faces as the lab wants to show at once; they all
    agree, because there is only one reading.

    Three ways to say what the limits are:

    \list
    \li \l min and \l max - a fixed scale (a thermometer, a dB meter).
    \li \l ranges - a self-ranging bench meter: the smallest of the offered
        full-scale values the reading still fits in is selected, and
        \l rangeText names it.
    \li \l logScale on top of either - equal ratios then take equal space,
        which is what a level meter needs.
    \endlist

    Example usage:
    \qml
    import Clayground.Lab

    InstrumentScale {
        id: windScale
        probe: "windSpeed"          // or: value: sensor.speed
        unit: "m/s"
        min: 0; max: 30
        okUntil: 12; warnUntil: 20  // green / amber / red bands
        damping: 0.4                // the lag of a real movement, in seconds
    }

    ColumnFace { scale: windScale; label: "WIND" }
    DigitFace  { scale: windScale }
    \endqml

    \sa Gauge, BarFace, ColumnFace, DigitFace, InstrumentDock
*/
QtObject {
    id: root

    // --- the quantity ------------------------------------------------------

    /*!
        \qmlproperty real InstrumentScale::value
        \brief The reading. Ignored while \l probe names one.
    */
    property real value: 0

    /*!
        \qmlproperty string InstrumentScale::probe
        \brief Name of a \l Probe to read instead of \l value.

        The probe is what the plot and the run record already quote, so an
        instrument pointed at one cannot drift from the curve beside it.
        Resolved after the first turn, since probes register with \c Lab in
        their own \c Component.onCompleted.
    */
    property string probe: ""

    /*!
        \qmlproperty string InstrumentScale::unit
        \brief SI unit of the reading, e.g. \c "V".
    */
    property string unit: ""

    /*!
        \qmlproperty string InstrumentScale::symbol
        \brief What this instrument measures, as a glyph. Defaults to the unit.

        Set it when the two differ - a tachometer reading \c "/min" is still
        an \c "n".
    */
    property string symbol: unit

    /*!
        \qmlproperty int InstrumentScale::digits
        \brief Decimals in the printed reading, or -1 for three significant figures.
    */
    property int digits: -1

    // --- the limits --------------------------------------------------------

    /*!
        \qmlproperty real InstrumentScale::min
        \brief Bottom of a fixed scale.
    */
    property real min: 0

    /*!
        \qmlproperty real InstrumentScale::max
        \brief Top of a fixed scale.
    */
    property real max: 1

    /*!
        \qmlproperty var InstrumentScale::ranges
        \brief Full-scale values on offer, for a self-ranging meter.

        Non-empty turns \l min / \l max off: the scale runs from 0 to the
        smallest offered range the magnitude still fits in, exactly the way a
        bench meter's selector does. Empty (the default) is a fixed scale.
    */
    property var ranges: []

    /*!
        \qmlproperty bool InstrumentScale::logScale
        \brief Position the reading by its logarithm - equal ratios, equal space.

        A \l min of 0 is not an error here; it means four decades below the
        top, which is what a level meter shows.
    */
    property bool logScale: false

    // --- severity ----------------------------------------------------------

    /*!
        \qmlproperty real InstrumentScale::okUntil
        \brief Top of the good band. Leave unset for an instrument with no opinion.
    */
    property real okUntil: NaN

    /*!
        \qmlproperty real InstrumentScale::warnUntil
        \brief Top of the warned band.
    */
    property real warnUntil: NaN

    /*!
        \qmlproperty var InstrumentScale::zones
        \brief Explicit bands, \c {[{from, to, severity}]}, overriding \l okUntil / \l warnUntil.

        Severity is \c "ok", \c "warn" or \c "alarm". Use this for a scale
        whose good band is in the middle rather than at one end.
    */
    property var zones: []

    /*!
        \qmlproperty color InstrumentScale::accent
        \brief Colour while the instrument has no opinion.
    */
    property color accent: LabTheme.primary

    // --- dynamics ----------------------------------------------------------

    /*!
        \qmlproperty real InstrumentScale::damping
        \brief Movement time constant in seconds - the lag of a real meter.

        Exponential and frame-rate independent, so a noisy signal reads as a
        needle that hunts slightly rather than as a blur. \c 0 (the default)
        is a perfectly rigid movement, which is what a digital readout wants.
    */
    property real damping: 0

    /*!
        \qmlproperty int InstrumentScale::settleTime
        \brief Milliseconds a face takes to travel to a new reading.

        For a value that changes on an \e action - a switch closing, a scenario
        applied - the swing is worth showing. Set it to 0 for a continuously
        changing signal: an animation restarted every frame never arrives, and
        the face then visibly disagrees with the number printed on it. Use
        \l damping for that case instead.
    */
    property int settleTime: 0

    /*!
        \qmlproperty bool InstrumentScale::peakHold
        \brief Remember the highest reading and mark it.

        \l peakFraction is where the marker sits; faces that can show one
        (\l BarFace, \l ColumnFace) draw it when this is on.
    */
    property bool peakHold: false

    /*!
        \qmlproperty real InstrumentScale::peakHoldTime
        \brief Seconds the marker sits before falling.
    */
    property real peakHoldTime: 1.2

    /*!
        \qmlproperty real InstrumentScale::peakFall
        \brief How fast it then falls, in scale fractions per second.
    */
    property real peakFall: 0.35

    /*!
        \qmlproperty int InstrumentScale::tickCount
        \brief Labelled divisions a face should aim for.
    */
    property int tickCount: 6

    // --- what the faces read ----------------------------------------------

    /*!
        \qmlproperty bool InstrumentScale::autoRange
        \readonly
        \brief True while \l ranges drives the limits.
    */
    readonly property bool autoRange: ranges !== undefined && ranges !== null
                                      && ranges.length > 0

    /*!
        \qmlproperty real InstrumentScale::source
        \readonly
        \brief The raw reading, from \l probe or \l value.
    */
    readonly property real source: _probeObj ? _probeObj.value : value

    /*!
        \qmlproperty real InstrumentScale::lo
        \readonly
        \brief Bottom of the scale in force.
    */
    readonly property real lo: autoRange ? 0 : min

    /*!
        \qmlproperty real InstrumentScale::hi
        \readonly
        \brief Top of the scale in force - the selected range, when self-ranging.
    */
    readonly property real hi: autoRange ? Scale.pickRange(source, ranges) : max

    /*!
        \qmlproperty real InstrumentScale::fullScale
        \readonly
        \brief Alias of \l hi, in the language a bench meter uses.
    */
    readonly property real fullScale: hi

    /*!
        \qmlproperty real InstrumentScale::reading
        \readonly
        \brief The value as it is read against the scale.

        A self-ranging meter reads magnitudes, so this is \c {|source|} there
        and \l source itself on a fixed scale that may run negative.
    */
    readonly property real reading: autoRange ? Math.abs(source) : source

    /*!
        \qmlproperty real InstrumentScale::displayValue
        \readonly
        \brief Where the face actually points - the reading after lag and settling.
    */
    property real displayValue: damping > 0 ? _damped : reading
    Behavior on displayValue {
        enabled: root.settleTime > 0
        NumberAnimation { duration: root.settleTime }
    }

    /*!
        \qmlproperty real InstrumentScale::fraction
        \readonly
        \brief Where the face points, 0 at \l lo and 1 at \l hi.
    */
    readonly property real fraction: Scale.fractionOf(displayValue, lo, hi, logScale)

    /*!
        \qmlproperty real InstrumentScale::peakFraction
        \readonly
        \brief Where the peak marker sits, 0..1.
    */
    readonly property real peakFraction: _peak

    /*!
        \qmlproperty var InstrumentScale::zoneList
        \readonly
        \brief The bands in force, \c {[{from, to, severity}]}.
    */
    readonly property var zoneList: (zones && zones.length)
        ? zones : Scale.zonesFrom(okUntil, warnUntil, lo, hi)

    /*!
        \qmlproperty bool InstrumentScale::graded
        \readonly
        \brief True while the instrument has bands to judge by.
    */
    readonly property bool graded: zoneList.length > 0

    /*!
        \qmlproperty string InstrumentScale::severity
        \readonly
        \brief \c "ok", \c "warn" or \c "alarm".
    */
    readonly property string severity: Scale.severityAt(displayValue, zoneList)

    /*!
        \qmlproperty color InstrumentScale::severityColor
        \readonly
        \brief The colour the reading has earned - \l accent while the
        instrument is ungraded.
    */
    readonly property color severityColor: graded ? colorFor(severity) : accent

    /*!
        \qmlproperty var InstrumentScale::ticks
        \readonly
        \brief Gradations, \c {[{value, fraction, major, text}]}.

        Round numbers (1, 2, 5 and their decades) inside the limits - the
        limits are the instrument's, so a meter that says 0-2 V ends at 2 V
        rather than at whatever the tick algorithm found convenient.
    */
    readonly property var ticks: {
        const raw = Scale.ticksFor(lo, hi, tickCount, logScale)
        const step = Scale.niceStep(lo, hi, tickCount)
        return raw.map(t => ({
            value: t.value,
            major: t.major,
            fraction: Scale.fractionOf(t.value, lo, hi, logScale),
            // bare numbers, all to one precision - the unit is on the face,
            // and an axis that switches from mV to V halfway along itself is
            // two scales printed on one instrument
            text: t.major
                ? LabLang.num(t.value,
                              Scale.tickDigits(logScale ? t.value : step))
                : ""
        }))
    }

    /*!
        \qmlproperty string InstrumentScale::valueText
        \readonly
        \brief The reading as a quantity, e.g. \c "50.0 mA".
    */
    readonly property string valueText:
        LabLang.qty(reading, unit, digits < 0 ? undefined : digits)

    /*!
        \qmlproperty string InstrumentScale::rangeText
        \readonly
        \brief The scale in force, e.g. \c "0 - 10 mA".
    */
    // Deliberately NOT forced to whole numbers: a 0.5 V range rounded to no
    // decimals prints "1 V", and an instrument that names a range twice the
    // one it is actually using is worse than one that names none.
    readonly property string rangeText:
        LabLang.qty(lo, unit, digits < 0 ? undefined : digits)
        + " – " + LabLang.qty(hi, unit, digits < 0 ? undefined : digits)

    /*!
        \qmlmethod real InstrumentScale::fractionOf(real v)
        \brief Where \a v would sit on this scale, 0..1.
    */
    function fractionOf(v) { return Scale.fractionOf(v, lo, hi, logScale) }

    /*!
        \qmlmethod real InstrumentScale::valueAt(real f)
        \brief What a face's \a f along the scale reads as.
    */
    function valueAt(f) { return Scale.valueAt(f, lo, hi, logScale) }

    /*!
        \qmlmethod color InstrumentScale::colorFor(string severity)
        \brief The theme colour for \c "ok", \c "warn" or \c "alarm".
    */
    function colorFor(sev) {
        if (sev === "alarm") return LabTheme.alarm
        if (sev === "warn") return LabTheme.highlight
        return LabTheme.tertiary
    }

    /*!
        \qmlmethod color InstrumentScale::colorAt(real v)
        \brief The colour a reading of \a v has earned on this scale.
    */
    function colorAt(v) {
        return graded ? colorFor(Scale.severityAt(v, zoneList)) : accent
    }

    /*!
        \qmlmethod void InstrumentScale::reset()
        \brief Drops the lag and the held peak - use it at a scenario boundary.
    */
    // Deliberately does NOT assign displayValue: that property carries a
    // binding, and assigning to it would replace the binding with a constant -
    // the face would then be frozen at the value it was reset to.
    function reset() {
        _damped = reading
        _peak = fractionOf(reading)
        _peakAge = 0
    }

    // --- the movement ------------------------------------------------------
    //
    // One ticker for both dynamics, running only while something needs it. A
    // meter with no lag and no peak marker costs nothing.

    property real _damped: 0
    property real _peak: 0
    property real _peakAge: 0
    property real _lastTick: 0

    readonly property bool _moving: damping > 0 || peakHold

    property Timer _ticker: Timer {
        interval: 16
        repeat: true
        running: root._moving
        onTriggered: root._advance()
        // a stale stamp from the last time the instrument moved would arrive
        // as one enormous first step
        onRunningChanged: root._lastTick = 0
    }

    function _tickSeconds() { return _ticker.interval / 1000 }

    function _advance() {
        const now = Date.now()
        // The first tick after the ticker starts has no previous stamp, and a
        // dt of "since the epoch" would slam both filters to their target.
        let dt = _lastTick > 0 ? (now - _lastTick) / 1000 : _tickSeconds()
        _lastTick = now
        // A window that was hidden or a scene that stalled must not arrive as
        // one enormous step either: that is the lag disappearing exactly when
        // the reading jumped, which is the moment it was there to smooth.
        if (!(dt > 0)) dt = _tickSeconds()
        if (dt > 0.25) dt = 0.25
        if (damping > 0) _damped = Scale.lowPass(_damped, reading, damping, dt)
        if (peakHold) {
            const st = Scale.peakStep(_peak, _peakAge, fraction, dt,
                                      peakHoldTime, peakFall)
            _peak = st.peak
            _peakAge = st.age
        }
    }

    // --- the probe ---------------------------------------------------------

    property var _probeObj: null

    // Deferred by a Timer rather than by Qt.callLater: a Probe registers with
    // Lab in its own onCompleted, which has not run yet when the scale beside
    // it completes - but a callLater closure outlives the object it captured,
    // and a lab that creates and destroys instruments as parts come and go
    // (the circuit kit's meters do exactly that) then evaluates it in a dead
    // context. A Timer is a child, so it dies with the scale.
    property Timer _resolver: Timer {
        interval: 0
        repeat: false
        onTriggered: root._resolveProbe()
    }

    function _resolveProbe() {
        _probeObj = probe !== "" ? Lab.probe(probe) : null
        reset()
    }

    onProbeChanged: {
        if (probe === "") _probeObj = null
        else _resolver.restart()
    }

    Component.onCompleted: {
        reset()
        if (probe !== "") _resolver.restart()
    }
}
