// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../kits/circuit"
import "../kits/circuit/circuit.js" as Circuit
import "../kits/circuit/symbols.js" as Symbols
import "../kits/circuit/strings.js" as CircuitStrings
import "strings.js" as Strings

// Electronics 101 — a school electronics kit on a pegboard: battery,
// switch, resistor, LED, bulb and meters, wired freely by clicking
// terminals. A DC nodal solver lights things up in real time.
//
// Keys are declared once, on the LabKeys below, which is also what generates
// the on-screen list: press ? to see the whole map. The short version:
// 1..4 presets · T the guided tour · C clear · E eraser · V values ·
// M schematic · W plot the selected part · # grid mode · R turn · Del ·
// Shift+R record · Esc cancel. View: drag the empty board to orbit,
// wheel zooms, arrows/+/- nudge, F frames the selection, 0 resets.
Item {
    id: root
    anchors.fill: parent
    focus: true
    Component.onCompleted: {
        // the kit owns the part vocabulary, the lab its own copy
        LabLang.register(CircuitStrings.dict)
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("led-basic")
    }

    // --- clock / probes --------------------------------------------------
    // No global battery parameter: every cell carries its own voltage (select
    // it and drag), so a board can hold a 1.5 V and a 9 V cell at once.
    readonly property real defaultVolts: 4.5

    SimClock { id: clock; seed: 42; sampleInterval: 0.1 }

    Probe {
        name: "iBattery"; unit: "mA"
        expr: () => {
            let sum = 0
            for (const el of root.elements)
                if (el.type === "battery") sum += root.simOf(el.id).i
            return sum * 1000
        }
    }
    Probe {
        name: "power"; unit: "W"
        expr: () => {
            let sum = 0
            for (const el of root.elements)
                if (el.type !== "battery") sum += root.simOf(el.id).power
            return sum
        }
    }

    DataRecorder { id: recorder; destination: "electronics-101-run.csv" }

    // --- monitoring -------------------------------------------------------
    // What the plot shows comes from the board, never from a fixed list: watch
    // a part and it gets a probe, a colour and a curve; delete the part (or
    // click its legend entry) and the curve goes with it. iBattery and power
    // stay as setup-independent globals for the CSV and for agent queries.
    // The mechanism itself lives in the kernel's WatchMonitor now - what stays
    // here is only what a part is worth, and what it is called.
    readonly property alias watch: monitor.watched

    function watchValueOf(id) {
        const s = simOf(id)
        // magnitudes, like the value labels: direction is the chevrons' job
        if (monitor.quantity === "V") return Math.abs(s.v)
        if (monitor.quantity === "P") return s.power
        return Math.abs(s.i) * 1000
    }
    function isWatched(id) { return monitor.isWatched(id) }
    function watchColorOf(id) { return monitor.colorOf(id) }
    function setWatched(id, on) { monitor.setWatched(id, on) }
    function toggleWatch(id) { monitor.toggle(id) }
    function watchOnly(ids) { monitor.watchOnly(ids) }

    // --- circuit state ---------------------------------------------------
    // elements: {id, type, col, row, rot, value, on} - col/row are fractional
    // cell coordinates (snapping rounds them) - wires: {id, a:[el,ti], b:[el,ti]}
    property var elements: []
    property var wires: []
    property int nextId: 1
    property var sim: ({ ok: true, perElement: {}, shorted: false, overloaded: false,
                        iterations: 0 })
    property int elemRev: 0          // bumped on moves so positions rebind

    // Peg raster: 5 world units, so a part can be nudged half a part-width.
    // A part body is ~9 units wide, hence the two-peg keep-out in cellFree.
    readonly property int cols: 20
    readonly property int rows: 12
    readonly property real cell: 5

    function cellX(col) { return (col - (cols - 1) / 2) * cell }
    function cellZ(row) { return (row - (rows - 1) / 2) * cell }
    function elemAt(id) {
        for (const el of elements) if (el.id === id) return el
        return null
    }
    function batteryOf(id) {
        const b = sim.batteries ? sim.batteries[id] : null
        return b ? b : null
    }
    // the cell's rated current, used to mark wires that are carrying too much
    readonly property real ratedCurrent: 1.5

    // Short names for legend and board marks: the type code, plus an ordinal
    // once the board holds more than one of a kind, so BULB1/BULB2 in the plot
    // line up with BULB1/BULB2 on the paper.
    function partLabel(id) {
        const el = elemAt(id)
        if (!el) return "?"
        const code = LabLang.t("code." + el.type)
        let n = 0, mine = 0
        for (const e of elements)
            if (e.type === el.type) { ++n; if (e.id === el.id) mine = n }
        return n > 1 ? code + mine : code
    }

    // Readouts in the reader's notation: German writes 5,1 mA, and a
    // current crosses to amps once it would need four digits in milliamps.
    function fmtA(i) {
        return Math.abs(i) >= 0.9995 ? LabLang.num(i, 2) + " A"
                                     : LabLang.num(i * 1000, 1) + " mA"
    }
    function fmtV(v) { return LabLang.num(v, 2) + " V" }

    function simOf(id) {
        const e = sim.perElement[id]
        return e ? e : { v: 0, i: 0, on: false, power: 0 }
    }
    function terminalPos(elId, ti) {
        elemRev
        const el = elemAt(elId)
        if (!el) return Qt.vector3d(0, 0, 0)
        // local (+/-3.5, 0) turned by the part's yaw (Qt rotates y ccw seen
        // from above: x' = x*cos, z' = -x*sin)
        // a junction is a single point: both of its terminals sit dead centre
        const off = el.type === "junction" ? 0 : (ti === 0 ? -3.5 : 3.5)
        const a = (el.rot || 0) * Math.PI / 180
        return Qt.vector3d(cellX(el.col) + off * Math.cos(a), 0.35,
                           cellZ(el.row) - off * Math.sin(a))
    }

    function resolve() {
        const els = elements.map(el => ({
            id: el.id, type: el.type, on: el.on,
            // a battery carries its own volts; the panel slider is a master
            // that moves them all at once
            value: el.type === "battery" ? (el.value || defaultVolts) : el.value
        }))
        sim = Circuit.solve(els, wires)
    }
    function setBatteryVolts(id, v) {
        const el = elemAt(id)
        if (!el || el.type !== "battery") return
        const nv = Math.round(Math.max(1.5, Math.min(12, v)) * 2) / 2
        if (nv === el.value) return
        el.value = nv
        elemRev++
        resolve()
    }

    // Two pegs of clearance for real parts; junctions are dots and need one
    function cellFree(col, row, ignoreId, type) {
        for (const el of elements) {
            if (el.id === ignoreId) continue
            const k = (type === "junction" || el.type === "junction") ? 0.7 : 1.6
            if (Math.abs(el.col - col) < k && Math.abs(el.row - row) < k) return false
        }
        return true
    }
    function nearestFreeCell(col, row, type) {
        col = Math.max(0, Math.min(cols - 1, Math.round(col)))
        row = Math.max(0, Math.min(rows - 1, Math.round(row)))
        for (let radius = 0; radius < cols; ++radius)
            for (let dr = -radius; dr <= radius; ++dr)
                for (let dc = -radius; dc <= radius; ++dc) {
                    const c = col + dc, r = row + dr
                    if (c < 0 || c >= cols || r < 0 || r >= rows) continue
                    if (cellFree(c, r, -1, type)) return { col: c, row: r }
                }
        return null
    }

    function addElement(type, col, row) {
        const spot = nearestFreeCell(col === undefined ? 10 : col,
                                     row === undefined ? 6 : row, type)
        if (!spot) return -1
        const el = { id: nextId++, type: type, col: spot.col, row: spot.row, rot: 0,
                     value: type === "resistor" ? 470
                          : (type === "battery" ? defaultVolts : 0), on: false }
        elements = elements.concat([el])
        resolve()
        return el.id
    }
    // A solder dot: wires meet here, so a board is no longer limited to
    // point-to-point links between part terminals. Placed exactly (never
    // snapped), because it lands wherever the wire was clicked.
    function addJunction(col, row) {
        const j = { id: nextId++, type: "junction", col: col, row: row,
                    rot: 0, value: 0, on: false }
        elements = elements.concat([j])
        resolve()
        return j.id
    }

    // Drops a junction onto an existing wire and splits it in two, which is
    // what makes a branch (and therefore a parallel circuit) buildable.
    function splitWireAt(wireId, wx, wz) {
        let w = null
        for (const x of wires) if (x.id === wireId) w = x
        if (!w) return -1
        const a = terminalPos(w.a[0], w.a[1])
        const b = terminalPos(w.b[0], w.b[1])
        const dx = b.x - a.x, dz = b.z - a.z
        const len2 = dx * dx + dz * dz
        const t = len2 < 1e-9 ? 0
            : Math.max(0, Math.min(1, ((wx - a.x) * dx + (wz - a.z) * dz) / len2))
        const j = addJunction((a.x + t * dx) / cell + (cols - 1) / 2,
                              (a.z + t * dz) / cell + (rows - 1) / 2)
        wires = wires.filter(x => x.id !== wireId).concat([
            { id: nextId++, a: w.a, b: [j, 0] },
            { id: nextId++, a: [j, 0], b: w.b }])
        resolve()
        return j
    }

    function removeElement(id) {
        wires = wires.filter(w => w.a[0] !== id && w.b[0] !== id)
        elements = elements.filter(el => el.id !== id)
        if (selectedId === id) selectedId = -1
        if (isWatched(id)) watch = watch.filter(x => x !== id)
        resolve()
    }
    // snap: land on a free peg cell (grafli's grid mode) - otherwise the part
    // follows the cursor freely and may sit anywhere on the board
    function moveElement(id, col, row, snap) {
        const el = elemAt(id)
        if (!el) return
        col = Math.max(0, Math.min(cols - 1, col))
        row = Math.max(0, Math.min(rows - 1, row))
        if (snap) {
            col = Math.round(col); row = Math.round(row)
            if (!cellFree(col, row, id, el.type)) return
        }
        el.col = col; el.row = row
        elemRev++
    }
    // 90 degree steps, kept unbounded so the animation always turns forward
    function rotateElement(id) {
        const el = elemAt(id)
        if (!el) return
        el.rot = (el.rot || 0) + 90
        elemRev++
    }
    function toggleSwitch(id) {
        const el = elemAt(id)
        if (!el || el.type !== "switch") return
        el.on = !el.on
        elemRev++
        resolve()
    }
    // Resistance runs over the real E12 series, the values a shop actually
    // sells - which is also what makes the colour bands honest, since a band
    // code encodes two significant digits and a decade.
    readonly property var resistorSteps: {
        const e12 = [10, 12, 15, 18, 22, 27, 33, 39, 47, 56, 68, 82]
        const out = []
        for (let dec = 1; dec <= 100; dec *= 10)
            for (const v of e12) out.push(v * dec)
        out.push(10000)
        return out
    }
    function resistorStepOf(ohms) {
        let best = 0, bd = Infinity
        for (let i = 0; i < resistorSteps.length; ++i) {
            const d = Math.abs(Math.log(resistorSteps[i]) - Math.log(Math.max(1, ohms)))
            if (d < bd) { bd = d; best = i }
        }
        return best
    }
    function setResistanceStep(id, step) {
        const el = elemAt(id)
        if (!el || el.type !== "resistor") return
        const v = resistorSteps[Math.max(0, Math.min(resistorSteps.length - 1, step))]
        if (v === el.value) return
        el.value = v
        elemRev++
        resolve()
    }
    function addWire(a, b) {
        if (a[0] === b[0] && a[1] === b[1]) return
        for (const w of wires) {
            const same = (w.a[0] === a[0] && w.a[1] === a[1] && w.b[0] === b[0] && w.b[1] === b[1])
                      || (w.a[0] === b[0] && w.a[1] === b[1] && w.b[0] === a[0] && w.b[1] === a[1])
            if (same) return
        }
        wires = wires.concat([{ id: nextId++, a: a, b: b }])
        resolve()
    }
    function removeWire(id) {
        wires = wires.filter(w => w.id !== id)
        resolve()
    }
    function clearBoard() {
        elements = []; wires = []
        wiringFrom = null
        selectedId = -1
        monitor.clear()
        resolve()
    }

    // --- camera -----------------------------------------------------------
    // An orbit cam on a leash (the kernel's OrbitCamera3D): it always looks at
    // the setup, always stays above the board and outside the parts, and it
    // reframes itself for the scenario that is on the board. The leash that
    // matters is minHeight - flatten the angle and the rig backs off instead
    // of diving through the setup, which a minimum DISTANCE could not do
    // without also blocking a zoom onto a single part.
    function frameCells(cells) {
        if (!cells || !cells.length) {
            rig.pivot = Qt.vector3d(0, 2, 0)
            rig.setDistance(rig.maxDistance)
            return
        }
        // a single part is a point; give the frame some extent so the camera
        // lands on something rather than diving at it
        const pts = []
        for (const c of cells) {
            pts.push(Qt.vector3d(cellX(c.col) - 7, 2, cellZ(c.row) - 7))
            pts.push(Qt.vector3d(cellX(c.col) + 7, 2, cellZ(c.row) + 7))
        }
        rig.frame(pts, 1.25)
    }
    function frameAll() { frameCells(elements) }
    function frameSetup() { frameAll() }          // the flow's "frame" verb
    function frameSelection() {
        const el = elemAt(selectedId)
        frameCells(el ? [el] : elements)
    }
    function orbitBy(dYaw, dPitch) { rig.orbitBy(dYaw, -dPitch) }
    function zoomBy(f) { rig.zoomBy(f) }

    // --- serialization (survives reloads via the viewState convention) ---
    function circuitState() {
        return { elements: elements.map(el => Object.assign({}, el)),
                 wires: wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() })),
                 nextId: nextId }
    }
    function loadCircuit(s) {
        elements = s.elements.map(el => Object.assign({ rot: 0 }, el))
        wires = s.wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() }))
        nextId = s.nextId
        wiringFrom = null
        selectedId = -1
        resolve()
    }

    function viewState() {
        return Object.assign(Lab.viewState(), {
            circuit: circuitState(),
            watch: monitor.watched.slice(), watchQuantity: monitor.quantity,
            lang: LabLang.lang,
            cam: rig.state()
        })
    }
    // The user's board wins over the scenario preset: with a circuit payload
    // the scenario is NOT re-applied, the exact board comes back instead.
    // The viewpoint is restored last, so a rearmed scenario cannot yank the
    // camera away from where the user was looking.
    function applyViewState(s) {
        if (s.circuit) {
            loadCircuit(s.circuit)
            // keep the name the board came from without re-running the preset,
            // otherwise the header claims a scenario the board is no longer in
            if (s.scenario) Lab.scenario = s.scenario
        }
        else if (s.scenario) applyScenario(s.scenario)
        // the watched set is the user's, so it wins over what a preset seeded;
        // parts that no longer exist are dropped rather than plotted as zero
        if (s.lang) LabLang.lang = s.lang
        if (s.watchQuantity) monitor.quantity = s.watchQuantity
        if (s.watch) monitor.watchOnly(s.watch.filter(id => elemAt(id) !== null))
        if (s.cam) {
            rig.applyState(s.cam)
        }
        Lab.applyViewState(s)
    }

    // --- scenarios --------------------------------------------------------
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "led-basic"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 6, 2)
                const sw = root.addElement("switch", 12, 2)
                const res = root.addElement("resistor", 6, 8)
                const led = root.addElement("led", 12, 8)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [led, 1])
                root.addWire([led, 0], [res, 1])
                root.addWire([res, 0], [bat, 0])
                // one current through both, but the volts split between them
                root.watchOnly([led, res])
            }
        }
        Scenario {
            name: "series"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 4, 2)
                const sw = root.addElement("switch", 10, 2)
                const b1 = root.addElement("bulb", 16, 2)
                const b2 = root.addElement("bulb", 16, 8)
                const jc = root.addJunction(4, 8)   // corner, so the loop is a rectangle
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [b1, 0])
                root.addWire([b1, 1], [b2, 1])
                root.addWire([b2, 0], [jc, 0])
                root.addWire([jc, 0], [bat, 0])
                // cell vs one bulb: same current, and V shows the cell's volts
                // shared out between the two
                root.watchOnly([bat, b1])
            }
        }
        Scenario {
            // Drawn as a ladder on purpose: two rungs between two rails, the
            // source at the bottom. Same circuit as before, but now it looks
            // like the textbook picture instead of a star of long diagonals.
            name: "parallel"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 5, 10)
                const sw = root.addElement("switch", 11, 10)
                const b1 = root.addElement("bulb", 10, 2)
                const b2 = root.addElement("bulb", 10, 6)
                const jl1 = root.addJunction(5, 2), jl2 = root.addJunction(5, 6)
                const jr1 = root.addJunction(15, 2), jr2 = root.addJunction(15, 6)
                root.addWire([jl1, 0], [b1, 0]); root.addWire([b1, 1], [jr1, 0])
                root.addWire([jl2, 0], [b2, 0]); root.addWire([b2, 1], [jr2, 0])
                root.addWire([jl1, 0], [jl2, 0])   // left rail
                root.addWire([jr1, 0], [jr2, 0])   // right rail
                root.addWire([jl2, 0], [bat, 0])
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [jr2, 0])
                // the same pair as in series, and now I splits while V doesn't
                root.watchOnly([bat, b1])
            }
        }
        Scenario {
            name: "metering"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 4, 2)
                const sw = root.addElement("switch", 10, 2)
                const amp = root.addElement("ammeter", 16, 2)
                const res = root.addElement("resistor", 4, 8)
                const led = root.addElement("led", 10, 8)
                const volt = root.addElement("voltmeter", 16, 8)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [amp, 1])
                root.addWire([amp, 0], [led, 1])
                root.addWire([led, 0], [res, 1])
                root.addWire([res, 0], [bat, 0])
                root.addWire([volt, 0], [led, 0])
                root.addWire([volt, 1], [led, 1])
                root.watchOnly([led])
            }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        const r = scenarioSet.apply(n)
        frameSetup()   // every preset arrives properly framed
        return r
    }

    // --- flow actions (SPIKE, see mgc/groundwork/lab-flows-2026-07-25.md) ---
    // One mutation API, three drivers: the UI below calls these same
    // functions, a Flow calls them by name, and an agent can call them
    // through the inspector's eval. Nothing here is flow-only.
    function flowActions() {
        return {
            "addPart":    (type, col, row) => addElement(type, col, row),
            "wire":       (a, ta, b, tb) => addWire([a, ta], [b, tb]),
            "flipSwitch": (id) => toggleSwitch(id),
            "setVolts":   (id, v) => setBatteryVolts(id, v),
            "setOhms":    (id, ohms) => setResistanceStep(id, resistorStepOf(ohms)),
            "watch":      (id, on) => setWatched(id, on),
            "select":     (id) => { selectedId = id },
            "showValues": (on) => { showValues = on },
            "clear":      () => clearBoard(),
            "scenario":   (n) => applyScenario(n),
            "frame":      (what) => what === "selection" ? frameSelection() : frameSetup()
        }
    }
    function flows() { return [ledFlow.flowId] }
    function startFlow(id) {
        if (id === ledFlow.flowId) { ledFlow.start(); return true }
        return false
    }

    function labInfo() {
        const info = Lab.labInfo()
        const byType = {}
        for (const el of elements) byType[el.type] = (byType[el.type] || 0) + 1
        info.circuit = { elements: byType, wires: wires.length,
                         nets: sim.netCount || 0, shorted: sim.shorted,
                         iterations: sim.iterations }
        // language-neutral for agents: types and ids, not display labels
        info.flow = { id: ledFlow.running ? ledFlow.flowId : "",
                      step: ledFlow.index, paused: ledFlow.paused,
                      waiting: ledFlow.waiting }
        info.ui = { selected: selectedId, snap: grid.snap,
                    watching: watch.map(id => ({ id: id, type: elemAt(id).type })),
                    quantity: monitor.quantity, lang: LabLang.lang }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- interaction state ------------------------------------------------
    // Grid mode follows grafli's contract: # cycles it, Alt inverts it for one
    // drag, and the pegs show which mode is on (crosses while snapping, dots
    // when free).
    GridMode { id: grid }
    // readable from inside delegates, where an outer id is not in scope
    readonly property bool snapToGrid: grid.snap

    property var wiringFrom: null       // {el, ti} while a wire is dangling
    property bool eraser: false
    property var hoverHit: null         // last hit under the cursor
    property var cursorW: Qt.vector3d(0, 1.9, 0)
    property string paletteDrag: ""     // element type while dragging from GUI
    property int selectedId: -1         // -1 = nothing selected
    property bool showValues: false     // V: label every part and every wire
    property bool showPlan: true        // M: the schematic minimap

    // world-space hit test against the data model (no per-model picking)
    function hitAt(wx, wz) {
        // terminals first (they sit inside the element radius)
        for (const el of elements)
            for (let ti = 0; ti < 2; ++ti) {
                const p = terminalPos(el.id, ti)
                if (Math.hypot(p.x - wx, p.z - wz) < 2.3)
                    return { kind: "terminal", el: el.id, ti: ti }
            }
        for (const el of elements) {
            const x = cellX(el.col), z = cellZ(el.row)
            if (el.type === "junction") continue   // handled as a terminal
            // body box turned by the part's yaw -> axis-aligned bound of it
            const a = (el.rot || 0) * Math.PI / 180
            const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a))
            if (Math.abs(x - wx) < 4.6 * c + 3.4 * s
                && Math.abs(z - wz) < 4.6 * s + 3.4 * c)
                return { kind: "element", el: el.id, type: el.type }
        }
        // wires lie flat on the board, so a point-to-segment distance is all
        // it takes to grab one anywhere along its length
        for (const w of wires) {
            const a = terminalPos(w.a[0], w.a[1])
            const b = terminalPos(w.b[0], w.b[1])
            const dx = b.x - a.x, dz = b.z - a.z
            const len2 = dx * dx + dz * dz
            const t = len2 < 1e-9 ? 0
                : Math.max(0, Math.min(1, ((wx - a.x) * dx + (wz - a.z) * dz) / len2))
            if (Math.hypot(a.x + t * dx - wx, a.z + t * dz - wz) < 1.3)
                return { kind: "wire", wire: w.id }
        }
        return null
    }

    // --- wires --------------------------------------------------------------
    // Wires are drawn flat on the board, as one instanced line batch: that is
    // what buys arrowheads and a flowing current animation, and it stays a
    // single draw call however many wires the board grows. Nothing expects a
    // shadow from a line lying on the paper, so the shadow question is simply
    // gone (a batch could not cast one anyway - see LineBatch3D).
    readonly property real wireY: 0.12

    function wireEnds(w) {
        const a = terminalPos(w.a[0], w.a[1])
        const b = terminalPos(w.b[0], w.b[1])
        return [Qt.vector3d(a.x, wireY, a.z), Qt.vector3d(b.x, wireY, b.z)]
    }

    // Style 0 is the idle wire; 1..flowSteps march chevrons at increasing
    // speed. The speed is relative to the largest current on the board, not
    // absolute, so a junction visibly splits: the trunk runs at full speed
    // and each branch at its share of it.
    readonly property int flowSteps: 6

    function wireStyle(amps, iMax) {
        const m = Math.abs(amps)
        if (!(m > 1e-5)) return 0
        const rel = iMax > 1e-9 ? m / iMax : 1
        return 1 + Math.min(flowSteps - 1, Math.max(0, Math.round((flowSteps - 1) * rel)))
    }

    // Two lines per wire: the ink body, plus a chevron overlay that marches
    // along it while current flows. The overlay rides a hair above the body
    // so the two never fight over depth.
    function wireLines() {
        elemRev
        let iMax = 0
        for (const w of wires) {
            const c = sim.wireCurrent ? sim.wireCurrent[w.id] : null
            if (c !== null && c !== undefined) iMax = Math.max(iMax, Math.abs(c))
        }
        const out = []
        for (const w of wires) {
            const pts = wireEnds(w)
            const i = sim.wireCurrent ? sim.wireCurrent[w.id] : null
            const amps = (i === null || i === undefined) ? 0 : i
            const style = wireStyle(amps, iMax)
            const hovered = hoverHit && hoverHit.kind === "wire" && hoverHit.wire === w.id

            // a wire past the cell's rating is the one that would get hot:
            // in a short this paints the bypass path, which is the answer to
            // "where is all that current going?"
            const hot = Math.abs(amps) > root.ratedCurrent
            out.push({ points: pts,
                       color: hovered ? (eraser ? LabTheme.alarm : LabTheme.secondary)
                            : hot ? LabTheme.alarm
                            : (style === 0 ? LabTheme.inkFaint : LabTheme.ink),
                       width: hot ? 0.66 : 0.5, styleId: 0 })
            if (style === 0) continue

            // chevrons point from the first point to the last, so a negative
            // current simply draws the overlay the other way round
            const flow = amps < 0 ? [pts[1], pts[0]] : pts
            out.push({ points: flow.map(p => Qt.vector3d(p.x, p.y + 0.05, p.z)),
                       color: LabTheme.highlight, width: 0.62, styleId: style })
        }
        return out
    }


    // --- 3D scene ---------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera

        environment: SceneEnvironment {
            // slightly lighter than the table below, so that a horizon line
            // appears at low camera angles - the eye keeps a reference
            clearColor: LabTheme.board
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
        }

        Model {  // the table the board lies on: grounds the view from any angle
            source: "#Cube"
            position: Qt.vector3d(0, -4.2, 0)
            // deliberately modest: the shadow volume grows with the scene, and
            // a table the size of the horizon would starve the shadow map
            scale: Qt.vector3d(2.4, 0.02, 1.9)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColor: LabTheme.table
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 2, 0)
            yaw: 0
            pitch: 48
            distance: 80
            minPitch: 22          // never skim along the board
            maxPitch: 84          // never flip over the top
            minDistance: 20       // clears a single part
            maxDistance: 170
            minHeight: 9          // taller than anything standing on the board
            Behavior on pivot { Vector3dAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on distance { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }

        // Three soft lights instead of one hard one: key with shadows, side
        // fill, and a low camera-side fill so unlit faces still separate.
        // Nothing in the scene is glossy, so depth comes from value, not glare.
        //
        // The shadows are real (GPU shadow map), kept legible by keeping the
        // shadow volume small: shadowMapFar bounds it to the table instead of
        // the horizon and the cascades spend their texels near the camera.
        // That is what lets a 0.55-unit wire cast a readable shadow.
        DirectionalLight {
            id: keyLight
            eulerRotation.x: -35
            eulerRotation.y: -25
            brightness: 0.9
            castsShadow: true
            shadowFactor: LabTheme.shadowFactor   // present, not dramatic
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            // far enough to still cover the setup at maximum zoom-out (the
            // range is measured from the camera), with cascades spending the
            // texels near it; a small bias - 10+ pushes thin shadows off the
            // board entirely, 0 turns the whole board into acne
            shadowMapFar: 250
            csmNumSplits: 2
            shadowBias: 3
            softShadowQuality: Light.PCF4
            pcfFactor: 1
        }
        DirectionalLight {
            eulerRotation.x: -60
            eulerRotation.y: 140
            brightness: 0.35
        }
        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: 20
            brightness: 0.28
        }

        Model {  // pegboard - the only pickable model; everything maps through it
            id: boardModel
            source: "#Cube"
            pickable: true
            position: Qt.vector3d(0, -2, 0)
            scale: Qt.vector3d(1.06, 0.04, 0.66)
            materials: PrincipledMaterial {
                baseColor: LabTheme.sheet
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
        Box3D {  // rim
            width: 112; height: 1.6; depth: 72
            position: Qt.vector3d(0, -3.8, 0)
            color: LabTheme.inkSolid
            useToonShading: true
        }
        // Peg marks: round dots when parts move freely, crisp squares while
        // the grid snaps - the board itself tells you which mode you are in
        // (that cue is borrowed from grafli's grid modes). One model per peg,
        // so the denser raster stays cheap.
        Repeater3D {
            model: root.cols * root.rows
            Model {
                source: root.snapToGrid ? "#Cube" : "#Cylinder"
                castsShadows: false   // they are print on the board, not objects
                position: Qt.vector3d(root.cellX(index % root.cols), 0.05,
                                      root.cellZ(Math.floor(index / root.cols)))
                scale: root.snapToGrid ? Qt.vector3d(0.006, 0.0008, 0.006)
                                       : Qt.vector3d(0.005, 0.001, 0.005)
                materials: PrincipledMaterial {
                    baseColor: LabTheme.grid
                    lighting: PrincipledMaterial.NoLighting
                }
            }
        }

        Repeater3D {  // the parts
            id: partRepeater
            model: root.elements
            CircuitElement3D {
                // modelData is a COPY of the plain JS object - mutable state
                // (cell, switch, ohms) must be read live from root.elements,
                // and each binding needs its own elemRev dependency: routing
                // them through a shared var would re-yield the same object
                // reference, which QML treats as "unchanged" (no notify).
                // parts sit slightly sunk into the board, so they read as
                // pressed in and their shadow hugs them instead of floating
                position: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? Qt.vector3d(root.cellX(e.col), -0.45, root.cellZ(e.row))
                             : Qt.vector3d(0, 0, 0)
                }
                eulerRotation.y: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? (e.rot || 0) : 0
                }
                Behavior on eulerRotation.y { NumberAnimation { duration: 150 } }
                type: modelData.type
                selected: root.selectedId === modelData.id
                value: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? e.value : modelData.value
                }
                switchOn: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? e.on : false
                }
                simI: root.simOf(modelData.id).i
                simV: root.simOf(modelData.id).v
                simPower: root.simOf(modelData.id).power
                lit: root.simOf(modelData.id).on
                shorted: {
                    const b = root.batteryOf(modelData.id)
                    return b !== null && b.shorted
                }
                overloaded: {
                    const b = root.batteryOf(modelData.id)
                    return b !== null && b.overloaded
                }
                hovered: root.hoverHit !== null && root.hoverHit.kind === "element"
                         && root.hoverHit.el === modelData.id
                wiringTerminal: {
                    if (root.wiringFrom && root.wiringFrom.el === modelData.id)
                        return root.wiringFrom.ti
                    if (root.hoverHit && root.hoverHit.kind === "terminal"
                        && root.hoverHit.el === modelData.id)
                        return root.hoverHit.ti
                    return -1
                }
            }
        }

        LineBatch3D {  // every wire, one instanced draw call
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat     // ribbons lie in the board plane
            opaque: true                      // crossings resolve by depth
            depthBias: 4
            castsShadows: false
            flowTime: clock.time              // sim clock: the flow is deterministic
            flowAutoPlay: false
            styles: [
                { dash: [0, 0], capRound: true, opacity: 1.0 },
                // deliberately unhurried: the flow is there to be read, not
                // to make the board feel busy
                { dash: [1.4, 3.4], pattern: "chevron", flow: 1.0 },
                { dash: [1.4, 3.4], pattern: "chevron", flow: 1.8 },
                { dash: [1.4, 3.4], pattern: "chevron", flow: 2.8 },
                { dash: [1.4, 3.4], pattern: "chevron", flow: 4.0 },
                { dash: [1.4, 3.4], pattern: "chevron", flow: 5.4 },
                { dash: [1.4, 3.4], pattern: "chevron", flow: 7.0 }
            ]
            lines: {
                root.elemRev; root.sim; root.hoverHit; root.eraser
                return root.wireLines()
            }
        }

        MultiLine3D {  // dangling wire preview - flat, like the real thing
            visible: root.wiringFrom !== null
            coords: {
                if (!root.wiringFrom) return []
                const a = root.terminalPos(root.wiringFrom.el, root.wiringFrom.ti)
                const b = root.cursorW
                return [[Qt.vector3d(a.x, root.wireY, a.z),
                         Qt.vector3d(b.x, root.wireY, b.z)]]
            }
            color: LabTheme.secondary
            width: 0.4
        }
    }

    // --- mouse interaction ------------------------------------------------
    MouseArea {
        id: boardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property var dragElem: null
        property bool dragged: false
        property var pressW: null
        property bool orbiting: false
        property real lastX: 0
        property real lastY: 0
        // Alt inverts the current grid mode for the length of one drag
        function snapping(mods) {
            return grid.snapping(mods)
        }

        function worldAt(mx, my) {
            const res = view3d.pick(mx, my)
            if (res && res.objectHit === boardModel) return res.scenePosition
            return null
        }

        onWheel: (wheel) => root.zoomBy(wheel.angleDelta.y > 0 ? 0.88 : 1.14)

        onPositionChanged: (mouse) => {
            if (pressed && orbiting) {
                root.orbitBy((mouse.x - lastX) * 0.32, (mouse.y - lastY) * 0.22)
                lastX = mouse.x; lastY = mouse.y
                return
            }
            const w = worldAt(mouse.x, mouse.y)
            if (!w) return
            root.cursorW = Qt.vector3d(w.x, 1.9, w.z)
            if (pressed && dragElem) {
                if (!dragged && pressW && Math.hypot(w.x - pressW.x, w.z - pressW.z) > 1.2)
                    dragged = true
                if (dragged)
                    root.moveElement(dragElem,
                                     w.x / root.cell + (root.cols - 1) / 2,
                                     w.z / root.cell + (root.rows - 1) / 2,
                                     snapping(mouse.modifiers))
            } else {
                root.hoverHit = root.hitAt(w.x, w.z)
            }
        }
        onPressed: (mouse) => {
            root.forceActiveFocus()
            const w = worldAt(mouse.x, mouse.y)
            pressW = w; dragged = false; dragElem = null
            orbiting = false; lastX = mouse.x; lastY = mouse.y
            const hit = w ? root.hitAt(w.x, w.z) : null
            if (mouse.button === Qt.RightButton) {
                if (hit && (hit.kind === "element" || hit.kind === "terminal")) {
                    root.selectedId = hit.el
                    root.rotateElement(hit.el)
                }
                return
            }
            // empty board (or off-board): the drag turns the view instead
            if (!hit) {
                root.selectedId = -1
                if (!root.eraser) root.wiringFrom = null
                orbiting = true
                return
            }
            if (root.eraser) {
                if (hit.kind === "wire") root.removeWire(hit.wire)
                else if (hit.kind === "element" || hit.kind === "terminal")
                    root.removeElement(hit.el)
                return
            }
            // Clicking a wire taps into it: a junction is dropped where you
            // clicked and the wire splits, so you can branch off anywhere.
            if (hit.kind === "wire") {
                const j = root.splitWireAt(hit.wire, w.x, w.z)
                if (j === -1) return
                if (root.wiringFrom) {
                    root.addWire([root.wiringFrom.el, root.wiringFrom.ti], [j, 0])
                    root.wiringFrom = null
                } else {
                    root.wiringFrom = { el: j, ti: 0 }
                }
                return
            }
            if (hit.kind === "terminal") {
                const el = root.elemAt(hit.el)
                // an idle click on a junction grabs the dot itself; while
                // wiring, the same click connects to it
                if (el && el.type === "junction" && root.wiringFrom === null) {
                    root.selectedId = hit.el
                    dragElem = hit.el
                    return
                }
                if (root.wiringFrom === null)
                    root.wiringFrom = { el: hit.el, ti: hit.ti }
                else {
                    root.addWire([root.wiringFrom.el, root.wiringFrom.ti],
                                 [hit.el, hit.ti])
                    root.wiringFrom = null
                }
                return
            }
            if (hit.kind === "element") {
                root.selectedId = hit.el
                dragElem = hit.el
            }
            ledFlow.takeOver()   // the learner is driving now, not the flow
        }
        onReleased: {
            if (dragElem && !dragged) {
                const el = root.elemAt(dragElem)
                if (el && el.type === "switch") root.toggleSwitch(dragElem)
                // a resistor is set with the slider on its selection card
            }
            dragElem = null; dragged = false; orbiting = false
        }
    }

    // --- palette ----------------------------------------------------------
    readonly property var partCatalog: [
        { type: "battery", color: "#3e9b92" },
        { type: "switch", color: "#c56c54" },
        { type: "resistor", color: "#d9c9a0" },
        { type: "led", color: "#e05a40" },
        { type: "bulb", color: "#d4ba6a" },
        { type: "ammeter", color: "#3f7a57" },
        { type: "voltmeter", color: "#8160a8" }
    ]

    LabPanel {
        id: palette
        x: 12; y: 12
        width: 208
        title: LabLang.t("lab.title")

        // The presets, clickable and each carrying what it is worth noticing.
        // They used to be reachable only by pressing 1..4, with nothing but
        // the active name on screen - the best material in the lab, hidden.
        ScenarioBar {
            lab: root
            width: 188
        }
        // and the offer to be taught, from the first frame
        FlowChip { flow: ledFlow }
        Item { width: 1; height: 2 }
        Column {
            spacing: 4
            Repeater {
                model: root.partCatalog
                Rectangle {
                    width: 188; height: 40; radius: 6
                    color: partArea.containsMouse ? LabTheme.panel : LabTheme.paper
                    border.color: partArea.containsMouse ? LabTheme.secondary : LabTheme.panelEdge
                    Rectangle {  // the part's colour on the board
                        x: 6; y: 15; width: 10; height: 10; radius: 3
                        color: modelData.color
                    }
                    // and its schematic symbol: the palette is where a kit can
                    // teach "this lump is that squiggle" for free
                    SymbolIcon {
                        x: 20; anchors.verticalCenter: parent.verticalCenter
                        type: modelData.type
                        ink: LabTheme.inkSoft
                    }
                    Column {
                        x: 60; anchors.verticalCenter: parent.verticalCenter
                        Text { text: LabLang.t("part." + modelData.type); color: LabTheme.ink; font.pixelSize: 12; font.bold: true; font.family: LabTheme.monoFont }
                        // bounded: a translated hint is often longer than the
                        // English one and must not run out of the panel
                        Text {
                            text: LabLang.t("part." + modelData.type + ".hint")
                            width: 122; elide: Text.ElideRight
                            color: LabTheme.inkFaint; font.pixelSize: 12
                            font.family: LabTheme.handFont
                        }
                    }
                    MouseArea {
                        id: partArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onPressed: root.paletteDrag = modelData.type
                        onReleased: (mouse) => {
                            const inView = mapToItem(root, mouse.x, mouse.y)
                            const w = boardMouse.worldAt(inView.x, inView.y)
                            if (w)
                                root.addElement(root.paletteDrag,
                                                w.x / root.cell + (root.cols - 1) / 2,
                                                w.z / root.cell + (root.rows - 1) / 2)
                            else
                                root.addElement(root.paletteDrag)
                            root.paletteDrag = ""
                        }
                    }
                }
            }
            Item { width: 1; height: 4 }
            Rectangle {
                width: 188; height: 30; radius: 6
                color: root.eraser ? LabTheme.clay : LabTheme.paper
                border.color: root.eraser ? LabTheme.alarm : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t(root.eraser ? "btn.eraser.on" : "btn.eraser")
                    color: LabTheme.inkOn(parent.color); font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.eraser = !root.eraser }
            }
            Rectangle {
                width: 188; height: 30; radius: 6
                color: LabTheme.paper
                border.color: root.showValues ? LabTheme.secondary : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t(root.showValues ? "btn.values.on" : "btn.values.off")
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.showValues = !root.showValues }
            }
            Rectangle {
                width: 188; height: 30; radius: 6
                color: LabTheme.paper
                border.color: grid.snap ? LabTheme.secondary : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t(grid.snap ? "btn.grid.snap" : "btn.grid.free")
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: grid.toggle() }
            }
            Rectangle {
                width: 188; height: 30; radius: 6
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t("btn.clear")
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearBoard() }
            }
        }
    }

    // --- flow (SPIKE) ------------------------------------------------------
    // "Why does the LED light?" - a demo that builds the circuit, hands the
    // switch to the learner, then explains the number it produced.
    Flow {
        id: ledFlow
        lab: root
        flowId: "led-basics"
        titleKey: "flow.led-basics.title"

        FlowStep {
            key: "empty"
            demo: [["clear"], ["showValues", false], ["frame", "setup"]]
        }
        FlowStep {
            key: "battery"
            demo: [["let", "bat", "addPart", "battery", 6, 2],
                   ["select", "bat"], ["frame", "selection"]]
        }
        FlowStep {
            key: "led"
            demo: [["let", "led", "addPart", "led", 12, 8],
                   ["select", "led"], ["frame", "selection"]]
        }
        FlowStep {
            key: "resistor"
            demo: [["let", "res", "addPart", "resistor", 6, 8],
                   ["setOhms", "res", 470],
                   ["select", "res"], ["frame", "selection"]]
        }
        FlowStep {
            key: "wire"
            demo: [["let", "sw", "addPart", "switch", 12, 2],
                   ["select", -1], ["frame", "setup"],
                   ["wire", "bat", 1, "sw", 0],
                   ["wire", "sw", 1, "led", 1],
                   ["wire", "led", 0, "res", 1],
                   ["wire", "res", 0, "bat", 0]]
        }
        FlowStep {
            key: "flip"
            task: ({ "until": (n) => { const e = root.elemAt(n("sw")); return e && e.on },
                     "hint": "flow.led-basics.flip.hint",
                     "hintAfter": 7,
                     "solve": [["flipSwitch", "sw"]] })
        }
        FlowStep {
            key: "lit"
            demo: [["watch", "led", true]]
            expect: (n) => Math.abs(root.simOf(n("led")).i - 0.00515) < 5e-5
        }
        FlowStep { key: "why" }
        FlowStep {
            key: "values"
            demo: [["showValues", true]]
        }
        FlowStep {
            key: "try"
            demo: [["select", "res"], ["frame", "selection"]]
        }
    }
    Narrator {
        flow: ledFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: Math.min(680, root.width - 2 * (root.width - monitor.x) - 24)
    }

    // --- language ----------------------------------------------------------
    // Top right, out of the way of the board: the lab is meant for a
    // classroom, and a German class should read it in German.
    // Language and palette, the two switches that change nothing about the
    // experiment and everything about who can read it.
    Row {
        id: topSwitches
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 6
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }

    // --- compass: which way the board faces while you circle it ------------
    Compass {
        // beside the palette rather than under it: the palette carries the
        // presets and the tour offer now, and the slot below it is the
        // schematic's
        x: palette.x + palette.width + 10
        y: 12
        yaw: rig.yaw
        aspect: root.cols / root.rows
    }

    // drag ghost following the cursor while dragging out of the palette
    Rectangle {
        visible: root.paletteDrag !== "" && ghostArea.mx > 0
        x: ghostArea.mx + 10; y: ghostArea.my - 14
        width: ghostLabel.width + 18; height: 26; radius: 6
        color: LabTheme.panel; border.color: LabTheme.secondary
        Text {
            id: ghostLabel
            anchors.centerIn: parent
            text: root.paletteDrag === "" ? "" : LabLang.t("part." + root.paletteDrag)
            color: LabTheme.primary; font.pixelSize: 12
            font.family: LabTheme.monoFont
        }
    }
    MouseArea {
        id: ghostArea
        anchors.fill: parent
        enabled: false
        hoverEnabled: root.paletteDrag !== ""
        property real mx: -1
        property real my: -1
        onPositionChanged: (mouse) => { mx = mouse.x; my = mouse.y }
    }

    // --- meter readouts (2D, pinned above the gauges) ----------------------
    Repeater {
        model: root.elements
        Rectangle {
            readonly property bool isMeter: modelData.type === "ammeter"
                                            || modelData.type === "voltmeter"
            readonly property var screenAt: {
                // re-project whenever the part moves OR the camera does
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const e = root.elemAt(modelData.id)
                if (!e) return Qt.vector3d(0, 0, 0)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    root.cellX(e.col), 7.5, root.cellZ(e.row)))
            }
            readonly property string reading: {
                const s = root.simOf(modelData.id)
                if (modelData.type === "ammeter") return root.fmtA(s.i)
                return root.fmtV(s.v)
            }
            visible: isMeter && screenAt.z > 0
            x: Math.max(4, Math.min(root.width - width - 4, screenAt.x - width / 2))
            y: Math.max(4, Math.min(root.height - height - 4, screenAt.y - height))
            width: readingText.width + 18
            height: 24
            radius: 12
            color: LabTheme.panel
            border.color: modelData.type === "ammeter" ? LabTheme.forest : LabTheme.plum
            border.width: 1.5
            Text {
                id: readingText
                anchors.centerIn: parent
                text: (modelData.type === "ammeter" ? "A " : "V ") + parent.reading
                color: LabTheme.ink; font.pixelSize: 13; font.bold: true
                font.family: LabTheme.monoFont
            }
        }
    }

    // --- schematic minimap (Schaltplan) ------------------------------------
    // The same board, drawn the way a circuit diagram draws it: symbols where
    // the parts are, lines where the wires are. The 3D board says what you
    // built; this says what it *is*. Both stay in step because they read the
    // same model - and the symbols are the very ones from the palette.
    LabPanel {
        id: plan
        visible: root.showPlan
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 44
        width: 250
        height: 176
        title: LabLang.t("plan.title")
        tag: "M"

        Canvas {
            id: planCanvas
            width: plan.body.width
            height: plan.body.height

            // one repaint trigger for everything the diagram depends on
            readonly property int rev: root.elemRev + root.selectedId * 7919
                                       + (root.showPlan ? 1 : 0)
            readonly property var simRef: root.sim
            onRevChanged: requestPaint()
            onSimRefChanged: requestPaint()
            Connections {
                target: root
                function onHoverHitChanged() { planCanvas.requestPaint() }
                function onShowPlanChanged() { planCanvas.requestPaint() }
            }

            // Fits the parts, not the whole board: an empty pegboard would
            // squeeze the diagram into a corner. Uniform scale, so the shape
            // of the circuit stays the shape you built.
            readonly property var fit: {
                root.elemRev
                const pad = 26
                if (!root.elements.length)
                    return { s: 1, ox: width / 2, oy: height / 2, cx: 0, cy: 0 }
                let c0 = Infinity, c1 = -Infinity, r0 = Infinity, r1 = -Infinity
                for (const el of root.elements) {
                    c0 = Math.min(c0, el.col); c1 = Math.max(c1, el.col)
                    r0 = Math.min(r0, el.row); r1 = Math.max(r1, el.row)
                }
                const spanC = Math.max(1.2, c1 - c0), spanR = Math.max(1.2, r1 - r0)
                const s = Math.min((width - 2 * pad) / spanC, (height - 2 * pad) / spanR)
                return { s: s, ox: width / 2, oy: height / 2,
                         cx: (c0 + c1) / 2, cy: (r0 + r1) / 2 }
            }
            function px(col) { return fit.ox + (col - fit.cx) * fit.s }
            function py(row) { return fit.oy + (row - fit.cy) * fit.s }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()

                // wires first, so symbols sit on top of their leads. Ends go
                // to the terminal, not the part centre - otherwise a wire
                // bridging one part's own two terminals (a short across the
                // cell) would collapse to a point and vanish from the diagram.
                function end(ref) {
                    const el = root.elemAt(ref[0])
                    if (!el) return null
                    if (el.type === "junction")
                        return { x: px(el.col), y: py(el.row) }
                    const off = ref[1] === 0 ? -0.7 : 0.7
                    const a = (el.rot || 0) * Math.PI / 180
                    return { x: px(el.col + off * Math.cos(a)),
                             y: py(el.row - off * Math.sin(a)) }
                }
                for (const w of root.wires) {
                    const a = end(w.a), b = end(w.b)
                    if (!a || !b) continue
                    const i = root.sim.wireCurrent ? root.sim.wireCurrent[w.id] : null
                    const amps = (i === null || i === undefined) ? 0 : Math.abs(i)
                    const hot = amps > root.ratedCurrent
                    ctx.strokeStyle = (hot ? LabTheme.alarm
                                     : amps > 1e-5 ? LabTheme.ink
                                     : LabTheme.inkFaint).toString()
                    ctx.lineWidth = hot ? 2.4 : (amps > 1e-5 ? 1.6 : 1.2)
                    ctx.beginPath()
                    ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y)
                    ctx.stroke()
                }

                for (const el of root.elements) {
                    const sel = el.id === root.selectedId
                    const hov = root.hoverHit && root.hoverHit.el === el.id
                    const sw = Math.max(22, Math.min(40, fit.s * 1.5))
                    Symbols.draw(ctx, el.type, px(el.col), py(el.row), sw, sw * 0.66, {
                        ink: (sel || hov ? LabTheme.secondary : LabTheme.ink).toString(),
                        lineWidth: sel ? 2.2 : 1.5,
                        rot: el.rot || 0,
                        on: el.type === "switch" ? el.on : false
                    })
                }
            }
        }
    }

    // --- value labels ------------------------------------------------------
    // The whole point of the lab in one toggle: with V on, every part shows
    // its current and voltage and every wire its current, so series (one
    // current everywhere, voltages divide) and parallel (one voltage, the
    // current splits) can simply be read off the board.
    Repeater {
        model: root.showValues ? root.elements : []
        Rectangle {
            readonly property var screenAt: {
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const e = root.elemAt(modelData.id)
                if (!e) return Qt.vector3d(0, 0, 0)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    root.cellX(e.col), 6.0, root.cellZ(e.row)))
            }
            visible: modelData.type !== "junction" && screenAt.z > 0
            x: Math.max(2, Math.min(root.width - width - 2, screenAt.x - width / 2))
            y: Math.max(2, Math.min(root.height - height - 2, screenAt.y - height))
            width: valueText.width + 12
            height: 20
            radius: 5
            color: LabTheme.panel
            border.color: LabTheme.panelEdge; border.width: 1
            opacity: 0.94
            Text {
                id: valueText
                anchors.centerIn: parent
                // magnitudes only: direction is what the chevrons are for,
                // and a signed reading here only invites "why is it minus?"
                text: {
                    const s = root.simOf(modelData.id)
                    return root.fmtA(Math.abs(s.i)) + "  " + root.fmtV(Math.abs(s.v))
                }
                color: LabTheme.primary; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
        }
    }
    Repeater {
        model: root.showValues ? root.wires : []
        Text {
            readonly property var screenAt: {
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const e = root.wireEnds(modelData)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    (e[0].x + e[1].x) / 2, 0.6, (e[0].z + e[1].z) / 2))
            }
            visible: root.showValues && screenAt.z > 0
            x: screenAt.x - width / 2
            y: screenAt.y - height / 2
            text: {
                const i = root.sim.wireCurrent ? root.sim.wireCurrent[modelData.id] : null
                if (i === null || i === undefined) return "?"
                return root.fmtA(Math.abs(i))
            }
            color: LabTheme.inkSoft; font.pixelSize: 11; font.bold: true
            font.family: LabTheme.monoFont
            style: Text.Outline; styleColor: LabTheme.paperDeep
        }
    }

    // --- watch marks -------------------------------------------------------
    // A tag in the curve's own colour, so "which line is which part" is read
    // off the board instead of guessed from the legend order.
    Repeater {
        model: root.watch
        Rectangle {
            readonly property int pid: modelData
            readonly property var screenAt: {
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const e = root.elemAt(pid)
                if (!e) return Qt.vector3d(0, 0, 0)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    root.cellX(e.col), 6.0, root.cellZ(e.row)))
            }
            visible: screenAt.z > 0
            x: Math.max(2, Math.min(root.width - width - 2, screenAt.x - width / 2))
            // steps aside for the value label when V is on
            y: Math.max(2, Math.min(root.height - height - 2,
                                    screenAt.y - height - (root.showValues ? 23 : 0)))
            width: markRow.width + 12
            height: 18
            radius: 9
            color: LabTheme.panel
            border.color: root.watchColorOf(pid); border.width: 2
            opacity: 0.94
            Row {
                id: markRow
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 4
                    color: root.watchColorOf(pid)
                }
                Text {
                    text: { root.elemRev; return root.partLabel(pid) }
                    color: LabTheme.inkSoft; font.pixelSize: 11; font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
        }
    }

    // --- selection card (what is selected, what it reads, what you can do) -
    LabPanel {
        id: selCard
        padding: 10
        spacing: 1
        border.color: LabTheme.secondary
        readonly property var el: {
            root.elemRev
            return root.selectedId === -1 ? null : root.elemAt(root.selectedId)
        }
        readonly property var screenAt: {
            root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
            if (!el) return Qt.vector3d(0, 0, 0)
            return view3d.mapFrom3DScene(Qt.vector3d(root.cellX(el.col), 0,
                                                     root.cellZ(el.row) + 5.5))
        }
        visible: el !== null && screenAt.z > 0
        // kept inside the window: zoomed in, the anchor point can sit far
        // below the viewport
        x: Math.max(8, Math.min(root.width - width - 8, screenAt.x - width / 2))
        y: Math.max(8, Math.min(root.height - height - 44, screenAt.y + 6))
        width: Math.max(selCol.width + 20, (isResistor || isBattery) ? 196 : 0)
        height: selCol.height + 14
        readonly property bool isResistor: el !== null && el.type === "resistor"
        readonly property bool isBattery: el !== null && el.type === "battery"
        readonly property var bat: {
            root.elemRev; root.sim
            return el && el.type === "battery" ? root.batteryOf(el.id) : null
        }

        Column {
            id: selCol
            spacing: 1
            Text {
                text: {
                    // elemRev per binding: `el` hands back the same object
                    // every time, and re-assigning an identical reference is
                    // not a change as far as QML is concerned
                    root.elemRev
                    if (!selCard.el) return ""
                    const e = selCard.el
                    const name = LabLang.t("part." + e.type).toUpperCase()
                    if (e.type === "resistor")
                        return name + "  " + (e.value >= 1000
                            ? LabLang.num(e.value / 1000, e.value % 1000 ? 1 : 0) + " kΩ"
                            : e.value + " Ω")
                    if (e.type === "battery")
                        return name + "  " + LabLang.num(e.value || root.defaultVolts, 1) + " V"
                    if (e.type === "switch")
                        return name + "  " + LabLang.t(e.on ? "switch.closed" : "switch.open")
                    return name
                }
                color: LabTheme.primary; font.pixelSize: 11; font.bold: true
                font.letterSpacing: 1.0; font.family: LabTheme.monoFont
            }
            Text {
                text: {
                    root.elemRev
                    if (!selCard.el) return ""
                    const s = root.simOf(selCard.el.id)
                    return root.fmtV(s.v) + "   " + root.fmtA(s.i)
                }
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            // Resistance slider: drag it and the colour bands on the part
            // change with the value, because the bands are the real code.
            Item {
                visible: selCard.isResistor || selCard.isBattery
                width: selCard.width - 20
                height: visible ? 22 : 0

                Item {
                    id: rSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 16
                    readonly property int steps: selCard.isBattery
                        ? 21 : root.resistorSteps.length - 1   // 1.5 .. 12 V in 0.5 steps
                    readonly property real ratio: {
                        root.elemRev
                        if (!selCard.el) return 0
                        if (selCard.isBattery)
                            return ((selCard.el.value || root.defaultVolts) - 1.5) / 10.5
                        return steps > 0 ? root.resistorStepOf(selCard.el.value) / steps : 0
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: LabTheme.panelEdge
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: rSlider.ratio * parent.width
                        height: 4; radius: 2
                        color: LabTheme.secondary
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: rSlider.ratio * (parent.width - width)
                        width: 12; height: 12; radius: 6
                        color: LabTheme.panel
                        border.color: LabTheme.ink; border.width: 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        function applyAt(mx) {
                            if (!selCard.el) return
                            const t = Math.max(0, Math.min(1, (mx + 6) / rSlider.width))
                            if (selCard.isBattery)
                                root.setBatteryVolts(selCard.el.id, 1.5 + t * 10.5)
                            else
                                root.setResistanceStep(selCard.el.id,
                                                       Math.round(t * rSlider.steps))
                        }
                        onPressed: (mouse) => applyAt(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x) }
                    }
                }
            }
            // The cell's own account of itself: EMF splits into what it
            // burns inside and what actually reaches the parts. A short is
            // then not a slogan on a banner but a bar gone all-red.
            BudgetBar {
                visible: selCard.isBattery && selCard.bat !== null
                width: selCard.width - 20
                height: visible ? implicitHeight : 0
                unit: "V"
                total: selCard.bat ? selCard.bat.emf : 1
                segments: {
                    root.elemRev
                    const b = selCard.bat
                    if (!b) return []
                    return [{ label: LabLang.t("cell.reaches"), value: b.vTerm,
                              color: LabTheme.teal },
                            { label: LabLang.t("cell.lost"), value: b.internalDrop,
                              color: b.shorted ? LabTheme.alarm : LabTheme.clay }]
                }
            }
            Text {
                visible: selCard.isBattery && selCard.bat !== null
                width: selCard.width - 20
                wrapMode: Text.WordWrap
                text: {
                    const b = selCard.bat
                    if (!b) return ""
                    if (b.shorted)
                        return LabLang.tf("cell.short", LabLang.num(b.rExt, 2))
                    if (b.overloaded)
                        return LabLang.tf("cell.heavy", LabLang.num(Math.abs(b.i), 2),
                                          LabLang.num(b.rated, 1))
                    return LabLang.tf("cell.ok", b.rExt > 9999 ? LabLang.t("cell.open")
                        : LabLang.num(b.rExt, b.rExt < 100 ? 1 : 0) + " Ω")
                }
                color: selCard.bat && selCard.bat.shorted ? LabTheme.alarm
                     : selCard.bat && selCard.bat.overloaded ? LabTheme.accent
                     : LabTheme.inkFaint
                font.pixelSize: 12
                font.family: LabTheme.handFont
            }
            // Monitoring is a per-part act, like selecting: this puts the part
            // on the plot in the colour it then wears on the board.
            Rectangle {
                id: watchChip
                visible: selCard.el !== null && selCard.el.type !== "junction"
                width: watchLabel.width + 16
                height: visible ? 21 : 0
                radius: LabTheme.radius
                readonly property bool watched:
                    selCard.el !== null && root.isWatched(selCard.el.id)
                readonly property bool full:
                    !watched && root.watch.length >= root.watchMax
                color: watched ? root.watchColorOf(selCard.el.id) : LabTheme.panel
                border.color: watched ? LabTheme.panelEdge
                            : (full ? LabTheme.panelEdge : LabTheme.secondary)
                border.width: LabTheme.borderWidth
                Text {
                    id: watchLabel
                    anchors.centerIn: parent
                    text: LabLang.t(watchChip.watched ? "card.watched"
                        : (watchChip.full ? "card.watch.full" : "card.watch"))
                    color: watchChip.watched ? LabTheme.paper
                         : (watchChip.full ? LabTheme.inkFaint : LabTheme.secondary)
                    font.pixelSize: 12; font.family: LabTheme.handFont
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !watchChip.full
                    onClicked: if (selCard.el) root.toggleWatch(selCard.el.id)
                }
            }
            Text {
                text: LabLang.t(selCard.isResistor ? "card.hint.resistor"
                     : selCard.isBattery ? "card.hint.battery" : "card.hint.part")
                color: LabTheme.inkFaint; font.pixelSize: 12
                font.family: LabTheme.handFont
            }
        }
    }

    // --- short-circuit banner ---------------------------------------------
    // Two different faults, two different messages. Drawing more current than
    // the cell is rated for is not a short - the old banner cried short at any
    // load above 1.5 A, which taught the wrong lesson.
    Rectangle {
        visible: root.sim.shorted || root.sim.overloaded
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: shortText.width + 40; height: 36; radius: 8
        color: root.sim.shorted ? LabTheme.alarm : LabTheme.highlight
        Text {
            id: shortText
            anchors.centerIn: parent
            text: LabLang.t(root.sim.shorted ? "banner.short" : "banner.heavy")
            color: LabTheme.inkOn(parent.color)
            font.pixelSize: 14; font.bold: true
        }
        SequentialAnimation on opacity {
            running: root.sim.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
            NumberAnimation { to: 0.55; duration: 300 }
            NumberAnimation { to: 1.0; duration: 300 }
        }
    }

    // --- hint bar ----------------------------------------------------------
    HintBar {
        flow: ledFlow                 // the narrator owns this slot while it runs
        rightGuard: monitor
        text: {
            if (root.eraser) return LabLang.t("hint.eraser")
            if (root.wiringFrom) return LabLang.t("hint.wiring")
            if (root.selectedId !== -1)
                return LabLang.t("hint.selected")
                + LabLang.t(grid.snap ? "hint.selected.snap"
                                      : "hint.selected.free")
                + LabLang.t("hint.selected.frame")
            return LabLang.t("hint.idle")
        }
    }

    // --- monitor -----------------------------------------------------------
    // One quantity at a time: all series share one autoscaled axis, so mixing
    // mA with V would flatten the volts onto the baseline. It is also the
    // better lesson - watch V in series and it divides, watch I in parallel
    // and it splits, on the very same pair of parts.
    WatchMonitor {
        id: monitor
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.margins: 10
        idPrefix: "part"
        quantities: [
            { key: "I", label: "quantity.current", unit: "mA" },
            { key: "V", label: "quantity.voltage", unit: "V" },
            { key: "P", label: "quantity.power", unit: "W" }]
        windowSeconds: 30
        placeholder: LabLang.t("plot.empty")
        valueOf: (id) => root.watchValueOf(id)
        labelOf: (id) => root.partLabel(id)
        // a solder dot has no reading of its own
        canWatch: (id) => {
            const el = root.elemAt(id)
            return el !== null && el.type !== "junction"
        }
        // labels carry ordinals (BULB becomes BULB1 when a second one lands),
        // so the legend has to be rebuilt when the board changes
        revision: root.elemRev + root.elements.length
    }

    // --- keys --------------------------------------------------------------
    // The reserved half of the map (presets, flow transport, view, record,
    // help) belongs to LabKeys; what is listed here is what this lab adds -
    // and declaring a key here is also what documents it in LabHelp.
    LabKeys {
        id: keymap
        lab: root
        camera: rig
        flow: ledFlow
        recorder: recorder
        keys: [
            { key: "C", label: "key.clear", action: () => root.clearBoard() },
            { key: "E", label: "key.eraser", action: () => root.eraser = !root.eraser },
            { key: "V", label: "key.values", action: () => root.showValues = !root.showValues },
            { key: "M", label: "key.plan", action: () => root.showPlan = !root.showPlan },
            { key: "W", label: "key.watch", action: () => {
                if (root.selectedId !== -1) root.toggleWatch(root.selectedId) } },
            { key: "R", label: "key.rotate", action: () => {
                if (root.selectedId !== -1) root.rotateElement(root.selectedId) } },
            { key: "#", label: "key.grid", action: () => grid.toggle() },
            { key: "G", label: "key.grid", hidden: true, action: () => grid.toggle() },
            { key: "Del", label: "key.delete", action: () => {
                if (root.selectedId !== -1) root.removeElement(root.selectedId) } }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: 300
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        // what is left is this lab's own cancel: the flow's Esc has already
        // had its turn inside handle()
        if (ev.key === Qt.Key_Escape) {
            wiringFrom = null; eraser = false; selectedId = -1
        }
    }
}
