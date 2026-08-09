// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype Stopwatch
    \inqmlmodule Clayground.Lab
    \inherits HandheldInstrument
    \brief How long something took, in \e simulated seconds: click to start,
    click to stop.

    The second instrument the kernel ships, and the one that shows the handheld
    contract is about binding rather than about pointing: a stopwatch picks
    \e moments instead of places. The click is the same click - marking \e now
    is as much a pick as marking a spot on the ground - so it needs no gesture
    of its own, no mode of its own and no code in the input layer. Only
    \l {HandheldInstrument::pickKind}{pickKind} differs, and with it the fact
    that where the cursor was is ignored.

    It runs on \l SimClock time, never on the wall clock. That is not a detail:
    a lab's whole determinism contract is that a seeded run replays identically,
    and a stopwatch reading in real seconds would be the one number in the
    building that changed between two runs of the same experiment. Pausing the
    lab pauses the watch, stepping the lab steps it.

    Third click starts a fresh timing - the instrument is never in a state
    where a click does nothing.

    \sa HandheldInstrument, InstrumentBelt, SimClock
*/
HandheldInstrument {
    id: root

    name: "time"
    label: LabLang.t("hand.stopwatch")
    glyph: "⏱"
    pickKind: "moment"
    maxPicks: 2
    unit: "s"
    tone: LabTheme.secondary
    hint: "hand.hint.clock"

    /*! \qmlproperty bool Stopwatch::running \readonly \brief Started and not yet stopped. */
    readonly property bool running: count === 1

    /*! \qmlproperty bool Stopwatch::stopped \readonly \brief A completed timing is on the face. */
    readonly property bool stopped: count === 2

    readonly property real _now: Lab.clock ? Lab.clock.time : 0

    value: count === 0 ? 0
         : running ? Math.max(0, _now - picks[0])
         : picks[1] - picks[0]

    valueText: count === 0 ? "" : LabLang.qty(value, unit)

    // A pinned stopwatch keeps the interval it measured - the two moments are
    // over, so there is nothing left to keep asking.
    function sampler(snapshot) {
        const d = snapshot.length >= 2 ? snapshot[1] - snapshot[0] : 0
        return () => d
    }

    function info() {
        return { name: name, kind: pickKind, count: count, unit: unit,
                 value: value, text: valueText,
                 running: running, from: count > 0 ? picks[0] : null,
                 to: stopped ? picks[1] : null,
                 pinned: pinnedReadings.map(p => p.name) }
    }

    // The clock rewinding is the one thing that invalidates a timing outright:
    // its start moment no longer exists on the timeline it was taken from.
    Connections {
        target: Lab.clock
        ignoreUnknownSignals: true
        function onWasReset() { root.clear() }
    }

    // --- the face -----------------------------------------------------------
    // Centred at the top, under the lab's transport chip: the elapsed time is
    // the thing being watched while it runs, not a detail to be found - and
    // sitting directly beneath the sim clock it is timing is the right place
    // for it, since the two numbers are read together.
    Rectangle {
        visible: root.held && root.count > 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: LabTheme.px(104)
        width: _row.width + 2 * LabTheme.spaceXl
        height: _row.height + 2 * LabTheme.spaceM
        radius: LabTheme.radius
        color: root.running ? root.tone : LabTheme.panel
        border.color: root.tone
        border.width: LabTheme.borderWidth
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: _row
            anchors.centerIn: parent
            spacing: LabTheme.spaceM
            Text {
                anchors.verticalCenter: parent.verticalCenter
                // filled while it runs, hollow once it has stopped - the same
                // language a recording indicator uses
                text: root.running ? "⏵" : "⏸"
                color: LabTheme.inkOn(parent.parent.color)
                font.pixelSize: LabTheme.fontLabel
                font.family: LabTheme.monoFont
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.valueText
                color: LabTheme.inkOn(parent.parent.color)
                font.pixelSize: LabTheme.fontTitle
                font.bold: true
                font.family: LabTheme.monoFont
            }
        }
    }
}
