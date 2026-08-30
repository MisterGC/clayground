// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "strings.js" as Strings

// The kernel's own showcase: a damped oscillator with a noisy measurement,
// used as an excuse to put every instrument on one page. Nothing here is 3D
// and nothing here is domain-specific - it is the shelf, laid out.
//
// It doubles as the visual test bed for the chrome: everything is sized from
// LabTheme's tokens and coloured from its palette, so rendering this file at
// two scales in two themes is the fastest way to see whether either is broken.
//
// Keys: 1..3 presets · P pause · T tour · ? keys · Ctrl+Plus/Minus/0 text size
Rectangle {
    id: sandbox
    anchors.fill: parent
    focus: true
    color: LabTheme.paper

    // --- the model ---------------------------------------------------------

    Parameter { id: pFreq; name: "frequency"; value: 0.5; from: 0.05; to: 3; unit: "Hz" }
    Parameter { id: pAmp; name: "amplitude"; value: 1; from: 0; to: 4; unit: "V" }
    Parameter { id: pDamp; name: "damping"; value: 0.08; from: 0; to: 1 }
    Parameter { id: pNoise; name: "noise"; value: 0.08; from: 0; to: 0.5; unit: "V" }

    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.05
        fixedStep: 1 / 60
        onStepped: (dt) => sandbox.stepSim(dt)
        onWasReset: sandbox.resetSim()
    }

    readonly property real envelope: pAmp.value * Math.exp(-pDamp.value * clock.time)
    readonly property real signal:
        envelope * Math.sin(2 * Math.PI * pFreq.value * clock.time)
    // the phase-space partner of the signal, so the map has something to draw
    readonly property real velocity:
        2 * Math.PI * pFreq.value * envelope
        * Math.cos(2 * Math.PI * pFreq.value * clock.time)
        - pDamp.value * signal

    // The measurement is part of the MODEL, not of the drawing - so it may
    // (and must) come from the clock's seeded stream. Decorative jitter never
    // may; that is the rule this is the legal side of.
    property real measurement: 0
    property real _measAccum: 0
    property var trail: []            // the phase trajectory, mutated in place
    property int trailRev: 0

    function resetSim() {
        measurement = 0
        _measAccum = 0
        trail = []
        trailRev++
    }

    function stepSim(dt) {
        _measAccum += dt
        if (_measAccum >= clock.sampleInterval) {
            _measAccum = 0
            measurement = signal + clock.randomGaussian() * pNoise.value
            trail.push({ x: signal, y: velocity })
            if (trail.length > 400) trail.shift()
            trailRev++
        }
    }

    Probe { name: "signal"; unit: "V"; expr: () => sandbox.signal }
    Probe { name: "envelope"; unit: "V"; expr: () => sandbox.envelope }
    Probe { name: "measured"; unit: "V"; expr: () => sandbox.measurement }
    // the band's half-width: a probe of its own, which is how Plot2D takes it
    Probe { name: "sigma"; unit: "V"; expr: () => pNoise.value }
    Probe { name: "energy"; unit: ""; expr: () => sandbox.envelope * sandbox.envelope }

    // --- scenarios ---------------------------------------------------------

    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "intro"
            description: "a lightly damped ring"
            script: () => {
                Lab.set("frequency", 0.5); Lab.set("amplitude", 1)
                Lab.set("damping", 0.08); Lab.set("noise", 0.15)
                monitor.watchOnly(["signal"])
            }
        }
        Scenario {
            name: "heavy"
            description: "damping up, the envelope collapses"
            script: () => {
                Lab.set("frequency", 0.9); Lab.set("amplitude", 1.4)
                Lab.set("damping", 0.55); Lab.set("noise", 0.04)
                monitor.watchOnly(["signal", "envelope"])
            }
        }
        Scenario {
            name: "loud"
            description: "past the meter's top range"
            script: () => {
                Lab.set("frequency", 0.35); Lab.set("amplitude", 3.4)
                Lab.set("damping", 0.02); Lab.set("noise", 0.22)
                monitor.watchOnly(["signal"])
            }
        }
    }

    // --- the conventions contract -----------------------------------------

    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    function labInfo() { return Lab.labInfo() }
    function flagInfo() { return labInfo() }
    function viewState() {
        return { lab: Lab.viewState(), watched: monitor.watched.slice() }
    }
    function applyViewState(s) {
        if (!s) return
        if (s.watched) monitor.watchOnly(s.watched)
        Lab.applyViewState(s.lab)
    }
    function flowActions() {
        return {
            "setParam": (n, v) => Lab.set(n, v),
            "preset": (n) => sandbox.applyScenario(n),
            "watch": (id) => monitor.setWatched(id, true)
        }
    }
    function flows() { return [shelfFlow.flowId] }
    function startFlow(id) { if (id === shelfFlow.flowId) shelfFlow.start() }

    // what the watch loop is watching: three traces of the same experiment
    function traceValue(id, q) {
        const k = q || monitor.quantity
        if (k === "energy")
            return id === "envelope" ? envelope * envelope : signal * signal
        if (id === "envelope") return envelope
        if (id === "measured") return measurement
        return signal
    }

    Component.onCompleted: {
        LabLang.register(Strings.dict)
        forceActiveFocus()
        // Deferred by one turn on purpose: the ROOT's onCompleted runs before
        // its children's, so a Parameter has not registered with Lab yet and a
        // scenario that calls Lab.set() during the cold open warns about
        // parameters that are right there in the file. Labs whose presets only
        // poke their own properties never notice; one that tunes a Parameter
        // does, immediately.
        Qt.callLater(() => sandbox.applyScenario("intro"))
    }

    // Turned up far enough, the instrument column alone is nearly as tall as
    // the window. Rather than squeeze the plots into the sliver below it, the
    // page reflows: the plot row moves from UNDER the instrument column to
    // BESIDE it, and the captions - the one thing here that is commentary
    // rather than instrument - step aside. A scale control that breaks the
    // layout it exists to fix would be worse than no scale control.
    readonly property bool roomy: height >= LabTheme.px(770)

    // --- left column: the instruments -------------------------------------

    LabPanel {
        id: gaugePanel
        x: LabTheme.spaceXl; y: LabTheme.spaceXl
        width: LabTheme.px(214)
        title: LabLang.t("gauge.title")

        Gauge {
            width: gaugePanel.body.width
            height: LabTheme.px(112)
            symbol: "V"
            unit: "V"
            // the ranges a bench meter of this kind would have. It tops out
            // at 2 V on purpose: the "over range" preset then pins the needle
            // at full scale, which is a lesson an instrument that silently
            // rescales forever cannot teach.
            ranges: [0.25, 0.5, 1, 2]
            value: sandbox.signal
            accent: LabTheme.primary
            needleColor: LabTheme.clay
            showValue: true
            showFrame: false
            // a continuously moving signal: an animation restarted every frame
            // would leave the needle permanently behind its own readout
            settleTime: 0
        }
        Text {
            visible: sandbox.roomy
            width: gaugePanel.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("gauge.caption")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }

    ReadoutPanel {
        id: readout
        x: gaugePanel.x
        y: gaugePanel.y + gaugePanel.height + LabTheme.spaceL
        width: gaugePanel.width
        title: LabLang.t("readout.title")
        // the model advances in place; the clock's sampling is the signal that
        // anything read off it has changed
        revision: sandbox.trailRev
        rows: [
            { swatch: LabTheme.seriesColors[0], label: LabLang.t("readout.signal"),
              value: LabLang.qty(sandbox.signal, "V", 2) },
            { swatch: LabTheme.seriesColors[1], label: LabLang.t("readout.envelope"),
              value: LabLang.qty(sandbox.envelope, "V", 2) },
            { swatch: LabTheme.seriesColors[4], label: LabLang.t("readout.measured"),
              value: LabLang.qty(sandbox.measurement, "V", 2) },
            { showSwatch: false, label: LabLang.t("readout.noise"),
              value: "±" + LabLang.qty(pNoise.value, "V", 2) },
            { showSwatch: false, label: LabLang.t("readout.mean"),
              value: LabLang.qty(sandbox.signalMean, "V", 2),
              valueColor: LabTheme.inkFaint }
        ]

        // The whole of the energy, and where it went. A BudgetBar inside a
        // readout is the pattern the labs converged on: the numbers say what
        // is happening, the bar says what it means.
        BudgetBar {
            width: readout.body.width
            unit: ""
            decimals: 2
            total: Math.max(1e-6, pAmp.value * pAmp.value)
            segments: [
                { label: "budget.stored", value: sandbox.envelope * sandbox.envelope,
                  color: LabTheme.tertiary },
                { label: "budget.lost",
                  value: Math.max(0, pAmp.value * pAmp.value
                                     - sandbox.envelope * sandbox.envelope),
                  color: LabTheme.accent }
            ]
        }

        Item { width: 1; height: LabTheme.spaceXs }

        // The watch loop's object end: each chip wears the name of its trace
        // and fills with the colour that trace then wears on the plot.
        //
        // A Grid rather than a QtQuick Flow on purpose: `import Clayground.Lab`
        // shadows QtQuick's Flow with the kernel's narration type, and the
        // failure ("cannot assign to non-existent property spacing") points
        // nowhere near the cause.
        Grid {
            columns: 2
            width: readout.body.width
            spacing: LabTheme.spaceM
            WatchChip {
                monitor: monitor; target: "signal"
                labels: ({ add: "readout.signal", on: "readout.signal",
                           full: "watch.full" })
            }
            WatchChip {
                monitor: monitor; target: "envelope"
                labels: ({ add: "readout.envelope", on: "readout.envelope",
                           full: "watch.full" })
            }
            WatchChip {
                monitor: monitor; target: "measured"
                labels: ({ add: "readout.measured", on: "readout.measured",
                           full: "watch.full" })
            }
        }

        Text {
            visible: sandbox.roomy
            width: readout.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("readout.caption")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }

    // the running mean of the signal, from the probe's own summary - which is
    // where mean and stddev now live
    property real signalMean: 0
    Connections {
        target: Lab
        function onSampled(t) {
            const pr = Lab.probe("signal")
            if (pr) sandbox.signalMean = pr.summary().mean
        }
    }

    // --- bottom row --------------------------------------------------------

    // The bottom row takes whatever the instrument column leaves, rather than
    // a fixed height: at 100% that is a generous plot, and turned up it gives
    // way to the panels above instead of sliding off the screen. An invisible
    // item owns the geometry so the three panels in it cannot disagree.
    Item {
        id: bottomRow
        x: sandbox.roomy ? LabTheme.spaceXl
                         : gaugePanel.x + gaugePanel.width + LabTheme.spaceXl
        width: parent.width - x - LabTheme.spaceXl
        y: (sandbox.roomy ? readout.y + readout.height
                          : scenarios.y + scenarios.height) + LabTheme.spaceXl
        height: parent.height - LabTheme.px(40) - y
    }

    MiniMap {
        id: phaseMap
        // the second view of the same data is the first thing to give way
        // when the row is short of width
        visible: sandbox.roomy
        anchors.left: bottomRow.left
        anchors.top: bottomRow.top
        anchors.bottom: bottomRow.bottom
        width: LabTheme.px(214)
        title: LabLang.t("map.title")
        emptyText: LabLang.t("map.empty")
        revision: sandbox.trailRev
        bounds: {
            sandbox.trailRev
            if (sandbox.trail.length < 2) return { empty: true }
            const a = pAmp.value
            const w = 2 * Math.PI * pFreq.value * a
            return { x0: -a, x1: a, y0: -w, y1: w }
        }
        draw: (ctx, map) => {
            ctx.strokeStyle = LabTheme.grid.toString()
            ctx.lineWidth = 1
            ctx.beginPath()
            ctx.moveTo(map.px(map.cx), 0); ctx.lineTo(map.px(map.cx), map.height)
            ctx.moveTo(0, map.py(map.cy)); ctx.lineTo(map.width, map.py(map.cy))
            ctx.stroke()

            const t = sandbox.trail
            ctx.strokeStyle = LabTheme.seriesColors[0]
            ctx.lineWidth = Math.max(1, LabTheme.px(1.4))
            ctx.beginPath()
            ctx.moveTo(map.px(t[0].x), map.py(t[0].y))
            for (let i = 1; i < t.length; ++i)
                ctx.lineTo(map.px(t[i].x), map.py(t[i].y))
            ctx.stroke()

            const head = t[t.length - 1]
            ctx.fillStyle = LabTheme.accent.toString()
            ctx.beginPath()
            ctx.arc(map.px(head.x), map.py(head.y), Math.max(2, LabTheme.px(3)),
                    0, 2 * Math.PI)
            ctx.fill()
        }
    }

    // The plot that shows what the extensions are for: a line, its ±σ band,
    // and the measurement as scatter beside it.
    LabPanel {
        id: plotPanel
        anchors.left: phaseMap.visible ? phaseMap.right : bottomRow.left
        anchors.right: monitor.left
        anchors.top: bottomRow.top
        anchors.bottom: bottomRow.bottom
        anchors.leftMargin: phaseMap.visible ? LabTheme.spaceXl : 0
        anchors.rightMargin: LabTheme.spaceXl
        title: LabLang.t("plot.title")

        Plot2D {
            id: bandPlot
            width: plotPanel.body.width
            height: plotPanel.body.height
            windowSeconds: 16
            // panel inside a panel would draw two borders; the outer one wins
            color: "transparent"
            border.width: 0
            series: [
                { probe: "signal", label: LabLang.t("readout.signal"),
                  color: LabTheme.seriesColors[0], sigmaProbe: "sigma" },
                { probe: "measured", label: LabLang.t("readout.measured"),
                  color: LabTheme.seriesColors[4], style: "scatter" }
            ]
        }
    }

    WatchMonitor {
        id: monitor
        anchors.right: bottomRow.right
        anchors.bottom: bottomRow.bottom
        // the chips sit above the chart, so the chart gets what is left
        plotHeight: Math.max(LabTheme.px(60),
                             bottomRow.height - LabTheme.px(22) - LabTheme.spaceM)
        idPrefix: "trace."
        quantities: [{ key: "signal", label: "readout.signal", unit: "V" },
                     { key: "energy", label: "readout.energy", unit: "" }]
        valueOf: (id, q) => sandbox.traceValue(id, q)
        labelOf: (id) => LabLang.t("readout." + id)
        placeholder: LabLang.t("plot.empty")
        windowSeconds: 16
    }

    // --- right column ------------------------------------------------------

    Row {
        id: switches
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.spaceXl
        spacing: LabTheme.spaceM
        LangSwitch { }
        ScaleSwitch { }
        ThemeSwitch { }
    }

    ParamPanel {
        id: params
        anchors.right: parent.right
        anchors.top: switches.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.spaceL
    }

    ScenarioBar {
        id: scenarios
        lab: sandbox
        anchors.right: parent.right
        anchors.top: params.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.spaceL
        width: params.width
    }

    // --- top centre --------------------------------------------------------

    LabBanner {
        active: sandbox.overRange || sandbox.dampedOut
        alarm: sandbox.overRange
        blink: sandbox.overRange
        guard: gaugePanel
        text: LabLang.t(sandbox.overRange ? "banner.loud" : "banner.damped")
    }

    readonly property bool overRange: Math.abs(signal) > 2
    readonly property bool dampedOut: pAmp.value > 0
                                      && envelope < 0.02 * pAmp.value

    // The page says what it is. Also the one place the scale control is
    // named in words, which is what the whole of #197 was about.
    Column {
        id: masthead
        // centred in the GAP between the two columns, not on the window: at a
        // large scale the columns eat most of the width, and a masthead
        // centred on the window slides straight under the parameter panel
        x: gaugePanel.x + gaugePanel.width + LabTheme.spaceXxl
        y: LabTheme.px(56)
        width: Math.max(LabTheme.px(160),
                        params.x - LabTheme.spaceXxl - x)
        spacing: LabTheme.spaceS
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LabLang.t("shelf.title")
            color: LabTheme.primary
            font.pixelSize: LabTheme.fontBody; font.bold: true
            font.letterSpacing: 2.0
            font.family: LabTheme.monoFont
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: LabLang.t("shelf.hint")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontLabel
            font.family: LabTheme.handFont
        }
    }

    TransportChip {
        id: transport
        x: masthead.x + (masthead.width - width) / 2
        y: masthead.y + masthead.height + LabTheme.spaceXl
    }

    FlowChip {
        id: flowChip
        flow: shelfFlow
        x: masthead.x + (masthead.width - width) / 2
        y: transport.y + transport.height + LabTheme.spaceL
    }

    Narrator {
        flow: shelfFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
    }

    // --- the world ---------------------------------------------------------
    // Every lab has one; here it is a single bob on a guide, so the page reads
    // as an experiment with instruments around it rather than as a dashboard.
    // It is also where WatchMark belongs: the mark an object wears while it is
    // on the plot, in the colour it wears there.
    Item {
        id: stage
        anchors.left: gaugePanel.right
        anchors.right: params.left
        anchors.top: flowChip.bottom
        anchors.bottom: bottomRow.top
        anchors.margins: LabTheme.spaceXxl

        readonly property real span: Math.max(1, height * 0.34)
        readonly property real unit: span / Math.max(0.2, pAmp.value)

        Rectangle {   // the rest position
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 1
            color: LabTheme.grid
        }
        Repeater {    // the envelope, as the two limits it currently allows
            model: [1, -1]
            Rectangle {
                required property int modelData
                y: parent.height / 2 - modelData * sandbox.envelope * stage.unit
                width: parent.width; height: 1
                color: LabTheme.seriesColors[1]
                opacity: 0.5
            }
        }
        Rectangle {   // the bob
            id: bob
            x: parent.width / 2 - width / 2
            y: parent.height / 2 - sandbox.signal * stage.unit - height / 2
            width: LabTheme.px(22); height: width
            radius: width / 2
            color: LabTheme.seriesColors[0]
            border.color: LabTheme.panel
            border.width: LabTheme.borderWidth
        }
        WatchMark {
            monitor: monitor
            target: "signal"
            label: LabLang.qty(sandbox.signal, "V", 2)
            x: bob.x + bob.width + LabTheme.spaceL
            y: bob.y + (bob.height - height) / 2
        }
    }

    // --- the lesson --------------------------------------------------------

    Flow {
        id: shelfFlow
        lab: sandbox
        flowId: "shelf"
        titleKey: "flow.shelf.title"

        FlowStep {
            key: "gauge"
            demo: [["preset", "intro"]]
        }
        FlowStep { key: "plot" }
        FlowStep { key: "scale" }
        FlowStep {
            key: "watch"
            task: ({ "until": () => monitor.watched.length > 1,
                     "hint": "readout.caption",
                     "solve": [["watch", "envelope"]] })
            expect: () => monitor.watched.length > 1
        }
    }

    // --- the rest of the chrome -------------------------------------------

    DataRecorder {
        id: recorder
        // Resolved against THIS file, not the process CWD: a relative name
        // lands wherever the loader happened to be started, which is how a
        // stray run.csv ends up in the repo root.
        destination: Qt.resolvedUrl("lab_demo_recording.csv")
                        .toString().replace("file://", "")
        probes: ["signal", "envelope", "measured"]
    }

    RecIndicator {
        recorder: recorder
        x: LabTheme.spaceXl
        y: phaseMap.y - height - LabTheme.spaceM
    }

    LabKeys {
        id: keymap
        lab: sandbox
        flow: shelfFlow
        recorder: recorder
        viewKeys: false               // nothing here has a camera to turn
        keys: [{ key: "P", label: "key.pause", action: () => transport.toggle() }]
    }

    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: LabTheme.px(320)
    }

    HintBar {
        // the guards are the panels the bar could actually run into; once the
        // row has moved beside the instrument column it has the whole strip
        leftGuard: sandbox.roomy ? phaseMap : null
        rightGuard: sandbox.roomy ? monitor : null
        flow: shelfFlow
        text: LabLang.t("hint.idle")
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) sandbox.forceActiveFocus()
    }
}
