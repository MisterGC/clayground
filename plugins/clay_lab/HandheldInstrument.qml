// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype HandheldInstrument
    \inqmlmodule Clayground.Lab
    \brief An instrument the viewer picks up, applies to the scene, and puts down.

    The other kind of instrument. A \l Gauge or a \l DockedInstrument is
    \e mounted: the lab author bound what it measures when the lab was written,
    and it reads for the whole run. This is the half that was missing - the
    user binds the subject at runtime, by pointing, and the reading dies with
    the gesture. A tape measure, a voltmeter held across two terminals, a
    stopwatch.

    \section2 The contract

    A handheld declares three things and inherits everything else:

    \list
    \li \l pickKind - what a click contributes: a \c "point" on the ground, an
        \c "object" in the scene, or a \c "moment" in sim time (the click's
        position is then ignored - marking \e now is still a click).
    \li \l maxPicks - how many it takes; 0 is a chain with no end. A full
        instrument starts a fresh subject on the next pick rather than
        refusing it, because refusing looks broken.
    \li \l value / \l valueText - the reading, computed from \l picks.
    \endlist

    It handles no input and knows nothing about the camera: the
    \l InstrumentBelt forwards \c {OrbitInput3D::picked} to whichever
    instrument is held. That is the acceptance test for this contract - a new
    instrument is one file that says what it picks and what that means, with
    no gesture code in it.

    \section2 Pinning

    \l pin() is the one transition out: it snapshots the subject, registers a
    \l Probe under the given name, and from that moment the reading is sampled
    on the sim clock's grid like any other - so it lands in the run record and
    a paper can cite it. Pinning asks for the name because that name is what
    gets cited; a column called \c measure_1 is a bad citation forever.

    A subclass says how a pinned reading keeps reading by overriding
    \l sampler(): the default freezes the value it had, which is right for a
    tape measure between two fixed points and wrong for a voltmeter, which
    overrides it with a closure that keeps asking the circuit.

    \qml
    HandheldInstrument {
        name: "tape"; label: LabLang.t("hand.tape"); glyph: "\u{1F4CF}"
        pickKind: "point"
        value: Measure.total(picks)
    }
    \endqml

    \sa InstrumentBelt, TapeMeasure, Stopwatch, Probe
