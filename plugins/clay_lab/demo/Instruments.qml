// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "instrument_strings.js" as Strings

// The instrument foundation, laid out.
//
// Two claims are on this page and both are meant to be visible in one glance:
//
//  1. A measurement and a face are different things. The panel on the left has
//     ONE InstrumentScale and four faces reading it - a needle, a bar, a
//     column and a set of digits. They cannot disagree, because there is
//     nothing for them to disagree about.
//
//  2. The same foundation skins across domains. The dock on the right holds an
//     electrical bench meter, an audio level meter and a wind gauge. Three
//     domains, no domain-specific components: a VU meter is a BarFace on a log
//     scale with peak-hold, and a wind gauge is a ColumnFace with bands.
//
// And, because HUD instruments belong to the reader rather than to the author:
// every panel in the dock can be put away with the ✕ in its corner, and the
// tray at the foot of the dock gives it back. The set rides in viewState().
//
// Keys: 1..3 presets · P pause · ? keys · Ctrl+Plus/Minus/0 text size
Rectangle {
    id: sandbox
    anchors.fill: parent
    focus: true
    color: LabTheme.paper

    // --- the model ---------------------------------------------------------
    // One clock, three quantities in three different units - which is the
    // point: the instruments below know none of them.

    Parameter { id: pDrive; name: "drive"; value: 0.8; from: 0; to: 2.4; unit: "V" }
    Parameter { id: pGust; name: "gust"; value: 0.35; from: 0; to: 1 }
    Parameter { id: pNoise; name: "noise"; value: 0.04; from: 0; to: 0.4; unit: "V" }

    SimClock {
        id: clock
        seed: 7
        sampleInterval: 0.05
        fixedStep: 1 / 60
        onStepped: (dt) => sandbox.stepSim(dt)
        onWasReset: sandbox.resetSim()
    }

    // the bus: a slowly beating ac line, rectified by the meters that read it
    readonly property real signal:
        pDrive.value * Math.sin(2 * Math.PI * 0.6 * clock.time)
        * (1 + 0.22 * Math.sin(2 * Math.PI * 0.11 * clock.time))

    // the audio envelope: a hit every 0.9 s, decaying - percussive on purpose,
    // because a peak-hold marker has nothing to hold on a steady tone
    readonly property real beat: clock.time - 0.9 * Math.floor(clock.time / 0.9)
    readonly property real amplitude:
        Math.max(1e-4, pDrive.value * (0.08 + 0.92 * Math.exp(-4.2 * beat)))
    readonly property real levelDb: 20 * Math.log(amplitude / 1.6) / Math.LN10

    // the mast: a slow swing with gusts riding on it. A pure function of
    // clock.time and touching no RNG at all - the sim stream belongs to the
    // measurement below, not to the weather.
    readonly property real windSpeed: {
        const t = clock.time
        const base = 4 + 10 * pGust.value * (0.5 + 0.5 * Math.sin(2 * Math.PI * 0.07 * t))
        const gust = 16 * pGust.value
                     * Math.pow(Math.max(0, Math.sin(2 * Math.PI * 0.23 * t)), 6)
        return base + gust
    }

    // The measurement is part of the MODEL, so it may (and must) come from the
    // clock's seeded stream. Decorative jitter never may.
    property real measured: 0
    property real _accum: 0

    function resetSim() {
        measured = 0
        _accum = 0
        voltScale.reset()
        busScale.reset()
        vuScale.reset()
        amplScale.reset()
        windScale.reset()
    }

    function stepSim(dt) {
        _accum += dt
        if (_accum >= clock.sampleInterval) {
            _accum = 0
            measured = signal + clock.randomGaussian() * pNoise.value
        }
    }

    Probe { name: "volts"; unit: "V"; expr: () => sandbox.measured }
    Probe { name: "level"; unit: "dB"; expr: () => sandbox.levelDb }
    Probe { name: "wind"; unit: "m/s"; expr: () => sandbox.windSpeed }

    // --- the measurements --------------------------------------------------
    //
    // Five scales, no faces. This is the whole of the instrument logic on this
    // page; everything below only draws one of these.

    // The showcase scale: rectified, because an ac reading swinging through
    // zero has a bar sitting at the bottom half the time - and rectifying is
    // what the meter reading it would actually do.
    InstrumentScale {
        id: voltScale
        value: Math.abs(sandbox.measured)
        unit: "V"; symbol: "V"
        min: 0; max: 2
        okUntil: 1.2; warnUntil: 1.7
        damping: 0.18            // a movement, not a strobe
        tickCount: 5
    }

    // The electrical skin: a bench meter with a range selector.
    InstrumentScale {
        id: busScale
        probe: "volts"
        unit: "V"; symbol: "V"
        ranges: [0.5, 1, 2, 5]
        damping: 0.2
    }

    // The music skin: a level in dB, which is already the log of the
    // amplitude, plus a marker that holds the loudest transient.
    InstrumentScale {
        id: vuScale
        value: sandbox.levelDb
        unit: "dB"
        min: -48; max: 6
        okUntil: -6; warnUntil: 0
        peakHold: true
        peakHoldTime: 1.0
        peakFall: 0.28
        digits: 1
        tickCount: 6
    }

    // The same sound on a log-positioned linear scale - the other way to say
    // it, and what `logScale` is for: equal ratios take equal space.
    InstrumentScale {
        id: amplScale
        value: sandbox.amplitude
        unit: ""
        min: 0; max: 2            // min 0 on a log scale means four decades down
        logScale: true
        peakHold: true
        peakHoldTime: 1.0
        peakFall: 0.28
    }

    // The weather skin: a fixed scale with three bands and a heavy movement,
    // because a mast anemometer has one.
    InstrumentScale {
        id: windScale
        probe: "wind"
        unit: "m/s"
        min: 0; max: 30
        okUntil: 12; warnUntil: 20
        damping: 0.55
        tickCount: 4
    }

    // --- scenarios ---------------------------------------------------------

    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "calm"
            description: "everything in its good band"
            script: () => {
                Lab.set("drive", 0.7); Lab.set("gust", 0.15); Lab.set("noise", 0.03)
            }
        }
        Scenario {
            name: "loud"
            description: "past full scale"
            script: () => {
                Lab.set("drive", 2.2); Lab.set("gust", 0.3); Lab.set("noise", 0.09)
            }
        }
        Scenario {
            name: "gusty"
            description: "the mast alarms while the rest stays calm"
            script: () => {
                Lab.set("drive", 0.6); Lab.set("gust", 1.0); Lab.set("noise", 0.03)
            }
        }
    }

    // --- the conventions contract -----------------------------------------

    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    function labInfo() { return Lab.labInfo() }
    function flagInfo() { return labInfo() }

    // The dock's visible set is part of the reader's place, exactly like a
    // camera pose - so it goes in with the rest of it.
    function viewState() {
        return Object.assign(Lab.viewState(), { dock: dock.viewState() })
    }
    function applyViewState(s) {
        if (!s) return
        dock.applyViewState(s.dock)
        Lab.applyViewState(s.lab !== undefined ? s.lab : s)
    }

    Component.onCompleted: {
        LabLang.register(Strings.dict)
        forceActiveFocus()
        // Deferred by one turn: the root's onCompleted runs before its
        // children's, so a Parameter has not registered with Lab yet.
        Qt.callLater(() => sandbox.applyScenario("calm"))
    }

    // Captions are commentary rather than instrument, so they are the first
    // thing to step aside when the window is short.
    readonly property bool roomy: height >= LabTheme.px(720)

    // The page's one vertical budget, in the scale's own units - so turning the
    // text size up is a stress test the layout passes rather than a way to push
    // panels off the bottom of the window.
    readonly property real colTop: LabTheme.spaceXl
    readonly property real colBottom: height - LabTheme.px(64)
    readonly property real colHeight: colBottom - colTop

    // What gives way first: the second view of the same three quantities. The
    // dock and the four faces are the page; the vertical bars restate them.
    readonly property bool showDomains: colHeight >= LabTheme.px(560)

    // --- left: one quantity, four faces ------------------------------------

    LabPanel {
        id: facesPanel
        x: LabTheme.spaceXl
        y: sandbox.colTop
        width: LabTheme.px(392)
        height: sandbox.showDomains
                ? Math.min(sandbox.colHeight * 0.6, LabTheme.px(470))
                : sandbox.colHeight
        title: LabLang.t("faces.title")

        Row {
            id: facesRow
            width: facesPanel.body.width
            height: facesPanel.body.height - (facesCaption.visible
                        ? facesCaption.height + LabTheme.spaceL : 0)
            spacing: LabTheme.spaceXl

            Column {
                id: flatFaces
                width: facesRow.width - column.width - facesRow.spacing
                spacing: LabTheme.spaceL

                Gauge {
                    width: flatFaces.width
                    height: LabTheme.px(118)
                    scale: voltScale
                    showValue: false
                    showFrame: false
                }
                Text {
                    text: LabLang.t("faces.needle")
                    color: LabTheme.inkFaint
                    font.pixelSize: LabTheme.fontMicro
                    font.letterSpacing: 1.0
                    font.family: LabTheme.monoFont
                }

                BarFace {
                    width: flatFaces.width
                    scale: voltScale
                    label: LabLang.t("faces.bar")
                }

                DigitFace {
                    width: flatFaces.width
                    scale: voltScale
                    label: LabLang.t("faces.digits")
                }
            }

            ColumnFace {
                id: column
                height: facesRow.height
                scale: voltScale
                label: LabLang.t("faces.column")
            }
        }

        Text {
            id: facesCaption
            visible: sandbox.roomy
            width: facesPanel.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("faces.caption")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }

    // The claim of D1 in one row: ONE face type, three domains, three units,
    // three sets of bands - and the face knows none of them. The only thing
    // that differs between these three is which InstrumentScale each was
    // handed.
    LabPanel {
        id: domainsPanel
        visible: sandbox.showDomains
        x: facesPanel.x
        y: facesPanel.y + facesPanel.height + LabTheme.spaceXl
        width: facesPanel.width
        height: Math.max(LabTheme.px(150), sandbox.colBottom - y)
        title: LabLang.t("domains.title")

        Row {
            id: domainsRow
            width: domainsPanel.body.width
            height: domainsPanel.body.height - (domainsCaption.visible
                        ? domainsCaption.height + LabTheme.spaceS : 0)
            spacing: LabTheme.spaceL

            // Wider than the bar itself on purpose: a vertical face is
            // narrower than its own caption, and the width it is given is what
            // the caption elides against.
            readonly property real cell:
                (width - 2 * spacing) / 3

            BarFace {
                width: domainsRow.cell
                height: domainsRow.height
                orientation: Qt.Vertical
                scale: busScale
                label: LabLang.t("readout.volts")
                thickness: LabTheme.px(20)
            }
            BarFace {
                width: domainsRow.cell
                height: domainsRow.height
                orientation: Qt.Vertical
                scale: vuScale
                label: LabLang.t("music.level")
                segments: 18
                thickness: LabTheme.px(20)
            }
            BarFace {
                width: domainsRow.cell
                height: domainsRow.height
                orientation: Qt.Vertical
                scale: windScale
                label: LabLang.t("readout.wind")
                thickness: LabTheme.px(20)
            }
        }

        Text {
            id: domainsCaption
            visible: sandbox.roomy
            width: domainsPanel.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("domains.caption")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }

    // --- middle: what the instruments are reading --------------------------

    Column {
        id: masthead
        x: facesPanel.x + facesPanel.width + LabTheme.spaceXxl
        y: LabTheme.spaceXl
        width: Math.max(LabTheme.px(200), dock.x - LabTheme.spaceXxl - x)
        spacing: LabTheme.spaceS
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: LabLang.t("inst.title")
            color: LabTheme.primary
            font.pixelSize: LabTheme.fontBody; font.bold: true
            font.letterSpacing: 2.0
            font.family: LabTheme.monoFont
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: LabLang.t("inst.hint")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontLabel
            font.family: LabTheme.handFont
        }
    }

    TransportChip {
        id: transport
        x: masthead.x + (masthead.width - width) / 2
        y: masthead.y + masthead.height + LabTheme.spaceL
    }

    // Takes whatever the column above and the preset bar below leave it,
    // rather than a fixed height: turned up, the chrome grows into it instead
    // of the page sliding off the screen.
    LabPanel {
        id: plotPanel
        x: masthead.x
        y: transport.y + transport.height + LabTheme.spaceXl
        width: masthead.width
        height: Math.max(LabTheme.px(120), scenarios.y - LabTheme.spaceXl - y)
        title: LabLang.t("plot.title")

        Plot2D {
            width: plotPanel.body.width
            height: plotPanel.body.height
            windowSeconds: 14
            color: "transparent"
            border.width: 0
            placeholder: LabLang.t("plot.empty")
            // one autoscaled axis, so one quantity: the bus, which is the one
            // the four faces on the left are all reading
            series: [{ probe: "volts", label: LabLang.t("readout.volts"),
                       color: LabTheme.seriesColors[0] }]
        }
    }

    // Anchored to the FOOT of the page, clear of the hint bar: the plot above
    // then absorbs the change when the text size does.
    ScenarioBar {
        id: scenarios
        lab: sandbox
        x: masthead.x
        y: sandbox.colBottom - height
        width: masthead.width
    }

    // --- right: the dock ---------------------------------------------------

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

    InstrumentDock {
        id: dock
        anchors.right: parent.right
        anchors.top: switches.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.spaceL
        itemWidth: LabTheme.px(248)

        // 1. electric - a self-ranging needle with its own digits beside it
        DockedInstrument {
            id: electric
            key: "electric"
            label: LabLang.t("inst.electric")
            accent: LabTheme.teal

            // The dock is a column of three and has to fit the window at every
            // text size, so the tall faces in it shrink when the page is short
            // rather than pushing the last instrument off the bottom.
            Gauge {
                width: electric.body.width
                height: sandbox.roomy ? LabTheme.px(104) : LabTheme.px(84)
                scale: busScale
                accent: LabTheme.teal
                showFrame: false
            }
            DigitFace {
                width: electric.body.width
                scale: busScale
                digitSize: LabTheme.px(26)
            }
            Text {
                visible: sandbox.roomy
                width: electric.body.width
                wrapMode: Text.WordWrap
                text: LabLang.t("elec.caption")
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.handFont
            }
        }

        // 2. music - the same bar face twice, on two different scales: a dB
        //    ladder and the amplitude behind it, positioned logarithmically
        DockedInstrument {
            id: music
            key: "music"
            label: LabLang.t("inst.music")
            accent: LabTheme.plum

            BarFace {
                width: music.body.width
                scale: vuScale
                label: LabLang.t("music.level")
                segments: 22
                thickness: LabTheme.px(16)
            }
            BarFace {
                width: music.body.width
                scale: amplScale
                label: LabLang.t("music.ampl")
                showValue: false
                thickness: LabTheme.px(9)
            }
            Text {
                visible: sandbox.roomy
                width: music.body.width
                wrapMode: Text.WordWrap
                text: LabLang.t("music.caption")
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.handFont
            }
        }

        // 3. wind - a column and the number, the pairing a weather station has
        DockedInstrument {
            id: wind
            key: "wind"
            label: LabLang.t("inst.wind")
            accent: LabTheme.forest

            Row {
                width: wind.body.width
                spacing: LabTheme.spaceXl
                ColumnFace {
                    id: windColumn
                    height: sandbox.roomy ? LabTheme.px(168) : LabTheme.px(124)
                    scale: windScale
                    label: LabLang.t("wind.speed")
                }
                // A wrapper, because a child of a positioner may not anchor
                // itself - and the digits belong beside the middle of the
                // column, not level with its cap.
                Item {
                    width: wind.body.width - windColumn.width - LabTheme.spaceXl
                    height: windColumn.height
                    DigitFace {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        scale: windScale
                        digitSize: LabTheme.px(26)
                    }
                }
            }
            Text {
                visible: sandbox.roomy
                width: wind.body.width
                wrapMode: Text.WordWrap
                text: LabLang.t("wind.caption")
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.handFont
            }
        }
    }

    // --- the rest of the chrome -------------------------------------------

    LabKeys {
        id: keymap
        lab: sandbox
        viewKeys: false               // nothing here has a camera to turn
        keys: [{ key: "P", label: "key.pause", action: () => transport.toggle() }]
    }

    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: LabTheme.px(320)
    }

    // No left guard: the left column is bounded by colBottom and stops above
    // this strip, so guarding against it would cap the bar at a fifth of the
    // room it actually has. The dock has no such bound and can reach down here.
    HintBar {
        rightGuard: dock
        text: LabLang.t("hint.idle")
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) sandbox.forceActiveFocus()
    }
}
