// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "strings.js" as Strings

// Hydraulics 101 - parts on a pegboard, wired together and solved. Started
// 2026-09-02 from tools/lab-new (kind: build, purpose: teaching).
//
// THIS IS A STARTING POINT, NOT A LAB. Everything below runs, so you can
// change one thing at a time and keep a loadable lab throughout. What is
// yours to replace: the DOMAIN - the part spec, the solver, what a part
// reads and how it is drawn - which belongs in a kit under labs/kits/<domain>/
// (pure JS model with a node suite, a QML part visual, a strings.js); the
// scenarios; the flow; every string in strings.js. What is NOT yours to
// replace: the conventions block, the key map and the HUD slots - an agent,
// a flow and the dojo all address every lab through those.
//
// A BUILD lab places typed parts on a grid, wires their pads and solves the
// result. The kernel's Board owns all of that mechanism: grid, pads, hit test,
// the mouse gesture (BoardInput), the wires (BoardWires3D), the placer tool,
// the palette, the selection card and the readings over the board. The lab
// says what a part IS (spec), what the wired-up board MEANS (solve) and what
// each part READS (readingOf).
//
// Keys: 1-2 presets · T tour · C clear · E eraser · V values · Q plot the
// selection · R turn · # grid · Del remove · f jump · ⇧F frame · 0 reset ·
// arrows/WASD travel · Shift+arrows turn · +/- zoom · Space holds the view ·
// H instruments · Shift+R record · Ctrl +/-/0 text size · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true

    // Register the dictionary BEFORE the first scenario. A kit's vocabulary
    // would be registered first, on the line above, so this lab's copy can
    // override it.
    Component.onCompleted: {
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("intro")
    }

    // --- the domain: what a part is -----------------------------------------
    // The board's contract, as data. Move this to labs/kits/<domain>/parts.js
    // the moment it has a second consumer. Two pads in a line is the rule;
    // `half` is the body footprint; `actuator` is the region you OPERATE
    // (tested before the pads); `fields` the domain state with its defaults;
    // `rows` the card rows this type offers. The keep-out derives from `half`.
    readonly property var spec: ({
        block: { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }],
                 half: { x: 4.6, y: 3.4 }, actuator: null,
                 fields: { value: 1, on: false }, rows: ["value"] },
        lever: { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }],
                 half: { x: 4.6, y: 3.4 }, actuator: { x: 2.6, y: 2.0 },
                 fields: { value: 0, on: false }, rows: ["state"] }
    })
    readonly property var catalog: [
        { type: "block", color: "#3e9b92" },
        { type: "lever", color: "#c56c54" }
    ]

    readonly property int cols: 20
    readonly property int rows: 12
    readonly property real cell: 5

    Board {
        id: board
        cols: root.cols; rows: root.rows; cell: root.cell
        spec: root.spec
        // a move or a turn is geometry, not the domain: no re-solve
        onChanged: (kind) => { if (kind !== "view") root.resolve() }
        onCleared: monitor.clear()
        onRemoved: (id) => monitor.setWatched(id, false)
    }

    // --- the domain: what the wired-up board means -----------------------------
    // The stub model: a lever that is ON powers everything wired to it. Replace
    // with your solver (pure JS in the kit, node-tested) - keep the shape:
    // parts and wires in, one plain object out, nothing mutated in place.
    property var sim: ({ perPart: {}, groups: 0 })
    function resolve() { sim = solveBoard(board.parts, board.wires) }
    function solveBoard(parts, wires) {
        const parent = {}
        for (const p of parts) parent[p.id] = p.id
        const find = (a) => { while (parent[a] !== a) a = parent[a]; return a }
        const links = {}
        for (const w of wires) {
            if (parent[w.a[0]] === undefined || parent[w.b[0]] === undefined) continue
            parent[find(w.a[0])] = find(w.b[0])
            links[w.a[0]] = (links[w.a[0]] || 0) + 1
            links[w.b[0]] = (links[w.b[0]] || 0) + 1
        }
        const powered = {}
        for (const p of parts) if (p.type === "lever" && p.on) powered[find(p.id)] = true
        const per = {}, groups = {}
        for (const p of parts) {
            const g = find(p.id)
            groups[g] = true
            per[p.id] = { links: links[p.id] || 0, lit: !!powered[g], group: g }
        }
        return { perPart: per, groups: Object.keys(groups).length }
    }
    function simOf(id) {
        const e = sim.perPart[id]
        return e ? e : { links: 0, lit: false, group: -1 }
    }
    // One reading, any attribute: the value labels, the tags and the card all
    // speak through this, so they cannot disagree.
    function readingOf(id, attr) {
        const p = board.partAt(id)
        if (!p) return ""
        if (attr === "weight") return LabLang.num(p.value, 0)
        return LabLang.num(simOf(id).links, 0)
    }
    function partLabel(id) {
        const p = board.partAt(id)
        if (!p) return "?"
        const code = LabLang.t("code." + p.type)
        let n = 0, mine = 0
        for (const e of board.parts)
            if (e.type === p.type) { ++n; if (e.id === p.id) mine = n }
        return n > 1 ? code + mine : code
    }
    function flip(id) {
        const p = board.partAt(id)
        if (p && p.type === "lever") board.setField(id, "on", !p.on)
    }
    function setValue(id, v) { board.setField(id, "value", Math.max(1, Math.min(3, v))) }

    // --- the clock and the probes -----------------------------------------------
    // The only source of time and randomness. This model has no time of its
    // own, so the clock only paces the samples; a time-driven model steps in
    // onStepped with a fixed dt.
    SimClock { id: clock; seed: 42; sampleInterval: 0.1 }
    Probe {
        name: "lit"
        expr: () => board.parts.filter(p => root.simOf(p.id).lit).length
    }
    Probe { name: "wires"; expr: () => board.wires.length }

    DataRecorder {
        id: recorder
        lab: "hydraulics-101"
        destination: "labs/hydraulics-101/records/session.labrec"
    }

    // --- scenarios ---------------------------------------------------------------
    // A scenario builds the board through the same verbs a hand uses, inside
    // one batch so the parts publish once. The lab always cold-opens into one.
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "intro"
            script: () => {
                board.beginBatch()
                board.clear()
                const a = board.addPart("block", 5, 4)
                const s = board.addPart("lever", 10, 4)
                const b = board.addPart("block", 15, 4)
                board.addWire([a, 1], [s, 0])
                board.addWire([s, 1], [b, 0])
                board.endBatch()
                root.frameAll()
            }
        }
        Scenario {
            name: "chain"
            script: () => {
                board.beginBatch()
                board.clear()
                let prev = board.addPart("lever", 3, 8)
                for (let i = 1; i < 4; ++i) {
                    const nxt = board.addPart("block", 3 + 4 * i, 8)
                    board.addWire([prev, 1], [nxt, 0])
                    prev = nxt
                }
                board.endBatch()
                root.frameAll()
            }
        }
    }

    // --- inspector / agent / flow conventions -------------------------------------
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }
    // Language-neutral: ids, numbers and types, never a translated label.
    function labInfo() {
        const info = Lab.labInfo()
        info.board = { parts: board.parts.map(p => ({ id: p.id, type: p.type, on: p.on })),
                       wires: board.wires.length, groups: sim.groups }
        info.flow = { id: introFlow.running ? introFlow.flowId : "", step: introFlow.index }
        return info
    }
    function flagInfo() { return labInfo() }
    // The user's whole place: the built board wins over the preset it came
    // from, the camera is restored last.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            board: board.state(),
            watch: monitor.watched.slice(), watchQuantity: monitor.quantity,
            overlay: overlay.state(),
            sections: Object.assign({}, palette.sectionsOpen),
            lang: LabLang.lang,
            cam: rig.state()
        })
    }
    function applyViewState(s) {
        if (!s) return
        if (s.board) { board.load(s.board); if (s.scenario) Lab.scenario = s.scenario }
        else if (s.scenario) applyScenario(s.scenario)
        if (s.lang) LabLang.lang = s.lang
        if (s.sections) palette.sectionsOpen = Object.assign({}, s.sections)
        if (s.watchQuantity) monitor.quantity = s.watchQuantity
        if (s.watch) monitor.watchOnly(s.watch.filter(id => board.partAt(id) !== null))
        if (s.overlay) overlay.load(s.overlay)
        Lab.applyViewState(s)
        if (s.cam) rig.applyState(s.cam)
    }
    // One mutation API, three drivers: the UI, a Flow by name, an agent
    // through eval. No verb exists that only a flow can perform.
    function flowActions() {
        return {
            "addPart":    (type, col, row) => board.addPart(type, col, row),
            "wire":       (a, ta, b, tb) => board.addWire([a, ta], [b, tb]),
            "flip":       (id) => flip(id),
            "setValue":   (id, v) => setValue(id, v),
            "watch":      (id, on) => monitor.setWatched(id, on),
            "select":     (id) => { board.selectedId = id },
            "showValues": (on) => { overlay.showValues = on },
            "clear":      () => board.clear(),
            "scenario":   (n) => applyScenario(n),
            "frame":      (what) => what === "selection" ? frameSelection() : frameAll()
        }
    }
    function flows() { return [introFlow.flowId] }
    function startFlow(id) {
        if (id === introFlow.flowId) { introFlow.start(); return true }
        return false
    }
    function frameAll() {
        rig.pushJump()
        const pts = board.bounds(null, 7)
        if (pts.length) rig.frame(pts, 1.25)
        else rig.applyState({ px: 0, py: 2, pz: 0, distance: 70 })
    }
    function frameSelection() {
        if (board.selectedId === -1) { frameAll(); return }
        rig.frameWithReturn(board.bounds([board.selectedId], 7), 1.15)
    }

    // --- the domain: how a part is drawn -----------------------------------------
    // A kit ships this as its own component (see labs/kits/circuit/
    // CircuitElement3D.qml). The pads come from the same spec the board reads,
    // so the pads, the hit test and the picture cannot drift apart.
    component PartVisual: Node {
        id: pv
        property string type: "block"
        property bool lit: false
        property bool on: false
        property bool hovered: false
        property bool selected: false
        property int wiringTerminal: -1
        readonly property var s: root.spec[type]
        // what a ray can hit: pickable is off by default, and without this a
        // handheld instrument pointed at the part finds only the ground
        Model {
            source: "#Cube"
            pickable: true
            position: Qt.vector3d(0, 2.5, 0)
            scale: Qt.vector3d(pv.s.half.x * 2 / 100, 0.05, pv.s.half.y * 2 / 100)
        }
        SelectionFrame3D {
            selected: pv.selected; hovered: pv.hovered
            halfWidth: pv.s.half.x + 0.6; halfDepth: pv.s.half.y + 0.5
            height: 0.62
        }
        Box3D {
            y: 0
            width: pv.s.half.x * 2 - 1.6; depth: pv.s.half.y * 2 - 1.6
            height: pv.type === "lever" ? 1.6 : 2.4
            color: pv.lit ? LabTheme.highlight
                 : (pv.type === "lever" ? LabTheme.clay : LabTheme.teal)
            useToonShading: true
        }
        // the lever's handle: what you operate, drawn where the actuator is
        Box3D {
            visible: pv.type === "lever"
            x: pv.on ? 1.2 : -1.2; y: 1.6; z: 0
            width: 1.4; depth: 1.4; height: 1.4
            color: pv.on ? LabTheme.secondary : LabTheme.ink
            useToonShading: true
        }
        Repeater3D {
            model: pv.s.terminals.length
            Model {
                id: pad
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(pv.s.terminals[pad.index].x, 0.3, pv.s.terminals[pad.index].y)
                scale: Qt.vector3d(0.02, 0.006, 0.02)
                materials: PrincipledMaterial {
                    baseColor: pv.wiringTerminal === pad.index ? LabTheme.secondary : LabTheme.accent
                    roughness: 1.0
                }
            }
        }
    }

    // --- the scene ------------------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        // The pegboard: an endless sheet of squared paper whose raster is drawn
        // in the shader, crosses while the grid snaps and dots when it is free.
        LabStage3D {
            id: stage
            cellSize: root.cell
            majorEvery: 4
            rasterOrigin: Qt.vector2d(board.cellX(0), board.cellZ(0))
            gridMode: grid
            workExtent: Qt.vector2d(root.cols * root.cell, root.rows * root.cell)
        }
        CameraAnchorMark { pointer: nav }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 2, 0)
            yaw: 0; pitch: 48; distance: 70
            minPitch: 22; maxPitch: 84
            minDistance: 20; maxDistance: 150
            minHeight: 9
            homePivot: Qt.vector3d(0, 2, 0)
            panLeash: stage.workRadius * 0.9
        }

        // The instruments you hold, and the palette's parts as one of them.
        InstrumentBelt {
            id: hands
            pointer: nav
            PartPlacer { id: placer; board: board; partType: "block" }
        }

        // What the click would do, before it does it.
        PartVisual {
            visible: hands.held === placer && placer.spot !== null
            type: placer.partType
            opacity: placer.free ? 0.45 : 0.3
            position: placer.spot
                      ? Qt.vector3d(board.cellX(placer.spot.col), -0.45, board.cellZ(placer.spot.row))
                      : Qt.vector3d(0, -1000, 0)
            hovered: placer.free
            selected: placer.spot !== null && !placer.free
        }

        // The parts. modelData is a COPY of the plain JS object: mutable state
        // is read live from the board, and each binding lists board.rev.
        Repeater3D {
            model: board.parts
            PartVisual {
                required property var modelData
                position: {
                    board.rev
                    const e = board.partAt(modelData.id)
                    return e ? Qt.vector3d(board.cellX(e.col), -0.45, board.cellZ(e.row))
                             : Qt.vector3d(0, 0, 0)
                }
                // No `Behavior on eulerRotation.y` here: under ComponentBehavior
                // Bound, a Behavior on a Repeater3D delegate crashes the engine
                // when the model is republished (Qt 6.11.1) - and a board
                // republishes on every mutation. Animate inside the kit's part
                // component instead, where the property is its own.
                eulerRotation.y: { board.rev; const e = board.partAt(modelData.id); return e ? (e.rot || 0) : 0 }
                type: modelData.type
                on: { board.rev; const e = board.partAt(modelData.id); return e ? e.on : false }
                lit: root.simOf(modelData.id).lit
                selected: board.selectedId === modelData.id
                hovered: board.hoverHit !== null
                         && (board.hoverHit.kind === "element" || board.hoverHit.kind === "actuator")
                         && board.hoverHit.el === modelData.id
                wiringTerminal: {
                    if (board.wiringFrom && board.wiringFrom.el === modelData.id)
                        return board.wiringFrom.ti
                    if (board.hoverHit && board.hoverHit.kind === "terminal"
                        && board.hoverHit.el === modelData.id)
                        return board.hoverHit.ti
                    return -1
                }
            }
        }

        // Every wire, one draw call; a wire in a powered group flows.
        BoardWires3D {
            id: wires3d
            board: board
            y: stage.overlayMaxY
            clock: clock
            solved: root.sim
            lineOf: (w, pts, hovered) => {
                const lit = root.simOf(w.a[0]).lit
                return { color: hovered ? (board.eraser ? LabTheme.alarm : LabTheme.secondary)
                              : (lit ? LabTheme.ink : LabTheme.inkFaint),
                         width: 0.5, styleId: 0,
                         flow: lit ? { reverse: false, color: LabTheme.highlight, width: 0.62,
                                       styleId: wires3d.flowStyle(0.5) } : null }
            }
        }
    }

    // --- navigation and the mouse -----------------------------------------------------
    // The LEFT BUTTON IS ALWAYS THE BOARD'S; the camera gets the right button,
    // the middle one, the wheel, the arrows, and the left button only while
    // Space is held.
    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid; step: root.cell }
    BoardInput {
        id: boardMouse
        board: board; nav: nav; hands: hands; stage: stage; view: view3d; grid: grid
        onOperate: (id) => root.flip(id)
        onInteracted: introFlow.takeOver()
    }

    // --- HUD ---------------------------------------------------------------------
    BoardPalette {
        id: palette
        objectName: "palette"
        board: board; lab: root; flow: introFlow; hands: hands; placer: placer
        grid: grid; overlay: overlay
        catalog: root.catalog
    }
    Compass {
        x: palette.x + palette.width + LabTheme.px(10); y: LabTheme.px(12)
        yaw: rig.yaw
        aspect: root.cols / root.rows
    }
    Row {
        id: topSwitches
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: LabTheme.spaceXl
        spacing: LabTheme.spaceM
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ScaleSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }

    // The readings over the board: value labels, watch marks, pinned tags.
    BoardOverlay {
        id: overlay
        anchors.fill: parent
        board: board; view: view3d; camera: rig.camera; monitor: monitor; solved: root.sim
        readingOf: (id, attr) => root.readingOf(id, attr)
        labelOf: (id) => root.partLabel(id)
    }

    // The selection card: what the kernel gives every part (plot, tag, hint)
    // plus this domain's rows - a lever's state, a block's weight.
    PartCard {
        id: selCard
        objectName: "partCard"
        board: board; view: view3d; camera: rig.camera; monitor: monitor; overlay: overlay
        titleOf: (p) => LabLang.t("part." + p.type).toUpperCase()
                        + (p.type === "block" ? "  " + LabLang.t("card.weight") + " " + LabLang.num(p.value, 0) : "")
        readingOf: (p) => LabLang.t(root.simOf(p.id).lit ? "card.lit" : "card.dark")
        hintOf: (p) => LabLang.t(p.type === "lever" ? "card.hint.lever" : "card.hint.part")
        adjust: (p, row, d) => {
            if (row === "state") { root.flip(p.id); return true }
            if (row === "value") { root.setValue(p.id, p.value + d); return true }
            return false
        }
        operate: (p) => { if (p.type !== "lever") return false; root.flip(p.id); return true }

        Row {
            visible: selCard.part !== null && selCard.part.type === "lever"
            height: visible ? implicitHeight : 0
            spacing: LabTheme.px(3)
            CardFocusRing { on: selCard.focusedRow === "state" }
            Repeater {
                model: [true, false]
                Rectangle {
                    id: stateChip
                    required property bool modelData
                    readonly property bool active: { board.rev; return selCard.part !== null && selCard.part.on === modelData }
                    width: LabTheme.px(88); height: LabTheme.px(20); radius: LabTheme.px(4)
                    color: active ? LabTheme.secondary : LabTheme.paper
                    border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        anchors.centerIn: parent
                        text: LabLang.t(stateChip.modelData ? "lever.on" : "lever.off")
                        color: LabTheme.inkOn(stateChip.color)
                        font.pixelSize: LabTheme.fontSmall; font.bold: true; font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (selCard.part && selCard.part.on !== stateChip.modelData) root.flip(selCard.part.id)
                    }
                }
            }
        }
        Row {
            visible: selCard.part !== null && selCard.part.type === "block"
            height: visible ? implicitHeight : 0
            spacing: LabTheme.px(3)
            CardFocusRing { on: selCard.focusedRow === "value" }
            Repeater {
                model: [1, 2, 3]
                Rectangle {
                    id: valueChip
                    required property int modelData
                    readonly property bool active: { board.rev; return selCard.part !== null && selCard.part.value === modelData }
                    width: LabTheme.px(56); height: LabTheme.px(20); radius: LabTheme.px(4)
                    color: active ? LabTheme.secondary : LabTheme.paper
                    border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        anchors.centerIn: parent
                        text: LabLang.num(valueChip.modelData, 0)
                        color: LabTheme.inkOn(valueChip.color)
                        font.pixelSize: LabTheme.fontSmall; font.bold: true; font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (selCard.part) root.setValue(selCard.part.id, valueChip.modelData)
                    }
                }
            }
        }
    }

    LabBanner {
        active: false
        guard: palette
        text: ""
    }
    TransportChip {
        id: transport
        clock: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: LabTheme.px(58)
    }
    RecIndicator {
        recorder: recorder
        anchors.left: parent.left; anchors.leftMargin: LabTheme.spaceXl
        anchors.bottom: parent.bottom; anchors.bottomMargin: LabTheme.spaceL
    }
    HintBar {
        id: hintBar
        flow: introFlow
        rightGuard: monitor
        text: boardMouse.hint
    }

    // What the plot shows comes from the board: watch a part and it gets a
    // probe, a colour and a curve. One quantity at a time.
    WatchMonitor {
        id: monitor
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.margins: LabTheme.px(10)
        idPrefix: "part"
        quantities: [
            { key: "links", label: "quantity.links", unit: "" },
            { key: "weight", label: "quantity.weight", unit: "" }]
        windowSeconds: 30
        placeholder: LabLang.t("plot.empty")
        valueOf: (id, q) => q === "weight" ? (board.partAt(id) ? board.partAt(id).value : 0)
                                            : root.simOf(id).links
        labelOf: (id) => root.partLabel(id)
        revision: board.rev + board.parts.length
    }

    // --- the guided tour ---------------------------------------------------------------
    Flow {
        id: introFlow
        lab: root
        camera: rig
        flowId: "hydraulics_101-intro"
        titleKey: "flow.hydraulics_101-intro.title"

        // demo: the lab builds through its own verbs, the learner watches
        FlowStep {
            key: "intro"
            demo: [["clear"], ["showValues", false],
                   ["let", "a", "addPart", "block", 5, 4],
                   ["let", "s", "addPart", "lever", 10, 4],
                   ["let", "b", "addPart", "block", 15, 4],
                   ["wire", "a", 1, "s", 0], ["wire", "s", 1, "b", 0],
                   ["frame", "setup"]]
        }
        // task: the learner acts; `until` is a predicate on board state, so
        // the card, the actuator and the h key all satisfy it
        FlowStep {
            key: "try"
            task: ({ "until": (n) => { const e = board.partAt(n("s")); return e && e.on },
                     "hint": "flow.hydraulics_101-intro.try.hint",
                     "hintAfter": 8,
                     "solve": [["flip", "s"]] })
        }
        // expect: the assertion that makes the flow a test
        FlowStep {
            key: "check"
            demo: [["showValues", true]]
            expect: (n) => root.simOf(n("a")).lit && root.simOf(n("b")).lit
        }
    }
    Narrator {
        flow: introFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
        width: Math.min(LabTheme.px(680), root.width - 2 * (root.width - monitor.x) - LabTheme.spaceXl)
    }

    // --- keyboard selection and the keys -------------------------------------------------
    HintJump {
        id: hintJump
        view: view3d; camera: rig.camera; rig: rig
        targets: () => board.jumpTargets((id) => root.partLabel(id), (el) => LabLang.t("code." + el.type))
        onSelected: (t) => board.selectedId = t.id
    }
    // The reserved half of the map is LabKeys', the board's half (clear,
    // eraser, values, plot, turn, grid, remove) the Board's; what a lab adds
    // goes in between - and declaring it here documents it in LabHelp.
    LabKeys {
        id: keymap
        lab: root; camera: rig; pointer: nav; hands: hands
        flow: introFlow; recorder: recorder; jump: hintJump; hints: hintBar
        selection: selCard.keys
        keys: board.keys(grid, overlay).concat(board.selectionKeys(monitor, grid))
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) boardMouse.cancelAll()
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