*/
Item {
    id: root

    // Instruments fill the belt, which fills the View3D: an instrument's own
    // face can then anchor itself (the stopwatch's readout centres near the
    // top), and a screen-space overlay drawn at (0, 0) is at the view's
    // (0, 0). Without this an instrument is a zero-sized item at the origin
    // and every anchored face lands in the top-left corner - which is exactly
    // where the stopwatch first appeared.
    anchors.fill: parent

    /*!
        \qmlproperty string HandheldInstrument::name
        \brief Id-like name, language-neutral - what a pinned probe is named after.
    */
    property string name: ""

    /*! \qmlproperty string HandheldInstrument::label \brief Belt caption, already translated. */
    property string label: ""

    /*! \qmlproperty string HandheldInstrument::glyph \brief One character for the belt chip. */
    property string glyph: "●"

    /*! \qmlproperty string HandheldInstrument::unit \brief Unit of \l value, e.g. \c "m", \c "V", \c "s". */
    property string unit: ""

    /*! \qmlproperty color HandheldInstrument::tone \brief The instrument's ink. */
    property color tone: LabTheme.primary

    /*!
        \qmlproperty string HandheldInstrument::hint
        \brief One line describing what a click does with this in hand.

        A LabLang key, for the lab's hint bar. It lives on the instrument
        because only the instrument knows: "click measures" is a lie while a
        stopwatch is out.
    */
    property string hint: "mode.hint.hand"

    /*!
        \qmlproperty string HandheldInstrument::pickKind
        \brief \c "point", \c "object" or \c "moment".
    */
    property string pickKind: "point"

    /*! \qmlproperty int HandheldInstrument::maxPicks \brief How many picks make a subject; 0 is unbounded. */
    property int maxPicks: 0

    /*!
        \qmlproperty var HandheldInstrument::picks
        \readonly
        \brief The subject so far - points, objects or moments, per \l pickKind.
    */
    readonly property alias picks: _s.picks

    /*! \qmlproperty int HandheldInstrument::count \readonly \brief How many picks the subject has. */
    readonly property int count: _s.picks.length

    /*! \qmlproperty bool HandheldInstrument::empty \readonly \brief Nothing picked yet. */
    readonly property bool empty: count === 0

    /*! \qmlproperty bool HandheldInstrument::full \readonly \brief \l maxPicks reached. */
    readonly property bool full: maxPicks > 0 && count >= maxPicks

    /*!
        \qmlproperty bool HandheldInstrument::held
        \brief The belt has this one in hand. Set by the belt, read by the visuals.
    */
    property bool held: false

    /*!
        \qmlproperty var HandheldInstrument::view
        \brief The \c View3D the picks came from - what the visuals project through.
    */
    property var view: null

    /*! \qmlproperty real HandheldInstrument::value \brief The reading. Bind it. */
    property real value: 0

    /*!
        \qmlproperty string HandheldInstrument::valueText
        \brief The reading as text; defaults to \l value in \l unit.
    */
    property string valueText: count > 0 ? LabLang.qty(value, unit) : ""

    /*! \qmlproperty bool HandheldInstrument::pinnable \readonly \brief There is a reading worth keeping. */
    readonly property bool pinnable: !empty && name !== ""

    /*!
        \qmlproperty bool HandheldInstrument::clearOnPutAway
        \brief Putting the instrument away ends the measurement.

        True, and deliberately: a measurement belongs to the moment it is
        taken, and a tape measure found still stretched across the scene after
        a detour is a question nobody is asking any more.
    */
    property bool clearOnPutAway: true

    /*!
        \qmlmethod void HandheldInstrument::add(var pick)
        \brief Contributes one pick, per \l pickKind. What the belt calls.

        A pick that does not carry what this instrument needs - no ground
        point under a \c "point" instrument, nothing hit under an
        \c "object" one - is ignored rather than stored as a hole.
    */
    function add(pick) {
        const v = _valueOf(pick)
        if (v === null) return
        // a full instrument starts a new subject rather than refusing the
        // click: the click plainly meant something, and doing nothing reads
        // as a broken tool
        if (full) _s.picks = []
        _s.picks = _s.picks.concat([v])
    }

    function _valueOf(pick) {
        if (pickKind === "moment") return Lab.clock ? Lab.clock.time : 0
        if (!pick) return null
        if (pickKind === "object") return pick.object ? pick.object : null
        if (!pick.point) return null
        const p = pick.point
        return Qt.vector3d(p.x, p.y === undefined ? 0 : p.y, p.z)
    }

    /*! \qmlmethod void HandheldInstrument::undo() \brief Takes the last pick back. */
    function undo() {
        if (_s.picks.length === 0) return
        _s.picks = _s.picks.slice(0, _s.picks.length - 1)
    }

    /*! \qmlmethod void HandheldInstrument::clear() \brief Ends the measurement. */
    function clear() {
        if (_s.picks.length === 0) return
        _s.picks = []
    }

    /*!
        \qmlmethod var HandheldInstrument::sampler(var snapshot)
        \brief Returns the function a pinned probe samples. Override to keep reading.

        \a snapshot is a copy of \l picks taken at the moment of pinning. The
        default returns the value frozen at that moment, which is correct for
        anything whose subject cannot change; an instrument bound to something
        live overrides it and closes over \a snapshot instead.
    */
    function sampler(snapshot) {
        const frozen = value
        return () => frozen
    }

    /*!
        \qmlmethod string HandheldInstrument::suggestedName()
        \brief The name \l pin() offers - \l name plus a counter.
    */
    function suggestedName() { return name + "_" + (_s.pins + 1) }

    /*!
        \qmlmethod bool HandheldInstrument::pin(string probeName)
        \brief Keeps this reading: registers a \l Probe that goes on sampling it.

        The one way a handheld reading becomes mounted, and therefore the one
        way it reaches a run record. Returns false when there is nothing to
        pin. The measurement itself is ended by pinning - what was a question
        is now an instrument, and leaving both on screen says the same thing
        twice.
    */
    function pin(probeName) {
        if (!pinnable) return false
        const nm = (probeName === undefined || probeName === "")
                   ? suggestedName() : probeName
        const snapshot = _s.picks.slice()
        const fn = sampler(snapshot)
        const p = _probeComp.createObject(root, { name: nm, unit: root.unit, expr: fn })
        if (!p) return false
        _s.pins += 1
        _s.pinnedList = _s.pinnedList.concat([{ name: nm, probe: p, at: snapshot,
                                                text: valueText }])
        pinned(nm)
        clear()
        return true
    }

    /*!
        \qmlproperty var HandheldInstrument::pinnedReadings
        \readonly
        \brief What has been pinned from this instrument: \c {[{name, at, text}]}.
    */
    readonly property alias pinnedReadings: _s.pinnedList

    /*! \qmlsignal HandheldInstrument::pinned(string probeName) \brief A reading was kept. */
    signal pinned(string probeName)

    /*! \qmlmethod var HandheldInstrument::info() \brief The reading as plain values, for an agent or a test. */
    function info() {
        return { name: name, kind: pickKind, count: count, unit: unit,
                 value: value, text: valueText,
                 pinned: _s.pinnedList.map(p => p.name) }
    }

    onHeldChanged: if (!held && clearOnPutAway) clear()

    QtObject {
        id: _s
        property var picks: []
        property int pins: 0
        property var pinnedList: []
    }

    Component {
        id: _probeComp
        Probe {}
    }
}
