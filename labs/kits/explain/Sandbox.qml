// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The explain bench (#269): four ways of showing what a part hides, on one
// subject, with one professor, switchable by scenario.
//
//   1 exploded view   the transistor comes apart in place
//   2 callouts        rings and captioned cards on its sub-parts, the case ghosted
//   3 chalkboard      a documentary cut to a slate that draws itself
//   4 dive in         the professor shrinks and the camera flies into the die
//
// Each scenario has its own lesson on T, and all four lessons teach the same
// thing - three legs, three layers, a small current steering a large one - so
// what is being compared is the mechanism and never the words. Deliberately
// a kit bench and not a lab: it has no experiment, no probes worth a record,
// and the question it answers is "which of these should the kernel grow".
//
// Keys: 1-4 approaches · T lesson · E take apart / together · X x-ray · Z focus
// next part · N / L / U callouts next / all / none · O chalkboard · Y draw ·
// G switch the drawing · I dive in / out · B base current. Camera as
// everywhere: right-drag turns, middle drags, wheel zooms, Space+left pans.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../professor"
import "strings.js" as Strings
import "anatomy.js" as Anatomy
import "chalk.js" as Chalk

Item {
    id: root
    anchors.fill: parent
    focus: true
    objectName: "explainBench"

    Component.onCompleted: {
        // Vocabulary first, then the scenario that reads it.
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("exploded")
        prof.appear()
        frameAll()
    }

    // The flows run in sim time, and the interior's carriers move with it -
    // one clock, so a stepped headless run and a live one see the same beats.
    SimClock { id: clock; seed: 7; fixedStep: 1 / 60 }

    // --- the approach --------------------------------------------------------
    // The scenario IS the approach. Switching resets every mechanism to its
    // resting state and stops whatever lesson was running, because the four
    // lessons drive four different things and a half-exploded part under a
    // chalkboard is nobody's lesson.
    readonly property string approach: Lab.scenario
    readonly property var approaches: ["exploded", "callouts", "chalkboard", "inside"]

    ScenarioSet {
        id: scenarioSet
        Scenario { name: "exploded";   script: () => root.resetMechanisms() }
        Scenario { name: "callouts";   script: () => root.resetMechanisms() }
        Scenario { name: "chalkboard"; script: () => root.resetMechanisms() }
        Scenario { name: "inside";     script: () => root.resetMechanisms() }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        for (const f of [explodedFlow, calloutFlow, chalkFlow, diveFlow])
            if (f.running) f.stop()
        const r = scenarioSet.apply(n)
        frameAll()
        return r
    }
    function resetMechanisms() {
        assembly.spread = 0
        assembly.xray = 0
        assembly.focus = ""
        callouts.revealed = 0
        chalk.shown = false
        chalk.progress = 0
        root.chalkDrawing = "section"
        if (dive.inside) dive.leave()
        root.iB = 0.3
        root.iC = 0.8
    }

    // --- the subject ---------------------------------------------------------
    // One transistor at the origin of a piece of pegboard, at the circuit
    // kit's scale (a part is nine units across with its pads). The currents
    // are the electronics lab's own numbers for its `transistor` preset,
    // normalised: 0.8 mA into the base, 9.8 mA through the lamp.
    readonly property vector3d partPos: Qt.vector3d(0, 0, 0)
    property real iB: 0.3
    property real iC: 0.8

    // Where a mark or a finger lands for a name: the anatomy answers its own
    // ids, the interior answers the layer names while we are inside, and
    // "part" is the whole thing. Null for a name nobody can place.
    function resolveName(name) {
        if (!name) return null
        if (name === "part" || name === "the transistor")
            return Qt.vector3d(root.partPos.x, 1.6, root.partPos.z)
        if (dive.inside && interior.partAt) {
            const q = interior.partAt(name)
            if (q && q.x === q.x) return q
        }
        const p = assembly.partAt(name)
        if (!p || p.x !== p.x) return null   // NaN: not one of ours
        return p
    }

    // Every part of the assembly as it stands now, for a camera that has to
    // hold the whole explosion, plus the ground under it so the fit keeps
    // the board in the picture.
    function assemblyPoints() {
        assembly.spreadNow
        const pts = [Qt.vector3d(root.partPos.x - 5, 0, root.partPos.z - 5),
                     Qt.vector3d(root.partPos.x + 5, 0, root.partPos.z + 5)]
        for (const id of assembly.partIds) {
            const p = assembly.partAt(id)
            if (p && p.x === p.x) pts.push(p)
        }
        return pts
    }

    // The professor stands beside the part, on the far side (smaller z): the
    // rig looks down the board from +z and a figure nearer the camera than
    // the part it points at hides it.
    readonly property real profClear: 9
    function standBeside(side) {
        return Qt.vector3d(root.partPos.x + side * root.profClear, 0, root.partPos.z - 3)
    }

    // --- the lessons' choreography, as data --------------------------------
    // Per flow, per step: which part the line is about (`part`), which side
    // of it the professor stands on (`side`, 0 = stay where you are, absent =
    // no flight), whether the camera holds the whole assembly (`wide`) and
    // whether it stays on the two-shot for the step (`hold`). What the
    // professor SAYS is in strings.js; this is only where it stands and what
    // it points at.
    readonly property var choreography: ({
        "explain-exploded": {
            "meet":   { part: "case",          side: 1 },
            "legs":   { part: "leg.base",      side: 1,  hold: true },
            "open":   { part: "case",          side: -1, wide: true, hold: true },
            "die":    { part: "die.collector", side: -1, wide: true, hold: true },
            "layers": { part: "die.base",      side: -1, wide: true, hold: true },
            "wires":  { part: "wires",         side: -1, wide: true, hold: true },
            "close":  { part: "case",          side: 1 }
        },
        "explain-callouts": {
            "meet":   { part: "case",          side: 1 },
            "legs":   { part: "leg.base",      side: 1,  hold: true },
            "case":   { part: "case",          side: 1,  hold: true },
            "inside": { part: "die.base",      side: 1,  hold: true },
            "all":    { part: "part",          side: 1,  hold: true }
        },
        "explain-chalkboard": {
            "meet":     { part: "case",        side: 1 },
            "layers":   { },
            "currents": { },
            "graph":    { },
            "back":     { part: "case",        side: 1 }
        },
        "explain-inside": {
            "meet":    { part: "case",         side: 1 },
            "dive":    { },
            "layers":  { part: "base",         side: 0, hold: true },
            "flow":    { part: "junction.eb",  side: 0, hold: true },
            "control": { part: "base",         side: 0, hold: true },
            "surface": { }
        }
    })

    function flowSubject(i) {
        const f = root.currentFlow
        if (!f || !f.step) return null
        const table = root.choreography[f.flowId]
        const c = table ? table[f.step.key] : undefined
        if (!c || !c.part) return null
        const look = root.resolveName(c.part)
        const s = { look: look, hold: !!c.hold }
        // Inside the die the professor is where the dive put it; a stand
        // would fly it back onto the board.
        if (c.side !== undefined && c.side !== 0 && !dive.inside)
            s.stand = root.standBeside(c.side)
        if (c.wide) s.extent = root.assemblyPoints()
        return s
    }

    // --- flow actions --------------------------------------------------------
    // One mutation API, three drivers: the buttons below, the lessons and an
    // agent's eval all go through these verbs. Each sets a GOAL; the eased
    // interpolants are read-only, which is what lets Lab.runFlow assert them
    // without an event loop.
    function flowActions() {
        return {
            "explode":  (v) => { assembly.spread = v === undefined ? 1 : v },
            // 1 would delete the case (opacity is 1 - xray); a ghost keeps the part recognisable
            "xray":     (v) => { assembly.xray = v === undefined ? 0.75 : v },
            "focus":    (id) => { assembly.focus = id === undefined || id === null ? "" : id },
            "callouts": (n) => { callouts.revealed = n === undefined ? -1 : n },
            "chalk":    (what, progress) => setChalk(what, progress),
            "dive":     (on) => { if (on === undefined || on) dive.enter(); else dive.leave() },
            "currents": (ib, ic) => { root.iB = ib; root.iC = ic },
            "scenario": (n) => applyScenario(n),
            "frame":    (what) => what === "assembly" ? frameAssembly() : frameAll()
        }
    }
    // "section" or "gain" draws that drawing (from the start unless a
    // progress is given); "off" closes the board.
    property string chalkDrawing: "section"
    function setChalk(what, progress) {
        if (!what || what === "off") { chalk.shown = false; return }
        if (root.chalkDrawing !== what) { chalk.progress = 0; root.chalkDrawing = what }
        chalk.shown = true
        chalk.progress = progress === undefined ? 1 : progress
    }
    readonly property var chalkLabels: ({
        n: LabLang.t("explain.chalk.n"), p: LabLang.t("explain.chalk.p"),
        collector: LabLang.t("explain.chalk.collector"),
        base: LabLang.t("explain.chalk.base"),
        emitter: LabLang.t("explain.chalk.emitter"),
        ib: LabLang.t("explain.chalk.ib"), ic: LabLang.t("explain.chalk.ic"),
        ibAxis: LabLang.t("explain.chalk.ibAxis"), icAxis: LabLang.t("explain.chalk.icAxis"),
        beta: LabLang.t("explain.chalk.beta")
    })

    function flows() { return [explodedFlow.flowId, calloutFlow.flowId,
                               chalkFlow.flowId, diveFlow.flowId] }
    function startFlow(id) {
        for (const f of [explodedFlow, calloutFlow, chalkFlow, diveFlow])
            if (f.flowId === id) {
                // a lesson belongs to its approach, so starting one switches
                const a = root.approaches[root.flows().indexOf(id)]
                if (Lab.scenario !== a) applyScenario(a)
                f.start()
                return true
            }
        return false
    }
    // Whichever lesson is running wins; otherwise the current approach's.
    readonly property var currentFlow: {
        for (const f of [explodedFlow, calloutFlow, chalkFlow, diveFlow])
            if (f.running) return f
        const i = root.approaches.indexOf(root.approach)
        return [explodedFlow, calloutFlow, chalkFlow, diveFlow][i < 0 ? 0 : i]
    }

    // --- lesson 1: the exploded view --------------------------------------
    Flow {
        id: explodedFlow
        lab: root
        camera: rig
        flowId: "explain-exploded"
        titleKey: "flow.explain-exploded.title"
        FlowStep { key: "meet";   demo: [["explode", 0], ["xray", 0], ["focus", ""]]
                   mark: ["case"] }
        FlowStep { key: "legs";   mark: ["leg.collector", "leg.base", "leg.emitter"] }
        FlowStep { key: "open";   demo: [["explode", 1]]; mark: ["case"]
                   expect: () => assembly.spread === 1 }
        FlowStep { key: "die";    demo: [["focus", "die.collector"]]; mark: ["die.collector"] }
        FlowStep { key: "layers"; demo: [["focus", "die.base"]]
                   mark: ["die.collector", "die.base", "die.emitter"]
                   expect: () => assembly.focus === "die.base" }
        FlowStep { key: "wires";  demo: [["focus", "wires"]]; mark: ["wires"] }
        FlowStep { key: "close";  demo: [["focus", ""], ["explode", 0]]
                   expect: () => assembly.spread === 0 && assembly.focus === "" }
    }

    // --- lesson 2: callouts ------------------------------------------------
    Flow {
        id: calloutFlow
        lab: root
        camera: rig
        flowId: "explain-callouts"
        titleKey: "flow.explain-callouts.title"
        FlowStep { key: "meet";   demo: [["callouts", 0], ["xray", 0]] }
        FlowStep { key: "legs";   demo: [["callouts", 3]]
                   expect: () => callouts.revealed === 3 }
        FlowStep { key: "case";   demo: [["callouts", 5], ["xray", 0.75]]
                   expect: () => assembly.xray === 0.75 }
        FlowStep { key: "inside"; demo: [["callouts", 9]] }
        FlowStep { key: "all";    demo: [["callouts", -1]]
                   expect: () => callouts.revealed === -1 && callouts.shownCount === callouts.count }
    }

    // --- lesson 3: the chalkboard ---------------------------------------------
    Flow {
        id: chalkFlow
        lab: root
        camera: rig
        flowId: "explain-chalkboard"
        titleKey: "flow.explain-chalkboard.title"
        FlowStep { key: "meet";     demo: [["chalk", "off"]]; mark: ["case"] }
        FlowStep { key: "layers";   demo: [["chalk", "section", 0.55]]
                   expect: () => chalk.shown && root.chalkDrawing === "section" }
        FlowStep { key: "currents"; demo: [["chalk", "section", 1]]
                   expect: () => chalk.progress === 1 }
        FlowStep { key: "graph";    demo: [["chalk", "gain", 1]]
                   expect: () => root.chalkDrawing === "gain" }
        FlowStep { key: "back";     demo: [["chalk", "off"], ["frame", "all"]]
                   expect: () => !chalk.shown }
    }

    // --- lesson 4: the dive ---------------------------------------------------
    Flow {
        id: diveFlow
        lab: root
        camera: rig
        flowId: "explain-inside"
        titleKey: "flow.explain-inside.title"
        FlowStep { key: "meet";    demo: [["dive", false], ["currents", 0.3, 0.8]]; mark: ["case"] }
        FlowStep { key: "dive";    demo: [["dive", true]]
                   expect: () => dive.inside }
        FlowStep { key: "layers";  mark: ["emitter", "base", "collector"] }
        FlowStep { key: "flow";    mark: ["junction.eb"] }
        FlowStep { key: "control"; demo: [["currents", 0, 0]]
                   expect: () => root.iB === 0 && root.iC === 0 }
        FlowStep { key: "surface"; demo: [["currents", 0.3, 0.8], ["dive", false]]
                   expect: () => !dive.inside }
    }

    // --- camera ----------------------------------------------------------------
    // The part and, once it has arrived, the professor beside it: the
    // opening shot is a two-shot of the bench, not a close-up of a lump.
    function frameAll() {
        let pts = [Qt.vector3d(root.partPos.x - 7, 0, root.partPos.z - 7),
                   Qt.vector3d(root.partPos.x + 7, 4, root.partPos.z + 7)]
        if (prof.present) pts = pts.concat(director.presenterPoints())
        rig.fit(pts, { pitch: 26, pad: 1.15, safe: director.safe })
    }
    function frameAssembly() {
        rig.fit(root.assemblyPoints(), { pitch: 24, pad: 1.25, safe: director.safe })
    }
    function frameSelection() { frameAssembly() }

    // --- the scene ---------------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        LabStage3D {
            id: stage
            cellSize: 5
            majorEvery: 4
            gridMode: grid
            workExtent: Qt.vector2d(60, 40)
            shadowMapFar: 120
        }
        CameraAnchorMark { pointer: nav }

        // The subject: the transistor with its inside modelled. Every
        // approach explains THIS node; the interior below is what the dive
        // shows in its place.
        TransistorAnatomy3D {
            id: assembly
            objectName: "assembly"
            position: root.partPos
        }

        // The die as a landscape, at part scale, standing where the anatomy's
        // die stands; hidden until the dive brings the camera to it.
        TransistorInterior3D {
            id: interior
            objectName: "interior"
            position: Qt.vector3d(root.partPos.x, 0.95, root.partPos.z)
            time: clock.time
            baseCurrent: root.iB
            collectorCurrent: root.iC
            reveal: dive.depth
            visible: dive.depth > 0.001
        }

        Professor {
            id: prof
            objectName: "professor"
            view: view3d
            // The electronics lab's size against a nine-unit part - this is
            // how the professor stands next to a transistor there.
            height3d: 6.2
            travelSpeed: 34
            stand: Qt.vector3d(12, 0, -8)
        }

        CameraDirector {
            id: director
            rig: rig
            presenter: prof
            // The bench panel down the left, the narrator along the bottom.
            safe: ({ top: 0.08, bottom: 0.24, left: 0.18, right: 0.04 })
        }

        FlowGuide {
            id: guide
            professor: prof
            running: root.currentFlow ? root.currentFlow.running : false
            step: root.currentFlow ? root.currentFlow.index : -1
            text: root.currentFlow ? root.currentFlow.narration : ""
            subjectOf: (i) => root.flowSubject(i)
            scriptResolve: (name) => root.resolveName(name)
            marks: root.currentFlow ? root.currentFlow.marks : []
            markLabelOf: (n) => LabLang.t("explain.part." + n)
            // Inside the die the dive owns the camera: a two-shot from the
            // director would restore the board's floors and pull the camera
            // back out through the case.
            director: dive.inside ? null : director
            entrance: Qt.vector3d(12, 0, -8)
            spoken: false
        }

        OrbitCamera3D {
            id: rig
            view: view3d
            pivot: Qt.vector3d(0, 2, 0)
            homePivot: Qt.vector3d(0, 2, 0)
            yaw: 15
            pitch: 30
            distance: 30
            minPitch: 8
            maxPitch: 84
            minDistance: 3
            maxDistance: 120
            minHeight: 1.5
            smoothMs: 140
            panLeash: stage.workRadius
            // A close look at a four-unit part needs the near plane well
            // under Qt's default ten, or the case is sliced open by accident.
            Component.onCompleted: rig.camera.clipNear = 0.3
            viewpoints: ({
                "part": { yaw: 15, pitch: 30, distance: 30, px: 0, py: 2, pz: 0 },
                "wide": { yaw: 15, pitch: 36, distance: 70, px: 0, py: 2, pz: 0 }
            })
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // The journey controller of approach 4. Ghosts the whole anatomy (the
    // interior stands in for its die) while the camera and the professor are
    // inside.
    DiveIn {
        id: dive
        rig: rig
        presenter: prof
        view: view3d
        target: assembly
        interior: interior
        ghosts: [assembly]
    }

    // --- the 2D layers over the scene --------------------------------------------
    // Rings for the names a line speaks (all approaches), the captioned
    // callouts of approach 2, the slate of approach 3.
    MarkLayer {
        id: markLayer
        objectName: "markLayer"
        anchors.fill: parent
        view: view3d
        camera: rig.camera
        marks: guide.markPoints
    }

    readonly property var calloutIds: ["leg.collector", "leg.base", "leg.emitter",
                                       "case", "face", "die.collector", "die.base",
                                       "die.emitter", "wires"]
    // Points follow the assembly (it may be x-rayed but not exploded here),
    // captions follow the language.
    readonly property var calloutList: {
        assembly.spreadNow
        LabLang.lang
        const out = []
        for (const id of root.calloutIds) {
            const p = assembly.partAt(id)
            if (!p || p.x !== p.x) continue
            out.push({ at: p, label: LabLang.t("explain.part." + id),
                       detail: LabLang.t("explain.detail." + id), side: "auto" })
        }
        return out
    }
    CalloutLayer {
        id: callouts
        objectName: "callouts"
        anchors.fill: parent
        view: view3d
        camera: rig.camera
        callouts: root.calloutList
        revealed: 0
    }

    Chalkboard {
        id: chalk
        objectName: "chalk"
        anchors.fill: parent
        drawing: root.chalkDrawing === "gain"
                 ? Chalk.gainGraph(12, root.chalkLabels)
                 : Chalk.transistorSection(root.chalkLabels)
        // The board carries the line while it is up: the professor is behind
        // the scrim, and a bubble seen through it is a bubble nobody reads.
        caption: root.currentFlow && root.currentFlow.running ? root.currentFlow.narration : ""
    }

    // --- chrome -------------------------------------------------------------------
    SceneTitle { anchors.fill: parent; text: director.title }

    Narrator {
        flow: root.currentFlow
        showText: !prof.present && !chalk.shown
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
        width: Math.min(LabTheme.px(680), root.width - 2 * LabTheme.px(240))
    }

    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.spaceXl
        spacing: LabTheme.spaceM
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ScaleSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }

    // The bench panel: the approaches as preset chips, the current one's
    // controls, and the offer of its lesson.
    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(230)
        title: LabLang.t("explain.title")
        tag: "?"

        component BenchButton: Rectangle {
            id: btn
            property string label: ""
            property bool active: false
            signal hit()
            width: controls.body.width
            height: LabTheme.px(24)
            radius: LabTheme.px(4)
            color: btn.active ? LabTheme.secondary
                 : hover.containsMouse ? LabTheme.step(LabTheme.panel, 1.2)
                                       : LabTheme.panel
            border.color: LabTheme.panelEdge
            border.width: Math.max(1, LabTheme.uiScale)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: LabTheme.spaceL
                anchors.right: parent.right
                anchors.rightMargin: LabTheme.spaceS
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                elide: Text.ElideRight
                color: btn.active ? LabTheme.inkOn(LabTheme.secondary) : LabTheme.ink
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.forceActiveFocus(); btn.hit() }
            }
        }

        ScenarioBar { lab: root; width: controls.body.width }
        Item { width: 1; height: LabTheme.spaceM }

        // approach 1
        BenchButton {
            visible: root.approach === "exploded"
            label: (assembly.spread > 0.5 ? LabLang.t("explain.btn.assemble")
                                          : LabLang.t("explain.btn.explode")) + "  (E)"
            active: assembly.spread > 0.5
            onHit: root.toggleExplode()
        }
        BenchButton {
            visible: root.approach === "exploded"
            label: LabLang.t("explain.btn.focus") + "  (Z)"
            active: assembly.focus !== ""
            onHit: root.focusNext()
        }
        // approach 2
        BenchButton {
            visible: root.approach === "callouts"
            label: LabLang.t("explain.btn.callout.next") + "  (N)"
            onHit: root.calloutNext()
        }
        BenchButton {
            visible: root.approach === "callouts"
            label: LabLang.t("explain.btn.callout.all") + "  (L)"
            active: callouts.revealed === -1
            onHit: callouts.revealed = -1
        }
        BenchButton {
            visible: root.approach === "callouts"
            label: LabLang.t("explain.btn.callout.none") + "  (U)"
            onHit: callouts.revealed = 0
        }
        // approaches 1 and 2 share the x-ray
        BenchButton {
            visible: root.approach === "exploded" || root.approach === "callouts"
            label: (assembly.xray > 0.5 ? LabLang.t("explain.btn.solid")
                                        : LabLang.t("explain.btn.xray")) + "  (X)"
            active: assembly.xray > 0.5
            onHit: assembly.xray = assembly.xray > 0.5 ? 0 : 0.75
        }
        // approach 3
        BenchButton {
            visible: root.approach === "chalkboard"
            label: (chalk.shown ? LabLang.t("explain.btn.chalk.close")
                                : LabLang.t("explain.btn.chalk.open")) + "  (O)"
            active: chalk.shown
            onHit: root.toggleChalk()
        }
        BenchButton {
            visible: root.approach === "chalkboard"
            label: LabLang.t("explain.btn.chalk.draw") + "  (Y)"
            onHit: root.drawChalk()
        }
        BenchButton {
            visible: root.approach === "chalkboard"
            label: (root.chalkDrawing === "gain" ? LabLang.t("explain.btn.chalk.section")
                                                  : LabLang.t("explain.btn.chalk.graph")) + "  (G)"
            onHit: root.switchDrawing()
        }
        // approach 4
        BenchButton {
            visible: root.approach === "inside"
            label: (dive.inside ? LabLang.t("explain.btn.dive.out")
                                : LabLang.t("explain.btn.dive.in")) + "  (I)"
            active: dive.inside
            onHit: root.toggleDive()
        }
        BenchButton {
            visible: root.approach === "inside"
            label: LabLang.t("explain.btn.currents") + "  " + LabLang.num(root.iB, 1) + "  (B)"
            onHit: root.cycleCurrents()
        }
        Item { width: 1; height: LabTheme.spaceM }
        FlowChip { flow: root.currentFlow }
    }

    // What the mechanisms are doing, in numbers - the bench's answer to
    // "is it the picture or the state that is wrong".
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: LabTheme.px(56)
        anchors.rightMargin: LabTheme.px(12)
        width: LabTheme.px(200)
        title: LabLang.t("explain.state")
        Text {
            text: "approach  " + root.approach
                + "\nspread    " + LabLang.num(assembly.spreadNow, 2)
                + "\nxray      " + LabLang.num(assembly.xrayNow, 2)
                + "\nfocus     " + (assembly.focus === "" ? "-" : assembly.focus)
                + "\ncallouts  " + callouts.shownCount + "/" + callouts.count
                + "\nchalk     " + (chalk.shown ? root.chalkDrawing + " " + LabLang.num(chalk.progressNow, 2) : "-")
                + "\ndive      " + LabLang.num(dive.depth, 2)
                + "\ncurrents  " + LabLang.num(root.iB, 1) + " / " + LabLang.num(root.iC, 1)
                + "\nlesson    " + (root.currentFlow && root.currentFlow.running
                                     ? (root.currentFlow.index + 1) + "/" + root.currentFlow.steps.length
                                     : "-")
                + "\nprof      " + (prof.gesture === "" ? "-" : prof.gesture)
                + (prof.travelling ? " flying" : "")
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // --- the bench verbs the buttons and keys share ---------------------------
    function toggleExplode() { assembly.spread = assembly.spread > 0.5 ? 0 : 1 }
    function focusNext() {
        const ids = assembly.idsInOrder()
        const i = ids.indexOf(assembly.focus)
        assembly.focus = i + 1 < ids.length ? ids[i + 1] : ""
    }
    function calloutNext() {
        const n = callouts.revealed < 0 ? callouts.count : callouts.revealed
        callouts.revealed = n >= callouts.count ? 0 : n + 1
    }
    function toggleChalk() {
        if (chalk.shown) chalk.shown = false
        else setChalk(root.chalkDrawing, chalk.progress)
    }
    function drawChalk() {
        if (!chalk.shown) setChalk(root.chalkDrawing, 0)
        chalk.progress = chalk.progress >= 1 ? 0 : 1
    }
    function switchDrawing() {
        setChalk(root.chalkDrawing === "gain" ? "section" : "gain", 1)
    }
    function toggleDive() { if (dive.inside) dive.leave(); else dive.enter() }
    function cycleCurrents() {
        root.iB = root.iB >= 1 ? 0 : (root.iB >= 0.3 ? 1 : 0.3)
        root.iC = root.iB === 0 ? 0 : 0.8
    }

    // --- conventions: what an agent and the loader read ---------------------------
    function labInfo() {
        const info = Lab.labInfo()
        info.explain = report()
        return info
    }
    function flagInfo() { return labInfo() }
    function report() {
        return { approach: root.approach,
                 spread: assembly.spread, spreadNow: assembly.spreadNow,
                 xray: assembly.xray, focus: assembly.focus,
                 callouts: callouts.revealed, calloutsShown: callouts.shownCount,
                 calloutCount: callouts.count,
                 chalk: { shown: chalk.shown, drawing: root.chalkDrawing,
                          progress: chalk.progress, progressNow: chalk.progressNow },
                 inside: dive.inside, depth: dive.depth,
                 iB: root.iB, iC: root.iC,
                 lesson: root.currentFlow ? root.currentFlow.flowId : "",
                 lessonStep: root.currentFlow ? root.currentFlow.index : -1,
                 marks: markLayer.count }
    }

    // The mechanisms' goals and the camera, so an edit to any file here does
    // not put the part back together under a half-drawn board.
    function viewState() {
        return { spread: assembly.spread, xray: assembly.xray, focus: assembly.focus,
                 callouts: callouts.revealed,
                 chalkShown: chalk.shown, chalkDrawing: root.chalkDrawing,
                 chalkProgress: chalk.progress,
                 inside: dive.inside, iB: root.iB, iC: root.iC,
                 sx: prof.stand.x, sy: prof.stand.y, sz: prof.stand.z,
                 heading: prof.heading,
                 cam: rig.state() }
    }
    function applyViewState(s) {
        if (!s) return
        if (s.spread !== undefined) assembly.spread = s.spread
        if (s.xray !== undefined) assembly.xray = s.xray
        if (s.focus !== undefined) assembly.focus = s.focus
        if (s.callouts !== undefined) callouts.revealed = s.callouts
        if (s.chalkDrawing !== undefined) root.chalkDrawing = s.chalkDrawing
        if (s.chalkProgress !== undefined) chalk.progress = s.chalkProgress
        if (s.chalkShown !== undefined) chalk.shown = s.chalkShown
        if (s.iB !== undefined) root.iB = s.iB
        if (s.iC !== undefined) root.iC = s.iC
        if (s.cam) rig.applyState(s.cam)
        if (s.sx !== undefined) prof.stand = Qt.vector3d(s.sx, s.sy, s.sz)
        if (s.heading !== undefined) prof.heading = s.heading
        if (s.inside) dive.enter()
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        flow: root.currentFlow
        keys: [
            { key: "E", label: "explain.key.explode", action: () => root.toggleExplode() },
            { key: "X", label: "explain.key.xray",
              action: () => { assembly.xray = assembly.xray > 0.5 ? 0 : 0.75 } },
            { key: "Z", label: "explain.key.focus", action: () => root.focusNext() },
            { key: "N", label: "explain.key.callout.next", action: () => root.calloutNext() },
            { key: "L", label: "explain.key.callout.all", action: () => { callouts.revealed = -1 } },
            { key: "U", label: "explain.key.callout.none", action: () => { callouts.revealed = 0 } },
            { key: "O", label: "explain.key.chalk", action: () => root.toggleChalk() },
            { key: "Y", label: "explain.key.chalk.draw", action: () => root.drawChalk() },
            { key: "G", label: "explain.key.chalk.graph", action: () => root.switchDrawing() },
            { key: "I", label: "explain.key.dive", action: () => root.toggleDive() },
            { key: "B", label: "explain.key.currents", action: () => root.cycleCurrents() }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(320) }

    Keys.onPressed: (ev) => keymap.handle(ev)
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
