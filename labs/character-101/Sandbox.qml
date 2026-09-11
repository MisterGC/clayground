// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
// Flow is also the kernel's narrated walkthrough; the layout is asked for by name
import QtQuick as Quick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../kits/character/strings.js" as KitStrings
import "strings.js" as Strings

// Character 101 - the procedural character, one aspect at a time. Started
// 2026-09-11 from tools/lab-new (kind: continuous, purpose: teaching).
//
// The lab is an ENTRY POINT THAT ONLY SELECTS. Every aspect of a character -
// the builds, the walk cycle, the gestures, the two whole-body actions, a
// loadable move set, the hands, the six faces, the head's detail tiers, the
// lip-sync tiers, a listener, and what a crowd costs - is a scene in
// labs/kits/character, loaded into this one View3D by the scenario that
// names it. What is here is what every aspect shares: the clock, the camera,
// the panels, the plot, the record, the keys and the tour. What a scene owns
// it declares through one contract (labs/kits/character/README.md): its
// knobs as kernel Parameters, its readings as kernel Probes, its choices and
// verbs, its framing, its labels and its report() - so the panel, the plot,
// the record and an agent all follow whichever scene is loaded.
//
// The clock is the only source of time. A scene that moves is posed from the
// clock's phase, and a scene that is a sheet of frozen figures reads its
// probes off the pure pose model at that phase - so a stepped run is the
// cycle's own curves, and two runs of one seed are one record.
//
// Keys: 1-9 scenarios · T tour · V readings · M plot · S silhouette · N next
// shot · F frame · 0 home · arrows/WASD travel · Shift+arrows turn · +/- zoom
// · Space holds the view · Shift+R record · Ctrl +/-/0 text size · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true

    // The kit's vocabulary first, the lab's copy second - so the lab may
    // override a word - and both BEFORE the first scenario.
    Component.onCompleted: {
        LabLang.register(KitStrings.dict)
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("lineup")
    }

    // --- the aspects ----------------------------------------------------------
    // One scene per aspect; the scenario that selects it is the same name.
    readonly property var aspectFiles: ({
        "lineup": "Lineup.qml",
        "gait": "GaitSheet.qml",
        "gestures": "GestureSheet.qml",
        "action": "ActionStage.qml",
        "moves": "MoveSheet.qml",
        "hands": "HandBench.qml",
        "faces": "FaceSheet.qml",
        "heads": "HeadRow.qml",
        "speech": "SpeechRow.qml",
        "conversation": "ConversationStage.qml",
        "crowd": "CrowdField.qml"
    })
    property string aspect: ""
    readonly property var scene: sceneLoader.item
    readonly property bool sceneReady: scene !== null && scene.ready === true
    // Whether the clock runs on its own (the dojo, a live render) or is being
    // stepped by hand (a record, the gate, --paused). A scene whose motion
    // belongs to the plugin's own animators may only start it while live, so
    // a stepped run stays a run of nothing moving.
    readonly property bool live: clock._frameTicker.running

    // view-only toggles - LabKeys drives them, viewState carries them, and
    // nothing a probe reads may depend on them
    property bool showReadout: true
    property bool showPlot: true
    property bool silhouette: false
    property string shot: ""

    function select(name) {
        if (root.aspectFiles[name] === undefined) return false
        root.shot = ""
        root.aspect = name
        return true
    }

    // Verbs a scene answers. They are dispatched by name so a flow may ask
    // for one in the same step that switches the scenario: on the desktop the
    // scene is there synchronously, in the browser it may still be loading,
    // and a verb that arrives before it is kept and performed on load.
    readonly property var sceneVerbs: [
        "base", "preset", "emotion", "gesture", "action", "move", "pose", "arm",
        "expression", "subject", "activity", "detail", "recording", "speaker",
        "listening", "build", "play", "say", "stop", "fingers", "gloves", "props",
        "solo", "gaze", "dialogue"
    ]
    property var _pending: []
    function act(verb, args) {
        const s = root.scene
        if (s === null || !s.verbs) { root._pending = root._pending.concat([[verb, args]]); return undefined }
        const v = s.verbs()[verb]
        if (v === undefined) { console.warn("character-101: " + root.aspect + " has no verb " + verb); return undefined }
        // A choice that moves what is on show (one gesture column, another
        // arm pose under the close-up) re-frames; one that does not (a
        // preset) leaves the viewer's camera alone.
        const before = JSON.stringify(s.bounds(root.currentShot()))
        const r = v.apply(null, args)
        if (JSON.stringify(s.bounds(root.currentShot())) !== before) root.frameAll()
        return r
    }
    function _flushPending() {
        const list = root._pending
        root._pending = []
        for (const [verb, args] of list) root.act(verb, args)
    }

    // --- the clock ------------------------------------------------------------
    // The only source of time and randomness. A scene reads it through its
    // `time`, bound on load; nothing else in the lab keeps time.
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.05
        fixedStep: 1 / 60
    }

    // --- scenarios ------------------------------------------------------------
    // Applying one resets the clock and the RNG and swaps the scene; a scene
    // arrives in its own default state, which is what a record of it is of.
    ScenarioSet {
        id: scenarioSet
        Scenario { name: "lineup"; script: () => root.select("lineup") }
        Scenario { name: "gait"; script: () => root.select("gait") }
        Scenario { name: "gestures"; script: () => root.select("gestures") }
        Scenario { name: "action"; script: () => root.select("action") }
        Scenario { name: "moves"; script: () => root.select("moves") }
        Scenario { name: "hands"; script: () => root.select("hands") }
        Scenario { name: "faces"; script: () => root.select("faces") }
        Scenario { name: "heads"; script: () => root.select("heads") }
        Scenario { name: "speech"; script: () => root.select("speech") }
        Scenario { name: "conversation"; script: () => root.select("conversation") }
        Scenario { name: "crowd"; script: () => root.select("crowd") }
    }

    // --- inspector / agent / flow conventions ---------------------------------
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }

    // Language-neutral: ids, numbers and types, never a translated label.
    function labInfo() {
        const info = Lab.labInfo()
        info.aspect = root.aspect
        info.ready = root.sceneReady
        info.shot = root.shot
        info.report = root.scene && root.scene.report ? root.scene.report() : null
        info.flow = { id: tour.running ? tour.flowId : "", step: tour.index }
        return info
    }
    function flagInfo() { return labInfo() }

    // The user's whole place: the scene's choices, the camera and the toggles.
    // Knob values travel in Lab.viewState() as parameters.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            cam: rig.state(),
            scene: root.scene && root.scene.choiceState ? root.scene.choiceState() : null,
            shot: root.shot,
            silhouette: root.silhouette,
            showReadout: root.showReadout,
            showPlot: root.showPlot,
            lang: LabLang.lang
        })
    }
    // (1) the scenario, which resets clock + RNG and loads the scene, (2) the
    // scene's own choices and the parameters, (3) the camera and the toggles.
    function applyViewState(s) {
        if (!s) return
        if (s.scenario) applyScenario(s.scenario)
        if (s.scene && root.scene && root.scene.loadChoices) root.scene.loadChoices(s.scene)
        Lab.applyViewState(s)
        if (s.shot !== undefined) root.shot = s.shot
        if (s.silhouette !== undefined) root.silhouette = s.silhouette
        if (s.showReadout !== undefined) root.showReadout = s.showReadout
        if (s.showPlot !== undefined) root.showPlot = s.showPlot
        if (s.lang) LabLang.lang = s.lang
        if (s.cam) rig.applyState(s.cam)
    }

    // One mutation API, three drivers: the UI, a Flow by name, an agent
    // through eval. The lab's own verbs, then every scene verb by name.
    function flowActions() {
        const a = {
            "scenario":   (n) => applyScenario(n),
            "setParam":   (n, v) => Lab.set(n, v),
            "shot":       (name) => root.goShot(name),
            "frame":      () => root.frameAll(),
            "silhouette": (on) => { root.silhouette = on === undefined ? true : !!on },
            "readout":    (on) => { root.showReadout = on === undefined ? true : !!on },
            "plot":       (on) => { root.showPlot = on === undefined ? true : !!on },
            "record":     (on) => { recorder.recording = !!on }
        }
        for (const verb of root.sceneVerbs)
            a[verb] = (...args) => root.act(verb, args)
        return a
    }
    function flows() { return [tour.flowId] }
    function startFlow(id) {
        if (id === tour.flowId) { tour.start(); return true }
        return false
    }

    // --- framing ----------------------------------------------------------------
    // A scene says what to frame and from where; the rig does the framing.
    function shotNames() { return root.scene && root.scene.shots ? Object.keys(root.scene.shots) : [] }
    function currentShot() {
        const names = root.shotNames()
        if (names.length === 0) return ""
        if (names.indexOf(root.shot) >= 0) return root.shot
        return root.scene.defaultShot !== undefined && names.indexOf(root.scene.defaultShot) >= 0
             ? root.scene.defaultShot : names[0]
    }
    function frameAll() {
        const s = root.scene
        if (s === null || !s.bounds) return
        const name = root.currentShot()
        const angles = name !== "" ? s.shots[name] : {}
        // a scene may frame differently per shot (a hand close up, the pair
        // from afar), so the shot's name goes with the question. The box is
        // fitted by its eight corners rather than by its sphere: a row of
        // thirteen figures is wide and flat, and a sphere round it holds the
        // row at a third of the height it could have. The safe margins keep
        // the picture out from under the card and the parameter panel.
        const b = s.bounds(name)
        if (!b || b.length < 2) return
        const corners = []
        for (const x of [b[0].x, b[1].x])
            for (const y of [b[0].y, b[1].y])
                for (const z of [b[0].z, b[1].z]) corners.push(Qt.vector3d(x, y, z))
        rig.fit(corners, { yaw: angles.yaw, pitch: angles.pitch, pad: 1.08,
                           safe: { left: (card.x + card.width) / root.width + 0.02,
                                   right: params.width / root.width + 0.03,
                                   top: 0.06, bottom: 0.06 } })
    }
    function frameSelection() { root.frameAll() }
    function goShot(name) {
        if (root.shotNames().indexOf(name) < 0) return false
        root.shot = name
        root.frameAll()
        return true
    }
    function nextShot() {
        const names = root.shotNames()
        if (names.length === 0) return
        const i = names.indexOf(root.currentShot())
        root.goShot(names[(i + 1) % names.length])
    }

    // Shift+R writes a scratch record of a FRAME-driven run, which is not
    // reproducible and must never be quoted. The citable ones come from
    // records/make.sh, which stops the ticker and steps the clock by hand.
    DataRecorder {
        id: recorder
        lab: "character-101"
        destination: "labs/character-101/records/session.labrec"
    }

    // --- the scene ---------------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        environment: stage.environment
        camera: rig.camera

        // Squared paper under every figure: a lift, a crouch and a stride all
        // read against the same rules whichever scene is up.
        LabStage3D {
            id: stage
            cellSize: 2
            majorEvery: 5
            workExtent: Qt.vector2d(100, 60)
            cueSize: 0
            shadowMapFar: 300
        }

        // One rig for every aspect, from a hand at two units to a crowd at
        // three hundred. The near plane is the trap: Qt's default is ten
        // units out, which swallows a head-sized subject whole. Narrow, so a
        // row of figures framed edge to edge keeps its outer ones upright.
        OrbitCamera3D {
            id: rig
            view: view3d
            fieldOfView: 30
            pivot: Qt.vector3d(0, 5, 0)
            yaw: 0; pitch: 6; distance: 90
            minPitch: 1; maxPitch: 88
            minDistance: 1.5; maxDistance: 900
            // The height floor is measured from the HOME pivot's plane, so
            // home stays on the paper: a head standing on the floor is then
            // reachable at a hand's breadth, where a home at mid-figure height
            // would hold the camera fifty units off a face.
            minHeight: 0.3
            smoothMs: 140
            homePivot: Qt.vector3d(0, 0, 0)
            panLeash: stage.workRadius * 1.5
            Component.onCompleted: { camera.clipNear = 0.2; camera.clipFar = 2500 }
        }
        CameraAnchorMark { pointer: nav }

        // The aspect. A scene is a Node from the kit, loaded by the scenario
        // that names it; on arrival it gets the view, the clock and the
        // silhouette toggle, and the camera frames what it declares.
        Loader3D {
            id: sceneLoader
            source: root.aspect === "" ? ""
                  : Qt.resolvedUrl("../kits/character/" + root.aspectFiles[root.aspect])
            onLoaded: {
                const s = sceneLoader.item
                s.view = view3d
                s.time = Qt.binding(() => clock.time)
                s.silhouette = Qt.binding(() => root.silhouette)
                if ("live" in s) s.live = Qt.binding(() => root.live)
                // a scene that moves its own subject (a conversation cutting
                // to the reverse angle) asks for a re-frame through a signal
                // deferred: the signal fires inside the property write that
                // moved the subject, before the scene's own bindings on it
                // (which shot, which box) have settled
                if (s.reframe !== undefined) s.reframe.connect(() => Qt.callLater(root.frameAll))
                if (s.nearest !== undefined) rig.minDistance = s.nearest
                root._flushPending()
                root.frameAll()
            }
        }
    }

    // --- navigation ---------------------------------------------------------------
    // Nothing here is built or selected, so the left button has no rival tool
    // and may pan.
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

    // The scene's labels - a phase under each frozen figure, a name over each
    // face - pinned to the world by the kernel's chip.
    Repeater {
        model: root.scene && root.scene.labels ? root.scene.labels : []
        WorldLabel {
            required property var modelData
            view: view3d
            camera: view3d.camera
            worldPosition: modelData.at
            text: modelData.text
            placement: modelData.above ? WorldLabel.Above : WorldLabel.Below
            active: !LabView.focus
        }
    }

    // --- HUD: palette top-left ------------------------------------------------------
    LabPanel {
        id: palette
        objectName: "palette"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(250)
        title: LabLang.t("lab.title")
        spacing: LabTheme.spaceS

        ScenarioBar { lab: root; width: palette.body.width }
        FlowChip { flow: tour }
    }

    // The aspect card: what this scene is for, its choices, its readings and
    // the shots it is judged from. One card, whichever scene is up.
    LabPanel {
        id: card
        objectName: "card"
        visible: root.showReadout && root.scene !== null
        anchors.left: palette.left
        anchors.top: palette.bottom
        anchors.topMargin: LabTheme.px(10)
        width: LabTheme.px(250)
        title: root.aspect !== "" ? LabLang.t("scenario." + root.aspect).toUpperCase() : ""
        tag: "V"
        spacing: LabTheme.spaceS

        Text {
            width: card.body.width
            wrapMode: Text.WordWrap
            text: root.aspect !== "" ? LabLang.t("aspect." + root.aspect + ".for") : ""
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }

        // the choices: one row of chips per string-valued knob
        Repeater {
            model: root.scene && root.scene.choices ? root.scene.choices : []
            Column {
                id: choiceRow
                required property var modelData
                width: card.body.width
                Text {
                    text: LabLang.t(choiceRow.modelData.key)
                    color: LabTheme.inkFaint
                    font.pixelSize: LabTheme.fontMicro
                    font.family: LabTheme.monoFont
                }
                Quick.Flow {
                    width: card.body.width
                    spacing: LabTheme.spaceXs
                    Repeater {
                        model: choiceRow.modelData.options
                        Rectangle {
                            id: chip
                            required property var modelData
                            readonly property bool active: choiceRow.modelData.current === modelData.value
                            height: LabTheme.px(20); radius: LabTheme.radius
                            width: chipLabel.implicitWidth + LabTheme.px(14)
                            color: active ? LabTheme.secondary : LabTheme.paper
                            border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                            border.width: LabTheme.borderWidth
                            Text {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: LabLang.t(chip.modelData.key)
                                color: LabTheme.inkOn(chip.color)
                                font.pixelSize: LabTheme.fontMicro
                                font.family: LabTheme.monoFont
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.act(choiceRow.modelData.verb, [chip.modelData.value])
                            }
                        }
                    }
                }
            }
        }

        // the readings: sampled, not bound - at the sim rate the last digit
        // is a blur, and a scene's report() walks its joints
        Column {
            id: readings
            width: card.body.width
            property var rows: []
            Timer {
                interval: 250; running: card.visible; repeat: true
                onTriggered: readings.rows = root.scene && root.scene.readout ? root.scene.readout() : []
            }
            Repeater {
                model: readings.rows
                // a reading is one line; a list (the factors off neutral) wraps
                // under its own name when the scene marks it `wrap`
                Column {
                    id: readingRow
                    required property var modelData
                    width: readings.width
                    Row {
                        width: readings.width
                        spacing: LabTheme.spaceS
                        Text {
                            width: readingRow.modelData.wrap ? readings.width : readings.width * 0.42
                            elide: Text.ElideRight
                            text: LabLang.t(readingRow.modelData.key)
                            color: LabTheme.inkFaint
                            font.pixelSize: LabTheme.fontSmall
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            visible: !readingRow.modelData.wrap
                            width: readings.width * 0.58 - LabTheme.spaceS
                            elide: Text.ElideRight
                            text: readingRow.modelData.value
                            color: LabTheme.ink
                            font.pixelSize: LabTheme.fontSmall
                            font.family: LabTheme.monoFont
                        }
                    }
                    Text {
                        visible: readingRow.modelData.wrap === true
                        width: readings.width
                        wrapMode: Text.WordWrap
                        text: readingRow.modelData.value
                        color: LabTheme.ink
                        font.pixelSize: LabTheme.fontSmall
                        font.family: LabTheme.monoFont
                    }
                }
            }
        }

        // the shots: where a scene is judged from
        Quick.Flow {
            width: card.body.width
            spacing: LabTheme.spaceXs
            Repeater {
                model: root.shotNames()
                Rectangle {
                    id: shotChip
                    required property var modelData
                    readonly property bool active: root.currentShot() === modelData
                    height: LabTheme.px(20); radius: LabTheme.radius
                    width: shotLabel.implicitWidth + LabTheme.px(14)
                    color: active ? LabTheme.primary : LabTheme.paper
                    border.color: active ? LabTheme.primary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        id: shotLabel
                        anchors.centerIn: parent
                        text: LabLang.t("shot." + shotChip.modelData)
                        color: LabTheme.inkOn(shotChip.color)
                        font.pixelSize: LabTheme.fontMicro
                        font.family: LabTheme.monoFont
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.goShot(shotChip.modelData) }
                }
            }
        }
    }

    // --- HUD: language, size, theme top-right, the scene's knobs under them -----
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

    // --- HUD: the plot, bottom-right --------------------------------------------------
    // Every probe the loaded scene registered, so the plot is the scene's.
    Plot2D {
        id: plot
        objectName: "plot"
        visible: root.showPlot
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: LabTheme.px(10)
        width: LabTheme.px(380)
        height: LabTheme.px(180)
        windowSeconds: root.scene && root.scene.plotWindow ? root.scene.plotWindow : 10
        placeholder: LabLang.t("plot.empty")
        // bound, not the empty "all" default: a scene swap re-registers the
        // probes and the plot has to follow rather than keep the last name
        probes: Lab.probeNames
    }

    // --- HUD: banner, hint bar, transport, recording -------------------------------------
    LabBanner {
        active: root.scene !== null && root.scene.ready === false
        guard: palette
        text: LabLang.t("banner.posing")
    }
    HintBar {
        id: hintBar
        flow: tour
        rightGuard: plot
        leftGuard: card
        text: root.aspect !== "" ? LabLang.t("hint." + root.aspect) : LabLang.t("hint.idle")
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

    // --- the tour ---------------------------------------------------------------------------
    // One idea per aspect, in the order a character is put together: a body,
    // a walk, the arms, the face, the voice, and what it all costs. No step
    // waits for a scene's `ready`: that is a wall-clock thing (a first-pose
    // timer, a solver settling) and Lab.runFlow() steps the sim clock with
    // no wall clock in between, so every expect reads a number the pure pose
    // model answers before a frame has been drawn.
    Flow {
        id: tour
        lab: root
        camera: rig
        flowId: "character-tour"
        titleKey: "flow.character-tour.title"

        FlowStep {
            key: "lineup"
            demo: [["scenario", "lineup"], ["shot", "front"]]
            expect: () => root.scene !== null && root.scene.report().count === 6
        }
        FlowStep {
            key: "gait"
            demo: [["scenario", "gait"], ["preset", "elderly"], ["shot", "side"]]
            // 800 ms over a tempo of 0.72: 1.111 s, measured
            expect: () => Math.abs(root.scene.report().cycleS - 1.1111) < 1e-3
        }
        FlowStep {
            key: "gaitTop"
            demo: [["shot", "top"]]
        }
        FlowStep {
            key: "try"
            task: ({ "until": () => root.scene !== null && root.aspect === "gait"
                                   && root.scene.report().base === "run",
                     "hint": "flow.character-tour.try.hint",
                     "hintAfter": 8,
                     "solve": [["base", "run"]] })
        }
        FlowStep {
            key: "run"
            // 450 ms over a tempo of 0.72: 0.625 s, measured
            expect: () => Math.abs(root.scene.report().cycleS - 0.625) < 1e-3
        }
        FlowStep {
            key: "gestures"
            demo: [["scenario", "gestures"], ["shot", "quarter"]]
            // thirteen columns, and a guard is an elbow folded past a right angle
            expect: () => root.scene.report().count === 13 && root.scene.report().guardElbow < -100
        }
        FlowStep {
            key: "silhouette"
            demo: [["silhouette", true]]
        }
        FlowStep {
            key: "action"
            demo: [["silhouette", false], ["scenario", "action"], ["action", "fight"], ["shot", "quarter"]]
            // the boxing loop at intensity 0.5: 1.70 s, measured
            expect: () => Math.abs(root.scene.report().cycleS - 1.7) < 0.02
        }
        FlowStep {
            key: "moves"
            demo: [["scenario", "moves"], ["shot", "quarter"]]
            // fourteen moves, and the stance keeps both feet within a toe of the floor
            expect: () => root.scene.report().count === 14 && root.scene.report().footLow > -0.05
        }
        FlowStep {
            key: "hands"
            demo: [["scenario", "hands"], ["pose", "point"], ["shot", "hand"]]
            // the bench build's palm is a tenth wider than the arm it hangs off
            expect: () => Math.abs(root.scene.report().palmArm - 1.10) < 0.02
        }
        FlowStep {
            key: "faces"
            demo: [["scenario", "faces"], ["shot", "face"]]
            // the closest pair of the six, in uniform space: 1.206 on the committed table
            expect: () => Math.abs(root.scene.report().distinct - 1.206) < 0.01
        }
        FlowStep {
            key: "heads"
            demo: [["scenario", "heads"], ["activity", "talk"], ["shot", "work"]]
            expect: () => root.scene.report().tiers.length === 3
        }
        FlowStep {
            key: "speech"
            demo: [["scenario", "speech"], ["play", "hello"], ["shot", "face"]]
            expect: () => root.scene.report().recording === "hello"
        }
        FlowStep {
            key: "conversation"
            demo: [["scenario", "conversation"], ["listening", true], ["say", ""], ["shot", "over"]]
            expect: () => root.scene.report().listening === true
        }
        FlowStep {
            key: "crowd"
            demo: [["scenario", "crowd"], ["setParam", "count", 20], ["shot", "quarter"]]
            // twenty characters at Low are 440 boxes before the stage adds its own draws
            expect: () => root.scene.report().count === 20 && root.scene.report().expectedDraws >= 440
        }
        FlowStep { key: "handoff" }
    }
    Narrator {
        flow: tour
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.px(10)
        width: Math.max(LabTheme.px(280),
                        Math.min(LabTheme.px(680),
                                 2 * (plot.x - root.width / 2 - LabTheme.spaceL)))
    }

    // --- keys -----------------------------------------------------------------------------------
    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        flow: tour
        recorder: recorder
        keys: [
            { key: "V", label: "key.readout", action: () => root.showReadout = !root.showReadout },
            { key: "M", label: "key.plot", action: () => root.showPlot = !root.showPlot },
            { key: "S", label: "key.silhouette", action: () => root.silhouette = !root.silhouette },
            { key: "N", label: "key.shot", action: () => root.nextShot() }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: LabTheme.px(320)
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) root.applyScenario(Lab.scenario || "lineup")
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
