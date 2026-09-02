// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../kits/hydro"
import "../kits/hydro/hydro.js" as Hydro
import "../kits/hydro/parts.js" as Parts
import "../kits/hydro/strings.js" as HydroStrings
// Manhattan pipe runs. The router is pure geometry and lives with the circuit
// kit that first needed it; a third consumer moves it into the kernel.
import "../kits/circuit/route.js" as Route
import "strings.js" as Strings

// Hydraulics 101 - the electricity lesson told in water: a pump, a valve, a
// narrow pipe and a water wheel on a pegboard, plumbed by clicking flanges,
// and solved as a real flow network (labs/kits/hydro). Pressure is voltage,
// flow is current, and the pump sags under load the way a cell does.
//
// This lab is the second consumer of the kernel's board layer: everything
// about placing, plumbing, selecting and reading parts is the Board's, what
// is here is water - the solver bridge, the readings, the scenarios and the
// lesson. Started 2026-09-02 from tools/lab-new (kind: build, purpose:
// teaching).
//
// Keys: 1-4 presets · T tour · C clear · E eraser · V values · Q plot the
// selection · R turn · # grid · Del remove · f jump · ⇧F frame · 0 reset ·
// arrows/WASD travel · Shift+arrows turn · +/- zoom · Space holds the view ·
// H instruments · Shift+R record · Ctrl +/-/0 text size · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        LabLang.register(HydroStrings.dict)   // the kit owns the part vocabulary
        LabLang.register(Strings.dict)        // the lab its own copy, and may override
        forceActiveFocus()
        applyScenario("wheel-basic")
    }

    // --- the board -------------------------------------------------------------
    readonly property int cols: 20
    readonly property int rows: 12
    readonly property real cell: 5

    Board {
        id: board
        cols: root.cols; rows: root.rows; cell: root.cell
        spec: Parts.spec
        router: ({ all: (links, obstacles, lane) => Route.routeAll(links, obstacles, lane),
                   one: (a, b, lane) => Route.routeOne(a, b, [], null, lane) })
        onChanged: (kind) => { if (kind !== "view") root.resolve() }
        onCleared: monitor.clear()
        onRemoved: (id) => monitor.setWatched(id, false)
    }
    // the short names the scenarios, the flow and the figure scripts use
    readonly property alias elements: board.parts
    readonly property alias wires: board.wires
    readonly property alias elemRev: board.rev
    property alias selectedId: board.selectedId
    function elemAt(id) { return board.partAt(id) }
    function addElement(type, col, row) { return board.addPart(type, col, row) }
    function addRotated(type, col, row, q) { return board.addRotated(type, col, row, q) }
    function addWire(a, b) { board.addWire(a, b) }
    function clearBoard() { board.clear() }

    // --- the water: solver bridge and readings -----------------------------------
    property var sim: ({ ok: true, perElement: {}, pumps: {}, wireFlow: {},
                         shorted: false, overloaded: false })
    // Everything the solver may read about a part is listed here; a field
    // left out silently takes the solver's default.
    function solverElements() {
        return board.parts.map(el => ({ id: el.id, type: el.type, on: el.on, value: el.value }))
    }
    function resolve() { sim = Hydro.solve(solverElements(), board.wires) }
    function simOf(id) {
        const e = sim.perElement[id]
        return e ? e : { q: 0, dp: 0, on: false, power: 0, speed: 0 }
    }
    function pumpOf(id) {
        const p = sim.pumps ? sim.pumps[id] : null
        return p ? p : null
    }
    readonly property real defaultHead: Hydro.P0_DEFAULT
    readonly property real ratedFlow: Hydro.Q_RATED

    function fmtQ(q) { return LabLang.num(q, 2) + " L/s" }
    function fmtP(p) { return LabLang.num(p, 1) + " kPa" }
    // One reading, any attribute - the value labels, the tags and the card
    // all speak through this, so they cannot disagree.
    function readingOf(id, attr) {
        const s = simOf(id)
        if (attr === "p") return fmtP(Math.abs(s.dp))
        if (attr === "P") return LabLang.qty(s.power, "W", 1)
        return fmtQ(Math.abs(s.q))
    }
    // Flow above the pump's rating warns; nothing here has a rated pressure.
    function severityOf(id, attr) {
        if (attr === "Q" && Math.abs(simOf(id).q) > ratedFlow) return "warn"
        return "ok"
    }
    function partLabel(id) {
        const el = board.partAt(id)
        if (!el) return "?"
        const code = LabLang.t("code." + el.type)
        let n = 0, mine = 0
        for (const e of board.parts)
            if (e.type === el.type) { ++n; if (e.id === el.id) mine = n }
        return n > 1 ? code + mine : code
    }

    // the domain's verbs - what a card, a flow and an agent may set
    function setValve(id, open) {
        const el = board.partAt(id)
        if (el && el.type === "valve") board.setField(id, "on", !!open)
    }
    function toggleValve(id) {
        const el = board.partAt(id)
        if (el && el.type === "valve") board.setField(id, "on", !el.on)
    }
    function setHead(id, kpa) {
        const el = board.partAt(id)
        if (!el || el.type !== "pump") return
        board.setField(id, "value", Math.round(Math.max(10, Math.min(120, kpa)) / 5) * 5)
    }
    function setPipe(id, r) {
        const el = board.partAt(id)
        if (!el || el.type !== "pipe") return
        board.setField(id, "value", Hydro.pipeSteps[Hydro.pipeStepOf(r)])
    }
    function setPipeStep(id, step) {
        const s = Math.max(0, Math.min(Hydro.pipeSteps.length - 1, step))
        setPipe(id, Hydro.pipeSteps[s])
    }

    // --- the clock and the probes ---------------------------------------------------
    // The solver has no time of its own; the clock paces the samples and the
    // wheel's spin, so a record is a pure function of the step count.
    SimClock { id: clock; seed: 42; sampleInterval: 0.1 }
    Probe {
        name: "qPump"; unit: "L/s"
        expr: () => {
            let sum = 0
            for (const el of board.parts) if (el.type === "pump") sum += root.simOf(el.id).q
            return sum
        }
    }
    Probe {
        name: "power"; unit: "W"
        expr: () => {
            let sum = 0
            for (const el of board.parts) if (el.type !== "pump") sum += root.simOf(el.id).power
            return sum
        }
    }
    // what the pump actually hands to the parts: its head less its own loss
    Probe {
        name: "pTerm"; unit: "kPa"
        expr: () => {
            let sum = 0
            for (const el of board.parts) {
                const p = root.pumpOf(el.id)
                if (p) sum += p.pTerm
            }
            return sum
        }
    }
    DataRecorder {
        id: recorder
        lab: "hydraulics-101"
        destination: "labs/hydraulics-101/records/session.labrec"
    }

    // --- scenarios ---------------------------------------------------------------------
    // Every preset starts with the valve SHUT, so the first thing a learner
    // does is open it and watch the wheel start - the same choice the
    // electronics lab makes with its switch.
    function loop(parts) {
        for (let i = 0; i < parts.length; ++i)
            board.addWire([parts[i], 1], [parts[(i + 1) % parts.length], 0])
    }
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "wheel-basic"
            script: () => {
                board.beginBatch()
                board.clear()
                const pump = board.addPart("pump", 5, 3)
                const valve = board.addPart("valve", 11, 3)
                const pipe = board.addPart("pipe", 14, 8)
                const wheel = board.addPart("wheel", 5, 8)
                // the pump's outlet is pad 0, so the loop runs out of the pump
                // into the valve and comes home through the wheel
                board.addWire([pump, 0], [valve, 0]); board.addWire([valve, 1], [pipe, 0])
                board.addWire([pipe, 1], [wheel, 0]); board.addWire([wheel, 1], [pump, 1])
                board.endBatch()
                monitor.watchOnly([wheel])
                root.frameAll()
            }
        }
        Scenario {
            name: "series"
            script: () => {
                board.beginBatch()
                board.clear()
                const pump = board.addPart("pump", 5, 3)
                const valve = board.addPart("valve", 11, 3)
                const a = board.addPart("wheel", 14, 8)
                const b = board.addPart("wheel", 5, 8)
                board.addWire([pump, 0], [valve, 0]); board.addWire([valve, 1], [a, 0])
                board.addWire([a, 1], [b, 0]); board.addWire([b, 1], [pump, 1])
                board.endBatch()
                monitor.watchOnly([a, b])
                root.frameAll()
            }
        }
        Scenario {
            name: "parallel"
            script: () => {
                board.beginBatch()
                board.clear()
                const pump = board.addPart("pump", 3, 5)
                const valve = board.addPart("valve", 8, 2)
                const a = board.addPart("wheel", 15, 5)
                const b = board.addPart("wheel", 15, 9)
                const top = board.addJunction(12, 2)
                const bottom = board.addJunction(12, 11)
                board.addWire([pump, 0], [valve, 0]); board.addWire([valve, 1], [top, 0])
                board.addWire([top, 0], [a, 0]); board.addWire([top, 0], [b, 0])
                board.addWire([a, 1], [bottom, 0]); board.addWire([b, 1], [bottom, 0])
                board.addWire([bottom, 0], [pump, 1])
                board.endBatch()
                monitor.watchOnly([a, b])
                root.frameAll()
            }
        }
        Scenario {
            name: "metering"
            script: () => {
                board.beginBatch()
                board.clear()
                const pump = board.addPart("pump", 4, 3)
                const valve = board.addPart("valve", 10, 3)
                const meter = board.addPart("flowmeter", 15, 3)
                const wheel = board.addPart("wheel", 10, 9)
                const gauge = board.addPart("gauge", 4, 9)
                board.addWire([pump, 0], [valve, 0]); board.addWire([valve, 1], [meter, 0])
                board.addWire([meter, 1], [wheel, 0]); board.addWire([wheel, 1], [pump, 1])
                // the gauge sits ACROSS the wheel: it reads the drop, and takes
                // no water worth mentioning
                board.addWire([gauge, 0], [wheel, 0]); board.addWire([gauge, 1], [wheel, 1])
                board.endBatch()
                monitor.watchOnly([wheel])
                root.frameAll()
            }
        }
    }

    // --- inspector / agent / flow conventions ---------------------------------------------
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        const ok = scenarioSet.apply(n)
        root.selectedId = -1
        return ok
    }
    function labInfo() {
        const info = Lab.labInfo()
        info.board = { parts: board.parts.map(p => ({ id: p.id, type: p.type, on: p.on, value: p.value })),
                       wires: board.wires.length, shorted: sim.shorted, overloaded: sim.overloaded }
        info.flow = { id: wheelFlow.running ? wheelFlow.flowId : "", step: wheelFlow.index }
        return info
    }
    function flagInfo() { return labInfo() }
    // The user's whole place: the built board wins over the preset it came
    // from, the camera is restored last.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            board: board.state(),
            watch: monitor.watched.slice(), watchQuantity: monitor.quantity,
            traces: monitor.traces(),
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
        if (s.traces) monitor.traceOnly(s.traces.filter(t => board.partAt(t.id) !== null))
        if (s.overlay) overlay.load(s.overlay)
        Lab.applyViewState(s)
        if (s.cam) rig.applyState(s.cam)
    }
    // One mutation API, three drivers: the UI, a Flow by name, an agent
    // through eval. No verb exists that only a flow can perform.
    function flowActions() {
        return {
            "addPart":    (type, col, row) => board.addPart(type, col, row),
            "plumb":      (a, ta, b, tb) => board.addWire([a, ta], [b, tb]),
            "openValve":  (id, open) => setValve(id, open === undefined ? true : open),
            "setHead":    (id, kpa) => setHead(id, kpa),
            "setPipe":    (id, r) => setPipe(id, r),
            "watch":      (id, on) => monitor.setWatched(id, on),
            "select":     (id) => { board.selectedId = id },
            "showValues": (on) => { overlay.valueAttr = on ? "Q" : "" },
            "clear":      () => board.clear(),
            "scenario":   (n) => applyScenario(n),
            "frame":      (what) => what === "selection" ? frameSelection() : frameAll(),
            "view":       (name) => rig.goTo(name)
        }
    }
    function flows() { return [wheelFlow.flowId] }
    function startFlow(id) {
        if (id === wheelFlow.flowId) { wheelFlow.start(); return true }
        return false
    }
    function frameAll() {
        rig.pushJump()
        const pts = board.bounds(null, 7)
        if (pts.length) rig.frame(pts, 1.25)
        else rig.applyState({ px: 0, py: 2, pz: 0, distance: rig.maxDistance })
    }
    function frameSetup() { frameAll() }
    function frameSelection() {
        if (board.selectedId === -1) {
            if (rig.hasReturnPose) { rig.frameWithReturn(null, 1.0); return }
            frameAll(); return
        }
        rig.frameWithReturn(board.bounds([board.selectedId], 7), 1.15)
    }

    // --- the scene ---------------------------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        LabStage3D {
            id: stage
            cellSize: root.cell
            majorEvery: 4
            rasterOrigin: Qt.vector2d(board.cellX(0), board.cellZ(0))
            gridMode: grid
            workExtent: Qt.vector2d(root.cols * root.cell, root.rows * root.cell)
            shadowMapFar: 200
        }
        CameraAnchorMark { pointer: nav }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 2, 0)
            yaw: 0; pitch: 48; distance: 70
            minPitch: 22; maxPitch: 84
            minDistance: 20; maxDistance: 150
            minHeight: 9
            smoothMs: 140
            homePivot: Qt.vector3d(0, 2, 0)
            panLeash: stage.workRadius * 0.9
            viewpoints: ({
                "board": { yaw: 0, pitch: 48, distance: 70, px: 0, py: 2, pz: 0 },
                "top":   { yaw: 0, pitch: 84, distance: 100 }
            })
        }

        InstrumentBelt {
            id: hands
            pointer: nav
            PartPlacer { id: placer; board: board; partType: "pipe" }
        }

        // What the click would do, before it does it.
        HydroElement3D {
            visible: hands.held === placer && placer.spot !== null
            type: placer.partType
            value: placer.partType === "pump" ? root.defaultHead : (placer.partType === "pipe" ? 8 : 0)
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
            HydroElement3D {
                required property var modelData
                position: {
                    board.rev
                    const e = board.partAt(modelData.id)
                    return e ? Qt.vector3d(board.cellX(e.col), -0.45, board.cellZ(e.row))
                             : Qt.vector3d(0, 0, 0)
                }
                eulerRotation.y: { board.rev; const e = board.partAt(modelData.id); return e ? (e.rot || 0) : 0 }
                type: modelData.type
                value: { board.rev; const e = board.partAt(modelData.id); return e ? e.value : modelData.value }
                switchOn: { board.rev; const e = board.partAt(modelData.id); return e ? e.on : false }
                simQ: root.simOf(modelData.id).q
                simDp: root.simOf(modelData.id).dp
                simPower: root.simOf(modelData.id).power
                turning: root.simOf(modelData.id).on
                speed: root.simOf(modelData.id).speed
                // the wheel's angle from the sim clock, so a stepped record
                // and the live lab agree on where it stands
                phase: (clock.time * root.simOf(modelData.id).speed * 6) % 360
                shorted: { const p = root.pumpOf(modelData.id); return p !== null && p.shorted }
                overloaded: { const p = root.pumpOf(modelData.id); return p !== null && p.overloaded }
                selected: board.selectedId === modelData.id
                hovered: board.hoverHit !== null
                         && (board.hoverHit.kind === "element" || board.hoverHit.kind === "actuator")
                         && board.hoverHit.el === modelData.id
                actuatorHovered: boardMouse.hoverActuator && board.hoverHit.el === modelData.id
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

        // Every pipe run, one draw call, chevrons marching with the flow at a
        // speed relative to the largest flow on the board - so a T-piece
        // visibly splits.
        BoardWires3D {
            id: wires3d
            board: board
            y: stage.overlayMaxY
            clock: clock
            solved: root.sim
            lineOf: (w, pts, hovered) => root.pipeLine(w, pts, hovered)
        }
    }
    readonly property real qMax: {
        board.rev; sim
        let m = 0
        for (const w of board.wires) {
            const q = sim.wireFlow ? sim.wireFlow[w.id] : null
            if (q !== null && q !== undefined) m = Math.max(m, Math.abs(q))
        }
        return m
    }
    function pipeLine(w, pts, hovered) {
        const f = sim.wireFlow ? sim.wireFlow[w.id] : null
        const q = (f === null || f === undefined) ? 0 : f
        const m = Math.abs(q)
        const style = m > 1e-4 ? wires3d.flowStyle(qMax > 1e-9 ? m / qMax : 1) : 0
        const hot = m > ratedFlow
        return { color: hovered ? (board.eraser ? LabTheme.alarm : LabTheme.secondary)
                      : hot ? LabTheme.alarm : (style === 0 ? LabTheme.inkFaint : LabTheme.primary),
                 width: hot ? 0.7 : 0.55, styleId: 0,
                 flow: style === 0 ? null
                     : { reverse: q < 0, color: LabTheme.teal, width: 0.66, styleId: style } }
    }

    // --- navigation and the mouse ---------------------------------------------------------------
    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid; step: root.cell }
    BoardInput {
        id: boardMouse
        board: board; nav: nav; hands: hands; stage: stage; view: view3d; grid: grid
        hintKeys: ({ eraser: "hint.eraser", actuator: "hint.actuator", actuatorPick: "hint.actuator.pick",
                     wiring: "hint.plumbing", selected: "hint.selected", selectedSnap: "hint.selected.snap",
                     selectedFree: "hint.selected.free", selectedFrame: "hint.selected.frame",
                     idle: "hint.idle.water" })
        onOperate: (id) => root.toggleValve(id)
        onInteracted: wheelFlow.takeOver()
    }

    // --- HUD ------------------------------------------------------------------------------------
    BoardPalette {
        id: palette
        objectName: "palette"
        board: board; lab: root; flow: wheelFlow; hands: hands; placer: placer
        grid: grid; overlay: overlay
        catalog: Parts.catalog
        icon: Component { SymbolIcon {} }
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

    BoardOverlay {
        id: overlay
        anchors.fill: parent
        board: board; view: view3d; camera: rig.camera; monitor: monitor; solved: root.sim
        readingOf: (id, attr) => root.readingOf(id, attr)
        severityOf: (id, attr) => root.severityOf(id, attr)
        labelOf: (id) => root.partLabel(id)
        // a pipe run carries one thing: its flow
        wireReadingOf: (w) => {
            const q = root.sim.wireFlow ? root.sim.wireFlow[w.id] : null
            return (q === null || q === undefined) ? "?" : root.fmtQ(Math.abs(q))
        }
    }

    // --- the selection card: a valve's state, a pump's head, a pipe's bore --------------------------
    function cardTitle(e) {
        const name = LabLang.t("part." + e.type).toUpperCase()
        if (e.type === "pump") return name + "  " + fmtP(e.value || defaultHead)
        if (e.type === "pipe") return name + "  " + LabLang.num(e.value, e.value < 10 ? 1 : 0) + " kPa·s/L"
        if (e.type === "valve") return name + "  " + LabLang.t(e.on ? "valve.open" : "valve.closed")
        return name
    }
    function adjustCardRow(el, row, d) {
        if (row === "state") { setValve(el.id, !el.on); return true }
        if (row === "value") {
            if (el.type === "pump") setHead(el.id, (el.value || defaultHead) + d * 5)
            else setPipeStep(el.id, Hydro.pipeStepOf(el.value) + d)
            return true
        }
        return false
    }
    PartCard {
        id: selCard
        objectName: "partCard"
        board: board; view: view3d; camera: rig.camera; monitor: monitor; overlay: overlay
        titleOf: (e) => root.cardTitle(e)
        readingOf: (e) => { const s = root.simOf(e.id); return root.fmtP(Math.abs(s.dp)) + "   " + root.fmtQ(Math.abs(s.q)) }
        hintOf: (e) => LabLang.t(e.type === "pump" ? "card.hint.pump"
                                : e.type === "pipe" ? "card.hint.pipe"
                                : e.type === "valve" ? "card.hint.valve" : "card.hint.part")
        minWidthOf: (e) => (e.type === "pump" || e.type === "pipe") ? LabTheme.px(196) : 0
        adjust: (e, row, d) => root.adjustCardRow(e, row, d)
        operate: (e) => { if (e.type !== "valve") return false; root.toggleValve(e.id); return true }
        readonly property bool isPump: part !== null && part.type === "pump"
        readonly property bool isPipe: part !== null && part.type === "pipe"
        readonly property var pump: { root.elemRev; root.sim; return part && part.type === "pump" ? root.pumpOf(part.id) : null }

        // open / shut, as a pair that says what IS
        Row {
            visible: selCard.part !== null && selCard.part.type === "valve"
            height: visible ? implicitHeight : 0
            spacing: LabTheme.px(3)
            CardFocusRing { on: selCard.focusedRow === "state" }
            Repeater {
                model: [true, false]
                Rectangle {
                    id: stateChip
                    required property bool modelData
                    readonly property bool active: { root.elemRev; return selCard.part !== null && selCard.part.on === modelData }
                    width: (selCard.width - 20 - LabTheme.px(3)) / 2
                    height: LabTheme.px(20); radius: LabTheme.px(4)
                    color: active ? LabTheme.secondary : LabTheme.paper
                    border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        anchors.centerIn: parent
                        text: LabLang.t(stateChip.modelData ? "valve.on" : "valve.off")
                        color: LabTheme.inkOn(stateChip.color)
                        font.pixelSize: LabTheme.fontSmall; font.bold: true; font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (selCard.part) root.setValve(selCard.part.id, stateChip.modelData)
                    }
                }
            }
        }
        // the pump's head and the pipe's resistance: one slider, two ladders
        Item {
            visible: selCard.isPump || selCard.isPipe
            width: selCard.width - 20
            height: visible ? 22 : 0
            CardFocusRing { on: selCard.focusedRow === "value" }
            Item {
                id: slider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: LabTheme.px(16)
                readonly property int steps: selCard.isPump ? 22 : Hydro.pipeSteps.length - 1   // 10..120 kPa in 5s
                readonly property real ratio: {
                    root.elemRev
                    if (!selCard.part) return 0
                    if (selCard.isPump) return ((selCard.part.value || root.defaultHead) - 10) / 110
                    return steps > 0 ? Hydro.pipeStepOf(selCard.part.value) / steps : 0
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: LabTheme.px(4); radius: LabTheme.px(2)
                    color: LabTheme.panelEdge
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: slider.ratio * parent.width; height: LabTheme.px(4); radius: LabTheme.px(2)
                    color: LabTheme.secondary
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: slider.ratio * (parent.width - width)
                    width: LabTheme.px(12); height: LabTheme.px(12); radius: LabTheme.px(6)
                    color: LabTheme.panel
                    border.color: LabTheme.ink; border.width: LabTheme.px(2)
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    function applyAt(mx) {
                        if (!selCard.part) return
                        const t = Math.max(0, Math.min(1, (mx + 6) / slider.width))
                        if (selCard.isPump) root.setHead(selCard.part.id, 10 + t * 110)
                        else root.setPipeStep(selCard.part.id, Math.round(t * slider.steps))
                    }
                    onPressed: (mouse) => applyAt(mouse.x)
                    onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x) }
                }
            }
        }
        // The pump's own account of itself: head splits into what is lost
        // inside and what reaches the parts. A short is then a bar gone red.
        BudgetBar {
            visible: selCard.isPump && selCard.pump !== null
            width: selCard.width - 20
            height: visible ? implicitHeight : 0
            unit: "kPa"
            total: selCard.pump ? selCard.pump.p0 : 1
            segments: {
                root.elemRev
                const p = selCard.pump
                if (!p) return []
                return [{ label: LabLang.t("pump.reaches"), value: p.pTerm, color: LabTheme.teal },
                        { label: LabLang.t("pump.lost"), value: p.internalDrop,
                          color: p.shorted ? LabTheme.alarm : LabTheme.clay }]
            }
        }
        Text {
            visible: selCard.isPump && selCard.pump !== null
            width: selCard.width - 20
            wrapMode: Text.WordWrap
            text: {
                const p = selCard.pump
                if (!p) return ""
                if (p.shorted) return LabLang.t("pump.short")
                if (p.overloaded) return LabLang.t("pump.heavy")
                return p.rExt === null || p.rExt > 9999 ? LabLang.t("pump.open") : LabLang.t("pump.ok")
            }
            color: selCard.pump && selCard.pump.shorted ? LabTheme.alarm
                 : selCard.pump && selCard.pump.overloaded ? LabTheme.accent : LabTheme.inkFaint
            font.pixelSize: LabTheme.fontBody
            font.family: LabTheme.handFont
        }
    }

    // Two faults, two messages, and only the short blinks.
    LabBanner {
        active: root.sim.shorted || root.sim.overloaded
        alarm: root.sim.shorted
        blink: root.sim.shorted
        guard: palette
        maxWidth: LabTheme.px(560)
        text: LabLang.t(root.sim.shorted ? "banner.short" : "banner.heavy")
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
        flow: wheelFlow
        rightGuard: monitor
        text: boardMouse.hint
    }
    // One quantity at a time: all series share one autoscaled axis. Watch
    // flow in series and it is the same everywhere; watch it in parallel and
    // it splits, on the very same pair of wheels.
    WatchMonitor {
        id: monitor
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.margins: LabTheme.px(10)
        idPrefix: "part"
        quantities: [
            { key: "Q", label: "quantity.flow", unit: "L/s" },
            { key: "p", label: "quantity.pressure", unit: "kPa" },
            { key: "P", label: "quantity.power", unit: "W" }]
        windowSeconds: 30
        placeholder: LabLang.t("plot.empty")
        valueOf: (id, q) => {
            const s = root.simOf(id)
            if (q === "p") return Math.abs(s.dp)
            if (q === "P") return s.power
            return Math.abs(s.q)
        }
        labelOf: (id) => root.partLabel(id)
        canWatch: (id) => { const el = board.partAt(id); return el !== null && el.type !== "junction" }
        revision: board.rev + board.parts.length
    }

    // --- the lesson: why does the wheel turn? -------------------------------------------------------
    // The electronics lab's first lesson, told in water, beat for beat.
    Flow {
        id: wheelFlow
        lab: root
        camera: rig
        flowId: "wheel-basics"
        titleKey: "flow.wheel-basics.title"

        FlowStep { key: "empty"; demo: [["clear"], ["showValues", false], ["frame", "setup"]] }
        FlowStep {
            key: "pump"
            demo: [["let", "pump", "addPart", "pump", 5, 3], ["select", "pump"], ["frame", "selection"]]
        }
        FlowStep {
            key: "wheel"
            demo: [["let", "wheel", "addPart", "wheel", 5, 8], ["select", "wheel"], ["frame", "selection"]]
        }
        FlowStep {
            key: "pipe"
            demo: [["let", "pipe", "addPart", "pipe", 14, 8], ["setPipe", "pipe", 8],
                   ["select", "pipe"], ["frame", "selection"]]
        }
        FlowStep {
            key: "plumb"
            demo: [["let", "valve", "addPart", "valve", 11, 3],
                   ["select", -1], ["frame", "setup"],
                   ["plumb", "pump", 0, "valve", 0], ["plumb", "valve", 1, "pipe", 0],
                   ["plumb", "pipe", 1, "wheel", 0], ["plumb", "wheel", 1, "pump", 1]]
        }
        FlowStep {
            key: "open"
            task: ({ "until": (n) => { const e = board.partAt(n("valve")); return e && e.on },
                     "hint": "flow.wheel-basics.open.hint",
                     "hintAfter": 7,
                     "solve": [["openValve", "valve", true]] })
        }
        FlowStep {
            key: "turning"
            demo: [["watch", "wheel", true]]
            // 40 kPa across 2 + 0.02 + 8 + 24 kPa·s/L: 1.176 L/s, measured
            expect: (n) => Math.abs(root.simOf(n("wheel")).q - 1.1758) < 5e-4
        }
        FlowStep { key: "why" }
        FlowStep { key: "values"; demo: [["showValues", true]] }
        FlowStep { key: "try"; demo: [["select", "pipe"], ["frame", "selection"]] }
    }
    Narrator {
        flow: wheelFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
        width: Math.min(LabTheme.px(680), root.width - 2 * (root.width - monitor.x) - LabTheme.spaceXl)
    }

    // --- keyboard selection and the keys ----------------------------------------------------------------
    HintJump {
        id: hintJump
        view: view3d; camera: rig.camera; rig: rig
        targets: () => board.jumpTargets((id) => root.partLabel(id), (el) => LabLang.t("code." + el.type))
        onSelected: (t) => board.selectedId = t.id
    }
    LabKeys {
        id: keymap
        lab: root; camera: rig; pointer: nav; hands: hands
        flow: wheelFlow; recorder: recorder; jump: hintJump; hints: hintBar
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
