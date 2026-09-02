// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "strings.js" as Strings

// {{Title}} - a mass on a spring, damped and optionally driven. Started
// {{date}} from tools/lab-new (kind: continuous, purpose: {{purpose}}).
//
// THIS IS A STARTING POINT, NOT A LAB. Everything below is real and runs, so
// you can change one thing at a time and keep a loadable lab throughout. What
// is yours to replace: the system in stepSim(), the parameters that drive it,
// the probes that measure it, the scenarios, the flow narration and every
// string in strings.js. What is NOT yours to replace: the conventions block,
// the key map and the HUD slots - an agent, a flow and the dojo all address
// every lab through those.
//
// A CONTINUOUS lab has no build step and nothing to select: it runs, and you
// turn knobs while it does. Time therefore comes from the clock in FIXED
// steps and from nowhere else, which is what makes a record of a run worth
// committing.
//
// Keys: 1-2 presets · T tour · V readout · M plot · F frame the mass ·
// 0 frame the bench · arrows/WASD travel · Shift+arrows turn · +/- zoom ·
// Space holds the view · Shift+R record · Ctrl +/-/0 text size · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true

    // Register the dictionary BEFORE the first scenario: a scenario may set a
    // banner or a hint, and a lab that translates itself afterwards has
    // already shown one raw key. A kit's vocabulary would be registered first,
    // on the line above, so this lab's copy can override it.
    Component.onCompleted: {
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("intro")
    }

    // --- the system --------------------------------------------------------
    // Position and velocity of the mass, in metres and metres per second.
    // Plain properties rather than a JS object: they are read by probes, by
    // the scene and by the flow's predicates, and a property change is what
    // makes all three follow.
    property real massX: 0
    property real massV: 0

    // view-only toggles - LabKeys drives them, viewState carries them, and
    // nothing in the simulation may read them
    property bool showReadout: true
    property bool showPlot: true

    // --- parameters --------------------------------------------------------
    // Owner-less globals go here rather than into a scenario: a Parameter is
    // what the slider panel, the recorder and a flow's "setParam" verb all
    // address by name.
    Parameter {
        id: pStiffness
        name: "stiffness"; value: 6; from: 0.5; to: 30; unit: "N/m"
    }
    Parameter {
        id: pDamping
        name: "damping"; value: 0.35; from: 0; to: 4; unit: "N·s/m"
    }
    Parameter {
        id: pDrive
        name: "drive"; value: 0; from: 0; to: 4; unit: "N"
    }

    // --- the clock ---------------------------------------------------------
    // The only source of time and randomness. fixedStep is not an optimization:
    // a frame is a wall-clock interval, so a run driven by frames depends on
    // the machine it ran on and no two records of one seed agree.
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.05
        fixedStep: 1 / 60
        onStepped: (dt) => root.stepSim(dt)
    }

    // Semi-implicit Euler on m x'' + c x' + k x = F sin(w t), m = 1. Replace
    // this with your own system; keep the shape - state in, one fixed dt,
    // state out, no frame time anywhere.
    readonly property real driveHz: 0.35
    function stepSim(dt) {
        const f = pDrive.value * Math.sin(2 * Math.PI * driveHz * clock.time)
        const a = f - pStiffness.value * massX - pDamping.value * massV
        massV += a * dt
        massX += massV * dt
    }

    // --- probes ------------------------------------------------------------
    // One per quantity worth a curve. A number the paper will quote needs a
    // probe here, or it cannot come out of a run record.
    Probe { name: "position"; unit: "m"; expr: () => root.massX }
    Probe { name: "velocity"; unit: "m/s"; expr: () => root.massV }
    Probe {
        name: "energy"; unit: "J"
        expr: () => 0.5 * (root.massV * root.massV
                           + Lab.p("stiffness") * root.massX * root.massX)
    }

    // --- scenarios ---------------------------------------------------------
    // Named, scripted situations; the lab always cold-opens into one. Applying
    // one resets the clock and the RNG - that is the reproducibility anchor,
    // so a scenario script must reset EVERYTHING a probe can see.
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "intro"; description: "a light nudge, barely damped"
            script: () => {
                root.massX = 1.6; root.massV = 0
                Lab.set("stiffness", 6); Lab.set("damping", 0.35)
                Lab.set("drive", 0)
            }
        }
        Scenario {
            name: "damped"; description: "the same nudge, four times the damping"
            script: () => {
                root.massX = 1.6; root.massV = 0
                Lab.set("stiffness", 6); Lab.set("damping", 1.6)
                Lab.set("drive", 0)
            }
        }
    }

    // --- inspector / agent / flow conventions -------------------------------
    // The contract every lab answers. An agent, the dojo's reload path and the
    // flow runner all address the lab through exactly these names.
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }

    // Language-neutral: ids, numbers and types, never a translated label.
    function labInfo() {
        const info = Lab.labInfo()
        info.flow = { id: introFlow.running ? introFlow.flowId : "",
                      step: introFlow.index }
        info.massX = massX
        info.massV = massV
        return info
    }
    function flagInfo() { return labInfo() }

    // The user's whole place: the camera, the toggles and any state the
    // simulation cannot re-derive from scenario + clock.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            cam: rig.state(),
            showReadout: showReadout,
            showPlot: showPlot,
            lang: LabLang.lang
        })
    }
    // Ordering contract, easy to get wrong: (1) the scenario, because applying
    // it resets clock + RNG, (2) Lab.applyViewState, which re-steps the
    // world-less clock and replays the run bit-identically, (3) the camera and
    // the view-only toggles, which touch no sim state at all.
    function applyViewState(s) {
        if (!s) return
        if (s.scenario) applyScenario(s.scenario)
        Lab.applyViewState(s)
        if (s.cam) rig.applyState(s.cam)
        if (s.showReadout !== undefined) showReadout = s.showReadout
        if (s.showPlot !== undefined) showPlot = s.showPlot
        if (s.lang) LabLang.lang = s.lang
    }

    // Every state change the lab supports is a named verb: the UI calls these,
    // a flow calls these, an agent calls these through eval. No verb exists
    // that only a flow can perform.
    function flowActions() {
        return {
            "scenario": (n) => applyScenario(n),
            "setParam": (n, v) => Lab.set(n, v),
            "nudge":    (x) => { root.massX = x; root.massV = 0 },
            "frame":    (what) => what === "selection" ? frameSelection()
                                                       : frameAll(),
            "record":   (on) => { recorder.recording = on }
        }
    }
    function flows() { return [introFlow.flowId] }
    function startFlow(id) {
        if (id === introFlow.flowId) { introFlow.start(); return true }
        return false
    }

    // The two framings LabKeys binds to 0 and F.
    function frameAll() {
        rig.frame([Qt.vector3d(-9, 0, -4), Qt.vector3d(9, 0, 4)], 1.3)
    }
    function frameSelection() {
        rig.frame([Qt.vector3d(massX - 3, 0, -3), Qt.vector3d(massX + 3, 0, 3)], 1.2)
    }

    // Shift+R writes a scratch record of a FRAME-driven run, which is not
    // reproducible and must never be quoted. The citable ones come from
    // records/make.sh, which stops the ticker and steps the clock by hand.
    DataRecorder {
        id: recorder
        lab: "{{slug}}"
        destination: "labs/{{slug}}/records/session.labrec"
    }

    // --- the scene ---------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        environment: stage.environment
        camera: rig.camera

        // Ground, lights and environment in one block: an endless sheet of
        // squared paper whose raster is drawn in the shader, so the scale
        // reference holds at any zoom.
        LabStage3D {
            id: stage
            cellSize: 1
            majorEvery: 5
            workExtent: Qt.vector2d(20, 10)
            cueSize: 0
        }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 0, 0)
            yaw: 0; pitch: 32; distance: 22
            minPitch: 8; maxPitch: 84
            minDistance: 6; maxDistance: 90
            minHeight: 2
            homePivot: Qt.vector3d(0, 0, 0)
            panLeash: stage.workRadius * 1.2
        }
        CameraAnchorMark { pointer: nav }

        // The rail the mass slides on: a marking on the ground, so it lies
        // FLAT - a camera-facing ribbon splays and reads as a wall.
        MultiLine3D {
            coords: [[Qt.vector3d(-8.6, stage.overlayY(0), 0),
                      Qt.vector3d(8.6, stage.overlayY(0), 0)]]
            color: LabTheme.muted
            width: 0.10
            orientation: LineBatch3D.Flat
        }

        // The wall the spring is anchored to. Box3D's origin is bottom-centre,
        // so y: 0 stands it ON the ground rather than half-sunk into it.
        Box3D {
            x: -9; y: 0; z: 0
            width: 0.6; depth: 3; height: 2.4
            color: LabTheme.inkFaint
            useToonShading: true
        }

        // The spring, as a zigzag between the wall and the mass. Pure geometry
        // from massX: no state of its own, so it can never disagree with the
        // simulation it draws.
        MultiLine3D {
            readonly property real tipX: root.massX - 0.5
            coords: {
                const pts = [Qt.vector3d(-8.7, 0.9, 0)]
                const coils = 14
                for (let i = 1; i < coils; ++i) {
                    const t = i / coils
                    pts.push(Qt.vector3d(-8.7 + t * (tipX + 8.7), 0.9,
                                         (i % 2 === 0 ? 0.32 : -0.32)))
                }
                pts.push(Qt.vector3d(tipX, 0.9, 0))
                return [pts]        // coords is a list of PATHS, not of points
            }
            color: LabTheme.clay
            width: 0.07
        }

        // The mass itself.
        Box3D {
            id: massBody
            x: root.massX; y: 0; z: 0
            width: 1.0; depth: 1.0; height: 1.8
            color: LabTheme.secondary
            useToonShading: true
        }

        // Where it started, so "how far from rest" is a thing you can see
        // rather than only read.
        MultiLine3D {
            coords: [[Qt.vector3d(0, stage.overlayY(1), -1.6),
                      Qt.vector3d(0, stage.overlayY(1), 1.6)]]
            color: LabTheme.inkFaint
            width: 0.05
            orientation: LineBatch3D.Flat
        }
    }

    // --- navigation --------------------------------------------------------
    // Nothing here is built or selected, so the left button has no rival tool
    // and may pan. In a lab that draws or places, it may not - see the draw
    // template.
    OrbitInput3D {
        id: nav
        rig: rig
        view: view3d
        panButtons: Qt.LeftButton | Qt.MiddleButton
    }
    MouseArea {
        id: viewMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: nav.cursorShape
        // A press on the view takes the keyboard back: clicking a HUD chip
        // gives focus to that chip, and then every key goes somewhere the lab
        // never hears about.
        onPressed: (m) => {
            root.forceActiveFocus()
            nav.begin(m.x, m.y, m.button, m.modifiers)
        }
        onPositionChanged: (m) => {
            if (nav.move(m.x, m.y)) return
            if (!pressed) nav.hoverAt(m.x, m.y)
        }
        onReleased: nav.end()
        onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)
        onDoubleClicked: (m) => nav.recenterAt(m.x, m.y)
    }

    // --- HUD: palette top-left ---------------------------------------------
    LabPanel {
        id: palette
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(230)
        title: LabLang.t("lab.title")
        spacing: LabTheme.spaceS

        ScenarioBar { lab: root; width: palette.body.width }
        // The visible offer of the guided tour, from the first frame: a flow
        // nobody finds teaches nobody.
        FlowChip { flow: introFlow }
    }

    Compass {
        id: compass
        anchors.left: palette.left
        anchors.top: palette.bottom
        anchors.topMargin: LabTheme.px(10)
        yaw: rig.yaw
    }

    // --- HUD: language, size, theme top-right, parameters under them --------
    Row {
        id: topSwitches
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: LabTheme.px(10)
        spacing: LabTheme.spaceM
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ScaleSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }
    ParamPanel {
        id: params
        anchors.right: parent.right; anchors.top: topSwitches.bottom
        anchors.rightMargin: LabTheme.px(10); anchors.topMargin: LabTheme.px(10)
    }

    // --- HUD: the readings, bottom-left ------------------------------------
    LabPanel {
        id: readout
        visible: root.showReadout
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.leftMargin: LabTheme.px(12)
        anchors.bottomMargin: LabTheme.px(46)
        width: LabTheme.px(230)
        title: LabLang.t("readout.title")

        // Sampled rather than bound: at the sim rate the last digit is a blur.
        property real vX: 0
        property real vV: 0
        Timer {
            interval: 250; running: true; repeat: true
            onTriggered: { readout.vX = root.massX; readout.vV = root.massV }
        }
        Text {
            width: readout.body.width
            elide: Text.ElideRight
            text: LabLang.t("quantity.position") + "  "
                  + LabLang.qty(readout.vX, "m", 2)
            color: LabTheme.ink
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Text {
            width: readout.body.width
            elide: Text.ElideRight
            text: LabLang.t("quantity.velocity") + "  "
                  + LabLang.qty(readout.vV, "m/s", 2)
            color: LabTheme.ink
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Text {
            width: readout.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("readout.caption")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }

    // --- HUD: the plot, bottom-right ---------------------------------------
    Plot2D {
        id: plot
        visible: root.showPlot
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: LabTheme.px(10)
        width: LabTheme.px(360)
        height: LabTheme.px(170)
        windowSeconds: 20
        placeholder: LabLang.t("plot.empty")
        series: [
            { probe: "position", label: LabLang.t("quantity.position"),
              color: LabTheme.secondary },
            { probe: "velocity", label: LabLang.t("quantity.velocity"),
              color: LabTheme.plum }
        ]
    }

    // --- HUD: banner, hint bar, transport, recording ------------------------
    // Inactive in both shipped scenarios: it only speaks when the driving
    // force wins against the damping and the mass leaves the bench.
    LabBanner {
        active: Math.abs(root.massX) > 7
        alarm: true
        guard: palette
        text: LabLang.t("banner.runaway")
    }
    HintBar {
        id: hintBar
        flow: introFlow
        rightGuard: plot
        leftGuard: readout
        text: {
            if (Lab.p("drive") > 0) return LabLang.t("hint.driven")
            if (Lab.p("damping") > 1.2) return LabLang.t("hint.damped")
            return LabLang.t("hint.idle")
        }
    }
    TransportChip {
        id: transport
        clock: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: LabTheme.spaceXl
    }
    RecIndicator {
        recorder: recorder
        anchors.left: parent.left; anchors.leftMargin: LabTheme.spaceXl
        anchors.bottom: parent.bottom; anchors.bottomMargin: LabTheme.spaceL
    }

    // --- the guided tour ----------------------------------------------------
    // Three steps, one of each kind: the lab acts, the learner acts, the lab
    // checks. Narration lives in strings.js under flow.<flowId>.<stepKey>,
    // which is what makes it translatable and diffable.
    Flow {
        id: introFlow
        lab: root
        camera: rig
        flowId: "{{id}}-intro"
        titleKey: "flow.{{id}}-intro.title"

        // demo: the lab acts through its own verbs, the learner watches
        FlowStep {
            key: "intro"
            demo: [["scenario", "intro"], ["setParam", "damping", 0.25],
                   ["nudge", 1.8], ["frame", "all"]]
        }
        // task: the learner acts. `until` is a predicate on LAB STATE, never
        // on a particular click, so there is always more than one way to
        // satisfy it - and `solve` is the "show me" path, so nobody is stuck.
        FlowStep {
            key: "try"
            task: ({ "until": () => Lab.p("damping") >= 1.2,
                     "hint": "flow.{{id}}-intro.try.hint",
                     "hintAfter": 8,
                     "solve": [["setParam", "damping", 1.6]] })
        }
        // expect: the assertion that makes the flow a test. Run headless with
        // pacing "auto" and a drifted lab breaks its own lesson loudly.
        FlowStep {
            key: "check"
            expect: () => Math.abs(root.massX) < 0.6
        }
    }
    Narrator {
        flow: introFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.px(10)
        // Centred, so its half-width is bounded by the NEARER panel - the plot
        // on the right here. Capping against root.width instead lets a German
        // narration, a quarter longer than the English, slide under it.
        width: Math.max(LabTheme.px(280),
                        Math.min(LabTheme.px(680),
                                 2 * (plot.x - root.width / 2 - LabTheme.spaceL)))
    }

    // --- keys ---------------------------------------------------------------
    // The reserved half of the map (presets, flow, view, record, help) is
    // LabKeys'. What is declared here is what this lab ADDS - and declaring it
    // here is also what documents it in LabHelp and in the ? list. Never
    // reassign 1-9, T, F, 0, Shift+R, W/A/S/D, the arrows, Space, H, P, Tab,
    // Esc or Ctrl +/-/0.
    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        flow: introFlow
        recorder: recorder
        keys: [
            { key: "V", label: "key.readout",
              action: () => root.showReadout = !root.showReadout },
            { key: "M", label: "key.plot",
              action: () => root.showPlot = !root.showPlot }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: LabTheme.px(320)
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) root.applyScenario(Lab.scenario || "intro")
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
