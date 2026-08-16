// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../kits/circuit"
import "../kits/circuit/circuit.js" as Circuit
import "../kits/circuit/route.js" as Route
import "../kits/circuit/symbols.js" as Symbols
import "../kits/circuit/strings.js" as CircuitStrings
import "strings.js" as Strings

// Electronics 101 — a school electronics kit on a pegboard: battery,
// switch, resistor, LED, bulb, diode, NPN transistor and meters, wired
// freely by clicking terminals. A DC nodal solver lights things up in real
// time, and the logic presets are gates rather than pictures of gates -
// their truth tables are four more solves of the board in front of you.
//
// Keys are declared once, on the LabKeys below, which is also what generates
// the on-screen list: press ? to see the whole map. The short version:
// 1..9 presets · T the guided flow (there are two - the offered one follows
// the preset) · C clear · E eraser · V values · M schematic · Q plot the
// selected part · # grid mode · R turn · Del · Shift+R record · Esc cancel.
//
// There is no mode. The LEFT BUTTON IS ALWAYS THE BOARD'S: an empty hand wires
// pads, flips a switch, selects and drags a part, and whatever is on the belt
// (H) takes the click instead while it is out. Navigation never competes for
// it - right-drag turns the world about the cursor, a right CLICK puts down
// whatever is in the hand, the middle button drags, the wheel zooms towards
// the cursor, double-click on bare board re-centres there, and holding Space
// pans on the left button for as long as you hold it. Arrows travel,
// Shift+arrows turn, +/- zoom, F frames the selection, 0 resets.
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
    // What the cell actually hands to the parts: its EMF less its own internal
    // drop. iBattery says how hard the cell is working, this says how much of
    // it survives the working - the two halves the BudgetBar draws, and the
    // pair a study needs to show a cell giving out under load.
    Probe {
        name: "vTerm"; unit: "V"
        expr: () => {
            let sum = 0
            const cells = root.sim.batteries || ({})
            for (const el of root.elements)
                if (el.type === "battery" && cells[el.id])
                    sum += cells[el.id].vTerm
            return sum
        }
    }

    // Shift+R writes a scratch run record into the lab's own records/ dir. No
    // command: a frame-driven session cannot be regenerated, and the citable
    // records are the ones a committed driver steps out (see the clay-lab skill).
    DataRecorder {
        id: recorder
        lab: "electronics-101"
        destination: "labs/electronics-101/records/session.labrec"
    }

    // --- monitoring -------------------------------------------------------
    // What the plot shows comes from the board, never from a fixed list: watch
    // a part and it gets a probe, a colour and a curve; delete the part (or
    // click its legend entry) and the curve goes with it. iBattery and power
    // stay as setup-independent globals for the CSV and for agent queries.
    // The mechanism itself lives in the kernel's WatchMonitor now - what stays
    // here is only what a part is worth, and what it is called.
    readonly property alias watch: monitor.watched

    // The monitor under a name the kernel's own widgets can reach. A WatchChip
    // and a WatchMark both declare a property CALLED monitor, which shadows the
    // id inside them - `monitor: monitor` there is a property assigned to
    // itself, and it fails silently as an invisible chip.
    readonly property alias watchMonitor: monitor

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
    // The board grew with the logic presets: an XOR is thirty-odd parts on
    // three rails, and it simply did not fit on the twenty by twelve the
    // one-loop circuits were laid out on.
    readonly property int cols: 28
    readonly property int rows: 16
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
    // --- terminals ---------------------------------------------------------
    // How many pads a part has and where they sit, in the part's OWN frame.
    // Two in a line is the rule; a transistor is the exception - collector and
    // emitter in line like everything else, and the base on the part's near
    // side, so all three stay far enough apart to be clicked. The kit's
    // CircuitElement3D draws the pads from the same numbers.
    function terminalCount(type) {
        return type === "transistor" ? 3 : (type === "gate" ? 5 : 2)
    }

    function terminalLocal(type, ti) {
        if (type === "junction") return Qt.vector2d(0, 0)
        if (type === "transistor")
            return ti === 0 ? Qt.vector2d(-3.5, 0)      // collector
                 : ti === 1 ? Qt.vector2d(0, 3.5)       // base
                            : Qt.vector2d(3.5, 0)       // emitter
        // A gate is a PACKAGE, so it has supply pins like a real chip: the two
        // inputs on the left, the output on the right, and power across the
        // short sides where a board's rails run.
        if (type === "gate")
            return ti === 0 ? Qt.vector2d(0, -4.6)      // VCC
                 : ti === 1 ? Qt.vector2d(-6.0, -2.6)   // A
                 : ti === 2 ? Qt.vector2d(-6.0, 2.6)    // B
                 : ti === 3 ? Qt.vector2d(6.0, 0)       // Y
                            : Qt.vector2d(0, 4.6)       // GND
        return Qt.vector2d(ti === 0 ? -3.5 : 3.5, 0)
    }

    // Which way a lead LEAVES its pad, in world x/z. Read off the pad's own
    // offset from the part's middle - the dominant axis of it - so it is the
    // same single source of truth as the pad positions themselves: a resistor's
    // wire leaves the end of the resistor, a transistor's base lead leaves the
    // base side, and a gate's output leaves the output side. This is what the
    // router turns a straight diagonal into a wire with: without it, an
    // orthogonal path is merely orthogonal, and may still start by crossing the
    // part it belongs to. A solder dot has no side, hence null.
    function terminalDir(elId, ti) {
        elemRev
        const el = elemAt(elId)
        if (!el || el.type === "junction") return null
        const l = terminalLocal(el.type, ti)
        if (Math.abs(l.x) < 1e-6 && Math.abs(l.y) < 1e-6) return null
        let lx = 0, lz = 0
        if (Math.abs(l.x) >= Math.abs(l.y)) lx = Math.sign(l.x)
        else lz = Math.sign(l.y)
        // the same rotation the pad itself gets; rounded because cos(90 deg)
        // is 6e-17 and a lead that is a hair off axis is not on an axis
        const a = (el.rot || 0) * Math.PI / 180
        const c = Math.round(Math.cos(a)), s = Math.round(Math.sin(a))
        return { x: lx * c + lz * s, z: -lx * s + lz * c }
    }

    // How far a part's own footprint reaches, in world units. One place, so the
    // hit test, the keep-out and the kit's bodies cannot disagree.
    function bodyHalf(type) {
        if (type === "gate") return Qt.vector2d(7.0, 5.6)
        if (type === "transistor") return Qt.vector2d(4.6, 4.6)
        return Qt.vector2d(4.6, 3.4)
    }

    function terminalPos(elId, ti) {
        elemRev
        const el = elemAt(elId)
        if (!el) return Qt.vector3d(0, 0, 0)
        // turned by the part's yaw. Qt rotates about y counter-clockwise seen
        // from above, which for a local (x, z) is
        //   x' =  x*cos + z*sin      z' = -x*sin + z*cos
        // The old form only handled points ON the local x axis, which is
        // exactly what a third pad off that axis broke.
        const l = terminalLocal(el.type, ti)
        const a = (el.rot || 0) * Math.PI / 180
        const c = Math.cos(a), s = Math.sin(a)
        return Qt.vector3d(cellX(el.col) + l.x * c + l.y * s, 0.35,
                           cellZ(el.row) - l.x * s + l.y * c)
    }

    // What the solver is handed. Everything it is allowed to read about a part
    // has to be listed here - a field left out does not fail, it silently takes
    // the solver's default, which is how every gate on the board answered AND
    // no matter what its case said.
    function solverElements(switchStates) {
        return elements.map(el => ({
            id: el.id, type: el.type,
            on: (switchStates && switchStates[el.id] !== undefined)
                ? switchStates[el.id] : el.on,
            func: el.func,
            // a battery carries its own volts; the panel slider is a master
            // that moves them all at once
            value: el.type === "battery" ? (el.value || defaultVolts) : el.value
        }))
    }
    function resolve() { sim = Circuit.solve(solverElements(null), wires) }
    function setBatteryVolts(id, v) {
        const el = elemAt(id)
        if (!el || el.type !== "battery") return
        const nv = Math.round(Math.max(1.5, Math.min(12, v)) * 2) / 2
        if (nv === el.value) return
        el.value = nv
        _touch("none")
    }

    // Two pegs of clearance for real parts; junctions are dots and need one.
    // A gate package is nearly three cells wide, so it asks for more - derived
    // from bodyHalf rather than from a second table, or the two drift and parts
    // start overlapping on the board while the keep-out says they do not.
    function keepOut(type) {
        if (type === "junction") return 0.7
        const h = bodyHalf(type)
        return Math.max(h.x, h.y) / cell + 0.7
    }
    function cellFree(col, row, ignoreId, type) {
        for (const el of elements) {
            if (el.id === ignoreId) continue
            const k = (type === "junction" || el.type === "junction")
                    ? 0.7 : Math.max(keepOut(type), keepOut(el.type))
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

    // --- batching ----------------------------------------------------------
    // Every mutation below edits `elements` / `wires` IN PLACE and then says so
    // here. Outside a batch that publishes immediately - a fresh array so QML
    // sees a change, plus a solve - which is what one click wants.
    //
    // Inside a batch it only marks what changed. That is the whole difference
    // between a preset that builds in 36 ms and one that takes 1.7 seconds:
    // reassigning `elements` hands the Repeater3D a new model and it destroys
    // and rebuilds EVERY part (measured: 22 ms at 38 parts, 15 ms for the
    // wires). The XOR preset makes 85 mutations, so it paid that 85 times over
    // and rebuilt roughly 740 parts to end up with 38. The solver was never the
    // problem - all 85 solves together are 85 ms of it.
    property int batchDepth: 0
    property bool _elemsDirty: false
    property bool _wiresDirty: false
    property bool _revDirty: false

    function beginBatch() { ++batchDepth }
    function endBatch() {
        if (batchDepth > 0) --batchDepth
        if (batchDepth === 0) _flush()
    }
    function _touch(what) {
        if (what !== "wires") _elemsDirty = true
        if (what !== "elements") _wiresDirty = true
        _revDirty = true
        if (batchDepth === 0) _flush()
    }
    // A view-only change (a part moved or turned): no re-solve, because
    // geometry is not electricity - but the bindings still have to re-read.
    function _touchView() {
        _revDirty = true
        if (batchDepth === 0) { ++elemRev; _revDirty = false }
    }
    function _flush() {
        if (_elemsDirty) { elements = elements.slice(); _elemsDirty = false }
        if (_wiresDirty) { wires = wires.slice(); _wiresDirty = false }
        if (_revDirty) { ++elemRev; _revDirty = false }
        resolve()
    }

    function addElement(type, col, row) {
        const spot = nearestFreeCell(col === undefined ? 10 : col,
                                     row === undefined ? 6 : row, type)
        if (!spot) return -1
        const el = { id: nextId++, type: type, col: spot.col, row: spot.row, rot: 0,
                     value: type === "resistor" ? 470
                          : (type === "battery" ? defaultVolts : 0), on: false,
                     func: type === "gate" ? "and" : "" }
        elements.push(el)
        _touch("elements")
        return el.id
    }
    // Place and turn in one go. Turning is a user verb (R), so this is the
    // same act a hand performs - and the logic presets need it on nearly every
    // part, because a gate is drawn as vertical branches between two rails.
    // A quarter turn is 90 degrees counter-clockwise seen from above; three of
    // them put terminal 0 at the TOP, which is what a branch fed from the plus
    // rail wants (and, on a transistor, the collector up, the emitter down and
    // the base facing left into the incoming signal).
    function addRotated(type, col, row, quarters) {
        const id = addElement(type, col, row)
        for (let i = 0; i < (quarters || 0); ++i) rotateElement(id)
        return id
    }
    // Resistance by value rather than by step index, for scenarios and flows.
    function setOhms(id, ohms) { setResistanceStep(id, resistorStepOf(ohms)) }
    // A solder dot: wires meet here, so a board is no longer limited to
    // point-to-point links between part terminals. Placed exactly (never
    // snapped), because it lands wherever the wire was clicked.
    function addJunction(col, row) {
        const j = { id: nextId++, type: "junction", col: col, row: row,
                    rot: 0, value: 0, on: false, func: "" }
        elements.push(j)
        _touch("elements")
        return j.id
    }

    // Drops a junction onto an existing wire and splits it in two, which is
    // what makes a branch (and therefore a parallel circuit) buildable.
    function splitWireAt(wireId, wx, wz) {
        let w = null
        for (const x of wires) if (x.id === wireId) w = x
        if (!w) return -1
        // on the DRAWN path, so the dot lands under the cursor and on the wire
        // - projecting onto the straight line between the pads would drop it
        // beside an L-shaped wire rather than on it
        const p = Route.closestOnPath(wireRoutes[w.id] || wirePath(w), wx, wz)
        beginBatch()
        const j = addJunction(p.x / cell + (cols - 1) / 2,
                              p.z / cell + (rows - 1) / 2)
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].id === wireId) wires.splice(i, 1)
        wires.push({ id: nextId++, a: w.a, b: [j, 0] })
        wires.push({ id: nextId++, a: [j, 0], b: w.b })
        _touch("wires")
        endBatch()
        return j
    }

    function removeElement(id) {
        beginBatch()
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].a[0] === id || wires[i].b[0] === id) wires.splice(i, 1)
        for (let i = elements.length - 1; i >= 0; --i)
            if (elements[i].id === id) elements.splice(i, 1)
        if (selectedId === id) selectedId = -1
        // `watch` is a readonly alias onto the monitor's set - a deleted part
        // leaves through the monitor's own API, never by assigning the alias
        monitor.setWatched(id, false)
        _touch("both")
        endBatch()
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
        _touchView()
    }
    // 90 degree steps, kept unbounded so the animation always turns forward
    function rotateElement(id) {
        const el = elemAt(id)
        if (!el) return
        el.rot = (el.rot || 0) + 90
        _touchView()
    }
    function toggleSwitch(id) {
        const el = elemAt(id)
        if (!el || el.type !== "switch") return
        el.on = !el.on
        _touch("none")
    }
    // Which logic function a gate package performs. The same idiom as a
    // resistor's ohms: the part is one thing you place, and what it does is a
    // property you set on it - printed on the package, and the schematic
    // symbol changes with it.
    readonly property var gateFuncs: ["and", "or", "xor", "nand", "nor", "not"]
    function setGateFunc(id, f) {
        const el = elemAt(id)
        if (!el || el.type !== "gate" || gateFuncs.indexOf(f) < 0) return
        if (el.func === f) return
        el.func = f
        _touch("none")
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
        _touch("none")
    }
    function addWire(a, b) {
        if (a[0] === b[0] && a[1] === b[1]) return
        for (const w of wires) {
            const same = (w.a[0] === a[0] && w.a[1] === a[1] && w.b[0] === b[0] && w.b[1] === b[1])
                      || (w.a[0] === b[0] && w.a[1] === b[1] && w.b[0] === a[0] && w.b[1] === a[1])
            if (same) return
        }
        wires.push({ id: nextId++, a: a, b: b })
        _touch("wires")
    }
    function removeWire(id) {
        for (let i = wires.length - 1; i >= 0; --i)
            if (wires[i].id === id) wires.splice(i, 1)
        _touch("wires")
    }
    function clearBoard() {
        elements.length = 0; wires.length = 0
        wiringFrom = null
        selectedId = -1
        setLogic([], [])
        monitor.clear()
        _touch("both")
    }

    // --- the truth table ---------------------------------------------------
    // A gate preset says which switches are its inputs and which part is its
    // output, and the table is then MEASURED rather than stated: for every
    // combination the solver is run again on a copy of this exact board with
    // those switches set, and the answer is whether the output lights. Nothing
    // in the table is written down anywhere - flip a switch, add a resistor,
    // reverse the LED, and the table changes with the board, because it IS the
    // board.
    property var logicInputs: []     // switch element ids, first one on the left
    // The parts whose `on` is the answer, left to right. More than one because
    // an adder has two: a sum and a carry, and they are the same experiment.
    property var logicOutputs: []
    property var logicOutputNames: []   // optional column headings, per output

    function setLogic(inputs, outputs, names) {
        logicInputs = inputs ? inputs.slice() : []
        logicOutputs = outputs === undefined || outputs === null ? []
                     : (Array.isArray(outputs) ? outputs.slice() : [outputs])
        logicOutputNames = names ? names.slice() : []
    }
    readonly property bool hasLogic: logicInputs.length > 0 && logicOutputs.length > 0

    function solveWith(switchStates) {
        return Circuit.solve(solverElements(switchStates), wires)
    }

    function truthTable() {
        if (!hasLogic) return []
        const n = logicInputs.length
        const rows = []
        for (let m = 0; m < (1 << n); ++m) {
            const bits = [], states = ({})
            for (let k = 0; k < n; ++k) {
                const bit = !!(m & (1 << (n - 1 - k)))
                bits.push(bit)
                states[logicInputs[k]] = bit
            }
            const solved = solveWith(states).perElement
            const outs = logicOutputs.map(id => !!(solved[id] && solved[id].on))
            rows.push({ inputs: bits, outs: outs, out: outs[0] })
        }
        return rows
    }
    // A / B / C ... for the inputs; the outputs use whatever the preset named
    // them (SUM, CARRY) and fall back to Y, Z ... when it named nothing.
    function logicInputName(k) { return String.fromCharCode(65 + k) }
    function logicOutputName(k) {
        if (logicOutputNames[k] !== undefined)
            return LabLang.t(logicOutputNames[k])
        return logicOutputs.length === 1 ? LabLang.t("truth.out")
                                         : String.fromCharCode(89 + k)
    }
    // which row of that table the board is standing on right now
    function logicRowIndex() {
        if (!hasLogic) return -1
        let m = 0
        for (let k = 0; k < logicInputs.length; ++k) {
            const el = elemAt(logicInputs[k])
            if (el && el.on) m |= 1 << (logicInputs.length - 1 - k)
        }
        return m
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
            // one applyState, not a pivot write plus a setDistance: the rig
            // eases, so two writes would start two glides and the board would
            // slide sideways while it zoomed out
            rig.applyState({ px: 0, py: 2, pz: 0, distance: rig.maxDistance })
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
    // The camera verbs a flow (or an agent) can call by name. The rig itself
    // is reachable as `rig`; these exist so a flow's action list reads like
    // something a user could have done.
    function orbitBy(dYaw, dPitch) { rig.orbitBy(dYaw, -dPitch) }
    function zoomBy(f) { rig.zoomBy(f) }
    function goToView(name) { return rig.goTo(name) }
    function focusOn(pts, pad) { rig.focusOn(pts, pad) }

    // --- serialization (survives reloads via the viewState convention) ---
    function circuitState() {
        return { elements: elements.map(el => Object.assign({}, el)),
                 wires: wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() })),
                 nextId: nextId,
                 // which parts the gate presets call inputs and output: the
                 // truth table is derived, but WHAT it is a table of is a
                 // choice, and it has to survive a reload with the board
                 logic: { inputs: logicInputs.slice(),
                          outputs: logicOutputs.slice(),
                          names: logicOutputNames.slice() } }
    }
    function loadCircuit(s) {
        elements = s.elements.map(el => Object.assign({ rot: 0, func: "" }, el))
        wires = s.wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() }))
        nextId = s.nextId
        // outputs used to be a single id; a board saved before the half-adder
        // preset existed still has to come back
        if (s.logic)
            setLogic(s.logic.inputs,
                     s.logic.outputs !== undefined ? s.logic.outputs
                     : (s.logic.output !== undefined && s.logic.output !== -1
                        ? [s.logic.output] : []),
                     s.logic.names)
        else setLogic([], [])
        wiringFrom = null
        selectedId = -1
        resolve()
    }

    function viewState() {
        return Object.assign(Lab.viewState(), {
            circuit: circuitState(),
            watch: monitor.watched.slice(), watchQuantity: monitor.quantity,
            lang: LabLang.lang,
            // which palette sections the reader folded away: a fact about the
            // reader and the room, like the theme, so it survives a reload
            sections: Object.assign({}, sectionsOpen),
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
        if (s.sections) sectionsOpen = Object.assign({}, s.sections)
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

        // --- the transistor, and the four gates built out of it -------------
        //
        // Every one of these is drawn the way a schematic is: a plus rail
        // along the top of the board, a ground rail along the bottom, the cell
        // standing between them on the left, and each stage a vertical branch
        // hanging off the rails. Nothing here is scripted - the LED lights
        // because the solver says current is flowing through it, exactly as in
        // the one-loop presets.
        Scenario {
            // One NPN as a switch: a base current a hundred times smaller than
            // the current it lets through. The ammeter is IN the base lead on
            // purpose - that is the whole lesson, and it is a number, not a
            // claim.
            name: "transistor"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([2, 9, 20], 1, 14)
                const bat = root.addRotated("battery", 2, 7, 3)
                root.addWire([bat, 0], [rails.top[2], 0])
                root.addWire([bat, 1], [rails.bot[2], 0])

                const sw = root.addRotated("switch", 9, 4, 3)
                const jb = root.addJunction(9, 7)
                // the pull-down that makes an open switch mean LOW rather than
                // "not connected to anything" - see addLogicInput
                const pd = root.addRotated("resistor", 9, 10, 3)
                root.setOhms(pd, 10000)
                const rb = root.addElement("resistor", 13, 7)
                root.setOhms(rb, 4700)
                // The meter goes AFTER the fork, in the base lead itself.
                // Upstream of it, it reads the base current plus whatever the
                // pull-down is wasting - and then the ratio this preset exists
                // to show comes out wrong by half a milliamp.
                const am = root.addElement("ammeter", 17, 7)
                const q = root.addRotated("transistor", 20, 7, 3)
                root.addWire([rails.top[9], 0], [sw, 0])
                root.addWire([sw, 1], [jb, 0])
                root.addWire([jb, 0], [pd, 0])
                root.addWire([pd, 1], [rails.bot[9], 0])
                root.addWire([jb, 0], [rb, 0])
                root.addWire([rb, 1], [am, 0])
                root.addWire([am, 1], [q, 1])          // into the base

                const led = root.addRotated("led", 20, 2, 3)
                const rl = root.addRotated("resistor", 20, 4, 3)
                root.setOhms(rl, 220)
                root.addWire([rails.top[20], 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [q, 0])          // into the collector
                root.addWire([q, 2], [rails.bot[20], 0])   // emitter to ground

                // the two currents side by side: that ratio IS the transistor
                root.setLogic([sw], led)
                root.watchOnly([am, led])
            }
        }
        Scenario {
            // OR without a single transistor. Two diodes let either switch
            // feed the LED and stop it feeding back out through the other one
            // - which is the only reason the diodes are there, and it can be
            // read straight off the board: the idle branch carries nothing.
            name: "diode-or"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([2, 8, 12, 16], 1, 14)
                const bat = root.addRotated("battery", 2, 7, 3)
                root.addWire([bat, 0], [rails.top[2], 0])
                root.addWire([bat, 1], [rails.bot[2], 0])

                // The same driven inputs the transistor gates use, and they
                // are what makes the diodes matter: a switch that only ever
                // connects to plus leaves its node floating when it is open,
                // and two floating nodes tied together are not two inputs.
                const a = root.addLogicInput(8, 3, 6, 9, rails)
                const b = root.addLogicInput(16, 3, 6, 9, rails)

                const dA = root.addElement("diode", 11, 6)
                const dB = root.addRotated("diode", 13, 6, 2)   // anode facing B
                const jm = root.addJunction(12, 6)
                const led = root.addRotated("led", 12, 9, 3)
                const rl = root.addRotated("resistor", 12, 11, 3)
                root.setOhms(rl, 220)

                root.addWire([a.node, 0], [dA, 0])
                root.addWire([dA, 1], [jm, 0])
                root.addWire([b.node, 0], [dB, 0])
                root.addWire([dB, 1], [jm, 0])
                root.addWire([jm, 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [rails.bot[12], 0])
                root.setLogic([a.sw, b.sw], led)
                root.watchOnly([dA, dB])
            }
        }
        Scenario {
            // AND: the two transistors sit in SERIES, so the current has to
            // get past both of them - the series preset again, with the
            // switches replaced by something a wire can operate.
            name: "logic-and"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([3, 9, 15, 22], 0, 15)
                const bat = root.addRotated("battery", 3, 7, 3)
                root.addWire([bat, 0], [rails.top[3], 0])
                root.addWire([bat, 1], [rails.bot[3], 0])

                const a = root.addLogicInput(9, 4, 8, 11, rails)
                const b = root.addLogicInput(15, 4, 12, 14, rails)

                const led = root.addRotated("led", 22, 2, 3)
                const rl = root.addRotated("resistor", 22, 5, 3)
                root.setOhms(rl, 220)
                const q1 = root.addRotated("transistor", 22, 8, 3)
                const q2 = root.addRotated("transistor", 22, 12, 3)
                root.addWire([rails.top[22], 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [q1, 0])
                root.addWire([q1, 2], [q2, 0])       // emitter into collector
                root.addWire([q2, 2], [rails.bot[22], 0])

                const rbA = root.addElement("resistor", 18, 8)
                const rbB = root.addElement("resistor", 18, 12)
                root.setOhms(rbA, 4700); root.setOhms(rbB, 4700)
                root.addWire([a.node, 0], [rbA, 0]); root.addWire([rbA, 1], [q1, 1])
                root.addWire([b.node, 0], [rbB, 0]); root.addWire([rbB, 1], [q2, 1])

                root.setLogic([a.sw, b.sw], led)
                root.watchOnly([q1, q2])
            }
        }
        Scenario {
            // OR: the same two transistors, now in PARALLEL. One path or the
            // other is enough, which is the parallel preset's lesson with the
            // bulbs swapped for switches made of silicon.
            name: "logic-or"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([3, 9, 14, 20, 25], 0, 15)
                const bat = root.addRotated("battery", 3, 7, 3)
                root.addWire([bat, 0], [rails.top[3], 0])
                root.addWire([bat, 1], [rails.bot[3], 0])

                const a = root.addLogicInput(9, 4, 8, 10, rails)
                const b = root.addLogicInput(14, 7, 11, 13, rails)

                const led = root.addRotated("led", 20, 2, 3)
                const rl = root.addRotated("resistor", 20, 4, 3)
                root.setOhms(rl, 220)
                const jc1 = root.addJunction(20, 5.6)
                const jc2 = root.addJunction(25, 5.6)
                const q1 = root.addRotated("transistor", 20, 8, 3)
                const q2 = root.addRotated("transistor", 25, 11, 3)
                root.addWire([rails.top[20], 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [jc1, 0])
                root.addWire([jc1, 0], [jc2, 0])     // the shared collector rail
                root.addWire([jc1, 0], [q1, 0])
                root.addWire([jc2, 0], [q2, 0])
                root.addWire([q1, 2], [rails.bot[20], 0])
                root.addWire([q2, 2], [rails.bot[25], 0])

                const rbA = root.addElement("resistor", 17, 8)
                const rbB = root.addElement("resistor", 22, 11)
                root.setOhms(rbA, 4700); root.setOhms(rbB, 4700)
                root.addWire([a.node, 0], [rbA, 0]); root.addWire([rbA, 1], [q1, 1])
                root.addWire([b.node, 0], [rbB, 0]); root.addWire([rbB, 1], [q2, 1])

                root.setLogic([a.sw, b.sw], led)
                root.watchOnly([q1, q2])
            }
        }
        Scenario {
            // XOR - exactly one of them. There is no such thing as an XOR
            // part: it is (A or B) AND NOT (A and B), so the board holds the
            // two gates you have just built plus the NAND that vetoes them.
            // Five transistors for one lamp is not a mistake in the drawing;
            // it is what this function costs.
            name: "logic-xor"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([2, 6, 10, 15, 20], 0, 15)
                const bat = root.addRotated("battery", 2, 7, 3)
                root.addWire([bat, 0], [rails.top[2], 0])
                root.addWire([bat, 1], [rails.bot[2], 0])

                // Each input feeds two gates, so it is tapped twice on its way
                // down to the pull-down - one dot per gate, chained.
                const a = root.addLogicInput(6, 2, 5, 10, rails, [7])
                const aLo = a.taps[0]
                const b = root.addLogicInput(10, 2, 9, 13, rails, [11])
                const bLo = b.taps[0]

                // --- the NAND: two in series, pulled up to the rail --------
                const rn = root.addRotated("resistor", 15, 2, 3)
                root.setOhms(rn, 4700)
                const jn = root.addJunction(15, 3.5)
                const qn1 = root.addRotated("transistor", 15, 5, 3)
                const qn2 = root.addRotated("transistor", 15, 9, 3)
                root.addWire([rails.top[15], 0], [rn, 0])
                root.addWire([rn, 1], [jn, 0])
                root.addWire([jn, 0], [qn1, 0])
                root.addWire([qn1, 2], [qn2, 0])
                root.addWire([qn2, 2], [rails.bot[15], 0])
                const rbn1 = root.addElement("resistor", 12, 5)
                const rbn2 = root.addElement("resistor", 12, 9)
                root.setOhms(rbn1, 4700); root.setOhms(rbn2, 4700)
                root.addWire([a.node, 0], [rbn1, 0]); root.addWire([rbn1, 1], [qn1, 1])
                root.addWire([b.node, 0], [rbn2, 0]); root.addWire([rbn2, 1], [qn2, 1])

                // --- the OR pair, and the transistor the NAND vetoes -------
                const led = root.addRotated("led", 20, 2, 3)
                const rl = root.addRotated("resistor", 20, 4, 3)
                root.setOhms(rl, 220)
                const jm1 = root.addJunction(20, 5.5)
                const jm2 = root.addJunction(25, 5.5)
                const q3 = root.addRotated("transistor", 20, 7, 3)
                const q4 = root.addRotated("transistor", 25, 11, 3)
                const je = root.addJunction(23, 9.5)
                const q5 = root.addRotated("transistor", 20, 13, 3)
                root.addWire([rails.top[20], 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [jm1, 0])
                root.addWire([jm1, 0], [jm2, 0])
                root.addWire([jm1, 0], [q3, 0])
                root.addWire([jm2, 0], [q4, 0])
                root.addWire([q3, 2], [je, 0])
                root.addWire([q4, 2], [je, 0])
                root.addWire([je, 0], [q5, 0])
                root.addWire([q5, 2], [rails.bot[20], 0])

                const rb3 = root.addElement("resistor", 16, 7)
                const rb4 = root.addElement("resistor", 21, 11)
                root.setOhms(rb3, 4700); root.setOhms(rb4, 4700)
                root.addWire([aLo, 0], [rb3, 0]); root.addWire([rb3, 1], [q3, 1])
                root.addWire([bLo, 0], [rb4, 0]); root.addWire([rb4, 1], [q4, 1])

                // the NAND's answer, brought down the outside to Q5's base
                const jn2 = root.addJunction(17.5, 3.5)
                const jn3 = root.addJunction(17.5, 13)
                const rbn5 = root.addElement("resistor", 18, 13)
                root.setOhms(rbn5, 4700)
                root.addWire([jn, 0], [jn2, 0])
                root.addWire([jn2, 0], [jn3, 0])
                root.addWire([jn3, 0], [rbn5, 0])
                root.addWire([rbn5, 1], [q5, 1])

                root.setLogic([a.sw, b.sw], led)
                root.watchOnly([q5, led])
            }
        }
        Scenario {
            // The gate as a PACKAGE. One chip, two switches and a lamp - and
            // the function is a property you set on it, so the same board is
            // all six gates in turn and the truth table redraws under your
            // finger. Note the supply pins: unwire VCC and the chip does
            // nothing, because its output swings between the pads it is
            // actually given, not between numbers it invented.
            name: "gates"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([2, 8, 14, 20, 24], 1, 14)
                const bat = root.addRotated("battery", 2, 7, 3)
                root.addWire([bat, 0], [rails.top[2], 0])
                root.addWire([bat, 1], [rails.bot[2], 0])

                const a = root.addLogicInput(8, 3, 6, 9, rails)
                const b = root.addLogicInput(14, 3, 9, 11, rails)

                const g = root.addElement("gate", 20, 7)
                root.setGateFunc(g, "and")
                root.addWire([rails.top[20], 0], [g, 0])     // VCC
                root.addWire([g, 4], [rails.bot[20], 0])     // GND
                root.addWire([a.node, 0], [g, 1])            // A
                root.addWire([b.node, 0], [g, 2])            // B

                const jy = root.addJunction(24, 7)
                const led = root.addRotated("led", 24, 9, 3)
                const rl = root.addRotated("resistor", 24, 11, 3)
                root.setOhms(rl, 220)
                root.addWire([g, 3], [jy, 0])                // Y
                root.addWire([jy, 0], [led, 0])
                root.addWire([led, 1], [rl, 0])
                root.addWire([rl, 1], [rails.bot[24], 0])

                root.setLogic([a.sw, b.sw], led)
                root.watchOnly([led])
            }
        }
        Scenario {
            // A half adder: two gates reading the same two inputs, and two
            // answers. SUM is A xor B, CARRY is A and B - which is binary
            // addition, and the first thing anybody ever built gates FOR.
            name: "half-adder"
            script: () => {
                root.clearBoard()
                const rails = root.addRails([2, 7, 11, 17, 21, 25], 0, 15)
                const bat = root.addRotated("battery", 2, 7, 3)
                root.addWire([bat, 0], [rails.top[2], 0])
                root.addWire([bat, 1], [rails.bot[2], 0])

                // each input feeds both gates, so each is tapped twice
                const a = root.addLogicInput(7, 1, 4, 12, rails, [10])
                const b = root.addLogicInput(11, 1, 6, 13, rails, [11])

                // the two chips, stacked, each with its own run to the rails
                const gs = root.addElement("gate", 17, 5)     // SUM  = A xor B
                const gc = root.addElement("gate", 17, 11)    // CARRY = A and B
                root.setGateFunc(gs, "xor")
                root.setGateFunc(gc, "and")
                root.addWire([rails.top[17], 0], [gs, 0])     // VCC, straight up
                root.addWire([gs, 4], [rails.bot[17] , 0])    // GND, straight down
                const jv = root.addJunction(21, 10.1)
                root.addWire([rails.top[21], 0], [jv, 0])
                root.addWire([jv, 0], [gc, 0])                // VCC for the lower one
                root.addWire([gc, 4], [rails.bot[17], 0])

                root.addWire([a.node, 0], [gs, 1])
                root.addWire([b.node, 0], [gs, 2])
                root.addWire([a.taps[0], 0], [gc, 1])
                root.addWire([b.taps[0], 0], [gc, 2])

                const ledS = root.addRotated("led", 25, 3, 3)
                const rlS = root.addRotated("resistor", 25, 6, 3)
                const ledC = root.addRotated("led", 25, 10, 3)
                const rlC = root.addRotated("resistor", 25, 13, 3)
                root.setOhms(rlS, 220); root.setOhms(rlC, 220)
                root.addWire([gs, 3], [ledS, 0])
                root.addWire([ledS, 1], [rlS, 0])
                root.addWire([rlS, 1], [rails.bot[25], 0])
                root.addWire([gc, 3], [ledC, 0])
                root.addWire([ledC, 1], [rlC, 0])
                root.addWire([rlC, 1], [rails.bot[25], 0])

                root.setLogic([a.sw, b.sw], [ledS, ledC],
                              ["truth.sum", "truth.carry"])
                root.watchOnly([ledS, ledC])
            }
        }
    }

    // --- shared wiring idioms ----------------------------------------------
    // A plus rail across the top of the board and a ground rail across the
    // bottom, as chains of solder dots at the given columns. Every logic
    // preset is drawn on these two, which is the only reason five gates can
    // sit on one board and still be followed with a finger.
    function addRails(columns, topRow, botRow) {
        const top = ({}), bot = ({})
        let pt = -1, pb = -1
        for (const c of columns) {
            const jt = addJunction(c, topRow), jb = addJunction(c, botRow)
            top[c] = jt; bot[c] = jb
            if (pt !== -1) { addWire([pt, 0], [jt, 0]); addWire([pb, 0], [jb, 0]) }
            pt = jt; pb = jb
        }
        return { top: top, bot: bot }
    }

    // One logic input: a switch from the plus rail down to a node, and a
    // 10 kOhm pull-down from that node to ground. The pull-down is not
    // decoration - without it an open switch leaves the node FLOATING, which
    // is not the same thing as low, and a gate fed from a floating wire is the
    // classic beginner's fault.
    // `taps` are extra rows on the way down where the same signal is picked up
    // again - one solder dot per gate it feeds, chained, so a second consumer
    // never means a second wire drawn along the first one.
    function addLogicInput(col, swRow, nodeRow, pdRow, rails, taps) {
        const sw = addRotated("switch", col, swRow, 3)
        const node = addJunction(col, nodeRow)
        addWire([rails.top[col], 0], [sw, 0])
        addWire([sw, 1], [node, 0])
        let last = node
        const extra = []
        for (const r of (taps || [])) {
            const j = addJunction(col, r)
            addWire([last, 0], [j, 0])
            extra.push(j)
            last = j
        }
        const pd = addRotated("resistor", col, pdRow, 3)
        setOhms(pd, 10000)
        addWire([last, 0], [pd, 0])
        addWire([pd, 1], [rails.bot[col], 0])
        return { sw: sw, node: node, taps: extra, pullDown: pd }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        // One batch around the whole script: a preset is dozens of mutations
        // that nobody watches happen, so the view is published once at the end
        // rather than after each one.
        beginBatch()
        let r
        try { r = scenarioSet.apply(n) } finally { endBatch() }
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
            "frame":      (what) => what === "selection" ? frameSelection() : frameSetup(),
            "view":       (name) => rig.goTo(name),
            // set every declared logic input at once, as a bit pattern: 0b10
            // is "A on, B off". One verb for "put the gate in this row".
            "setInputs":  (mask) => setLogicInputs(mask),
            // what the first (or n-th) package on the board does
            "gateFunc":   (f, n) => {
                const gs = elements.filter(e => e.type === "gate")
                const g = gs[n === undefined ? 0 : n]
                if (g) setGateFunc(g.id, f)
            }
        }
    }
    function setLogicInputs(mask) {
        for (let k = 0; k < logicInputs.length; ++k) {
            const want = !!(mask & (1 << (logicInputs.length - 1 - k)))
            const el = elemAt(logicInputs[k])
            if (el && el.type === "switch" && el.on !== want) toggleSwitch(el.id)
        }
    }
    function flows() { return [ledFlow.flowId, logicFlow.flowId] }
    function startFlow(id) {
        if (id === ledFlow.flowId) { ledFlow.start(); return true }
        if (id === logicFlow.flowId) { logicFlow.start(); return true }
        return false
    }
    // Which lesson `T` and the chip offer. Two flows, one key: a lab with a
    // switch to choose between them would be asking the learner to pick a
    // lesson before they know what either is - so the offer follows the board
    // instead, and whichever flow is running always wins.
    readonly property var currentFlow: {
        if (logicFlow.running) return logicFlow
        if (ledFlow.running) return ledFlow
        const s = Lab.scenario
        return (s === "transistor" || s === "diode-or" || s === "gates"
                || s === "half-adder" || s.indexOf("logic-") === 0)
               ? logicFlow : ledFlow
    }

    function labInfo() {
        const info = Lab.labInfo()
        const byType = {}
        for (const el of elements) byType[el.type] = (byType[el.type] || 0) + 1
        info.circuit = { elements: byType, wires: wires.length,
                         nets: sim.netCount || 0, shorted: sim.shorted,
                         overloaded: sim.overloaded, iterations: sim.iterations }
        // the gate's answer, measured, so an agent can check what the lab
        // teaches without reading a single pixel
        if (hasLogic)
            info.logic = { inputs: logicInputs.slice(),
                           outputs: logicOutputs.slice(),
                           row: logicRowIndex(),
                           table: truthTable().map(r => ({ inputs: r.inputs,
                                                           outs: r.outs })) }
        // language-neutral for agents: types and ids, not display labels
        const f = currentFlow
        info.flow = { id: f.running ? f.flowId : "",
                      offered: f.flowId,
                      step: f.index, paused: f.paused, waiting: f.waiting }
        info.ui = { selected: selectedId, snap: grid.snap,
                    watching: watch.map(id => ({ id: id, type: elemAt(id).type })),
                    quantity: monitor.quantity, lang: LabLang.lang }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- interaction state ------------------------------------------------
    // Grid mode follows grafli's contract: # cycles it, Alt inverts it for one
    // drag, and the pegs show which mode is on (crosses while snapping, dots
    // when free). GridMode itself draws nothing - the stage does, from here.
    GridMode { id: grid; step: root.cell }

    property var wiringFrom: null       // {el, ti} while a wire is dangling
    property bool eraser: false
    property var hoverHit: null         // last hit under the cursor
    property var cursorW: Qt.vector3d(0, 1.9, 0)
    property int selectedId: -1         // -1 = nothing selected
    property bool showValues: false     // V: label every part and every wire
    property bool showPlan: true        // M: the schematic minimap

    // world-space hit test against the data model (no per-model picking)
    function hitAt(wx, wz) {
        // terminals first (they sit inside the element radius)
        for (const el of elements)
            for (let ti = 0; ti < terminalCount(el.type); ++ti) {
                const p = terminalPos(el.id, ti)
                if (Math.hypot(p.x - wx, p.z - wz) < 2.3)
                    return { kind: "terminal", el: el.id, ti: ti }
            }
        for (const el of elements) {
            const x = cellX(el.col), z = cellZ(el.row)
            if (el.type === "junction") continue   // handled as a terminal
            // body box turned by the part's yaw -> axis-aligned bound of it
            const h = bodyHalf(el.type)
            const a = (el.rot || 0) * Math.PI / 180
            const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a))
            if (Math.abs(x - wx) < h.x * c + h.y * s
                && Math.abs(z - wz) < h.x * s + h.y * c)
                return { kind: "element", el: el.id, type: el.type }
        }
        // wires lie flat on the board, so the distance to the DRAWN path is
        // all it takes to grab one anywhere along its length. It has to be the
        // drawn path and not the straight line between the pads, or a click
        // would land on a wire that is no longer there.
        for (const w of wires) {
            if (Route.closestOnPath(wireRoutes[w.id] || [], wx, wz).dist < 1.3)
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
    // The top of the stage's overlay budget: as high as a marking may sit and
    // still belong to the paper rather than float above it.
    readonly property real wireY: stage.overlayMaxY

    // --- routing -------------------------------------------------------------
    // A wire is not the straight line between two pads any more. It leaves each
    // pad on that pad's own side and then turns at right angles, the way a
    // wire on a real board and a line on a real diagram both do - the kit's
    // route.js does the choosing, this only tells it what the board looks like.
    //
    // Routing is GEOMETRY, so it is recomputed when the board moves and never
    // when the currents change: `elemRev` is bumped by every mutation and by
    // every move, `sim` is not listed on purpose. Getting that wrong would put
    // a search over candidate paths inside the solve loop.
    //
    // Every wire on the board is routed in one call rather than one at a time,
    // because a wire has to know which lanes are already taken - two wires that
    // change lane in the same column hide under one another and read as one.
    readonly property var wireRoutes: {
        elemRev
        const obstacles = []
        for (const el of elements) {
            if (el.type === "junction") continue
            const h = bodyHalf(el.type)
            const a = (el.rot || 0) * Math.PI / 180
            const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a))
            obstacles.push({ id: el.id, x: cellX(el.col), z: cellZ(el.row),
                             hx: h.x * c + h.y * s, hz: h.x * s + h.y * c })
        }
        const links = wires.map(w => {
            const pa = terminalPos(w.a[0], w.a[1])
            const pb = terminalPos(w.b[0], w.b[1])
            return { id: w.id,
                     a: { x: pa.x, z: pa.z, dir: terminalDir(w.a[0], w.a[1]) },
                     b: { x: pb.x, z: pb.z, dir: terminalDir(w.b[0], w.b[1]) },
                     ends: [w.a[0], w.b[0]] }
        })
        // half a peg: the lane a route turns in lands on the same raster the
        // parts stand on, so the corners line up with the board instead of
        // falling wherever the arithmetic put them
        return Route.routeAll(links, obstacles, cell / 2)
    }

    // The drawn path of one wire, in world space. Falls back to the straight
    // line, so a wire asked about before the routes are rebuilt still draws.
    function wirePath(w) {
        const p = wireRoutes[w.id]
        if (p && p.length > 1)
            return p.map(q => Qt.vector3d(q.x, wireY, q.z))
        const a = terminalPos(w.a[0], w.a[1])
        const b = terminalPos(w.b[0], w.b[1])
        return [Qt.vector3d(a.x, wireY, a.z), Qt.vector3d(b.x, wireY, b.z)]
    }

    // Half the wire's LENGTH along it - where a reading belongs. The mean of
    // the two ends stopped being on the wire the moment wires grew corners.
    function wireMid(w) {
        const p = wireRoutes[w.id]
        if (p && p.length > 1) {
            const m = Route.midOfPath(p)
            return Qt.vector3d(m.x, wireY, m.z)
        }
        const e = wirePath(w)
        return Qt.vector3d((e[0].x + e[1].x) / 2, wireY, (e[0].z + e[1].z) / 2)
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
            const pts = wirePath(w)
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
            // current simply draws the overlay the other way round. The dash
            // phase runs continuously along a polyline (LineBatch3D packs the
            // accumulated path distance per segment), so the chevrons march
            // round the corners instead of restarting at each one.
            const flow = amps < 0 ? pts.slice().reverse() : pts
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

        // The whole stage - ground, light rig, environment - in one block. The
        // pegboard is the shared lab surface: an endless sheet of squared paper
        // whose raster is drawn in the fragment shader, so the pegs are crosses
        // while the grid snaps and dots when placement is free without a single
        // Model per peg. Everything on the board maps through it (see worldAt).
        LabStage3D {
            id: stage
            cellSize: root.cell
            majorEvery: 4                 // a heavier rule every four pegs
            // 20 columns of 5 puts the pegs on the half-cells, not on the
            // origin - the crosses have to land where the parts do
            rasterOrigin: Qt.vector2d(root.cellX(0), root.cellZ(0))
            gridMode: grid
            workExtent: Qt.vector2d(root.cols * root.cell, root.rows * root.cell)
            shadowMapFar: 250             // measured: covers the board at maxDistance 170
        }
        CameraAnchorMark { pointer: nav }
        // The tape measure, in the same screen space and for the same reason:
        // it answers "how far apart are those pads" without disturbing the
        // board, and it never clips into a part. The kit's own Voltmeter rides
        // with it: a part carries a pick volume now, so a click names the part
        // and a probe left clipped on keeps reading it.
        InstrumentBelt {
            id: hands
            pointer: nav
            Voltmeter {}

            // The palette's parts, as ONE tool that carries which part it is
            // about to place. A build tool is an instrument whose reading is
            // an act: it takes a place, and instead of remembering it, it puts
            // something there. That is the whole of "build is not a mode".
            HandheldInstrument {
                id: placer
                name: "place"
                label: LabLang.t("part." + partType)
                glyph: "✎"
                pickKind: "point"
                maxPicks: 1
                tone: LabTheme.secondary
                hint: "hint.placing"

                property string partType: "resistor"

                // where the part would land, as board cells - null off-board
                readonly property var spot: {
                    if (!hovering || !hovering.point) return null
                    const p = hovering.point
                    const col = p.x / root.cell + (root.cols - 1) / 2
                    const row = p.z / root.cell + (root.rows - 1) / 2
                    if (col < -0.5 || col > root.cols - 0.5
                        || row < -0.5 || row > root.rows - 0.5) return null
                    return { col: Math.round(col), row: Math.round(row) }
                }
                readonly property bool free: spot !== null
                                             && root.cellFree(spot.col, spot.row, -1, partType)

                // A click PLACES rather than accumulating: the pick is the
                // instruction, not the subject. Refused where the cell is
                // taken - and the ghost said so before the click.
                function add(pick) {
                    if (!spot || !free) return
                    root.addElement(partType, spot.col, spot.row)
                }
            }
        }
        environment: stage.environment

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
            smoothMs: 140         // the rig's own easing now, on all four axes
            // The pan leash. The board is 100 x 60 and the ground around it is
            // endless, so travelling is tethered to a little over the board's
            // own reach - far enough to put any corner in the middle, near
            // enough that the parts never leave the picture.
            homePivot: Qt.vector3d(0, 2, 0)
            panLeash: stage.workRadius * 0.9
            viewpoints: ({
                "board":  { yaw: 0, pitch: 48, distance: 80, px: 0, py: 2, pz: 0 },
                "top":    { yaw: 0, pitch: 84, distance: 120 },
                "eye":    { pitch: 24, distance: 60 }
            })
        }

        // --- the ghost ----------------------------------------------------
        // What the click would do, before it does it. Semi-transparent so it
        // reads as a proposal rather than a part, and tinted when the cell is
        // taken, which is the one refusal a placement can meet.
        CircuitElement3D {
            id: placeGhost
            visible: hands.held === placer && placer.spot !== null
            type: placer.partType
            value: placer.partType === "resistor" ? 470
                 : (placer.partType === "battery" ? root.defaultVolts : 0)
            opacity: placer.free ? 0.45 : 0.3
            position: placer.spot
                      ? Qt.vector3d(root.cellX(placer.spot.col), -0.45,
                                    root.cellZ(placer.spot.row))
                      : Qt.vector3d(0, -1000, 0)
            // the refusal reads as a frame rather than a recolour: the part
            // keeps its own identity while it is being refused
            hovered: placer.free
            selected: placer.spot !== null && !placer.free
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
                // which region a transistor is working in, so five identical
                // black blobs stop looking identical
                mode: {
                    const m = root.simOf(modelData.id).mode
                    return m === undefined ? "" : m
                }
                // which logic a gate package performs, printed on its case
                func: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e && e.func ? e.func : "and"
                }
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

        MultiLine3D {  // dangling wire preview - flat, and routed like the real
                       // thing, so what you see while dragging is the wire you
                       // get when you let go
            visible: root.wiringFrom !== null
            coords: {
                if (!root.wiringFrom) return []
                const a = root.terminalPos(root.wiringFrom.el, root.wiringFrom.ti)
                const b = root.cursorW
                const p = Route.routeOne(
                    { x: a.x, z: a.z,
                      dir: root.terminalDir(root.wiringFrom.el, root.wiringFrom.ti) },
                    { x: b.x, z: b.z, dir: null },
                    [], null, root.cell / 2)
                return [p.map(q => Qt.vector3d(q.x, root.wireY, q.z))]
            }
            color: LabTheme.secondary
            width: 0.4
        }
    }

    // --- navigation --------------------------------------------------------
    // The camera gestures are the kernel's (OrbitInput3D), and so is the rule
    // for which gestures are the camera's. The rule is one sentence: the LEFT
    // button is never the camera's. It is not "not in build mode" or "not over
    // a part" - it is never, in every state this lab can be in, which is what
    // makes the switch below flippable at any moment without a key first.
    // The camera gets the right button, the middle one, the wheel, the arrows,
    // and the left button only while Space is held.
    OrbitInput3D {
        id: nav
        rig: rig
        view: view3d
    }

    // --- mouse interaction ------------------------------------------------
    MouseArea {
        id: boardMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: nav.cursorShape
        property var dragElem: null
        property bool dragged: false
        property var pressW: null
        // Alt inverts the current grid mode for the length of one drag
        function snapping(mods) {
            return grid.snapping(mods)
        }

        function worldAt(mx, my) { return stage.worldAt(view3d, mx, my) }

        // The gesture lives in named functions rather than in the signal
        // handlers, so a flow, a test or an agent can perform the SAME drag a
        // hand does - the inspector can synthesize a click but not a drag, and
        // wiring two pads together is the one thing this lab is for. The
        // handlers below are three one-liners that forward to them.
        function moveAt(mx, my, mods, isDown) {
            if (isDown && nav.active) { nav.move(mx, my); return }
            if (isDown && hands.held) { hands.move(mx, my); return }
            if (!isDown) nav.hoverAt(mx, my)
            const w = worldAt(mx, my)
            if (!w) return
            root.cursorW = Qt.vector3d(w.x, 1.9, w.z)
            if (isDown && dragElem) {
                if (!dragged && pressW && Math.hypot(w.x - pressW.x, w.z - pressW.z) > 1.2)
                    dragged = true
                if (dragged)
                    root.moveElement(dragElem,
                                     w.x / root.cell + (root.cols - 1) / 2,
                                     w.z / root.cell + (root.rows - 1) / 2,
                                     snapping(mods))
            } else {
                root.hoverHit = root.hitAt(w.x, w.z)
            }
        }

        // A click, as one call: press and release with no movement between.
        function clickAt(x, y, mods) {
            pressAt(x, y, Qt.LeftButton, mods || 0)
            releaseAt()
        }
        // Drag a part from one window point to another, in one call.
        function dragFrom(x1, y1, x2, y2, mods) {
            pressAt(x1, y1, Qt.LeftButton, mods || 0)
            moveAt(x2, y2, mods || 0, true)
            releaseAt()
        }

        onWheel: (wheel) => nav.wheel(wheel.angleDelta.y, wheel.x, wheel.y)

        onDoubleClicked: (mouse) => {
            // only over bare board: a double-click on a part belongs to the part
            const w = worldAt(mouse.x, mouse.y)
            if (w && !root.hitAt(w.x, w.z)) nav.recenterAt(mouse.x, mouse.y)
        }

        onPositionChanged: (mouse) => moveAt(mouse.x, mouse.y, mouse.modifiers, pressed)
        onPressed: (mouse) => pressAt(mouse.x, mouse.y, mouse.button, mouse.modifiers)
        onReleased: releaseAt()

        function pressAt(mx, my, button, mods) {
            root.forceActiveFocus()
            nav.cancel()
            // Ask the camera first, and with the default buttons the answer for
            // the left button is always no - so nothing below has to think
            // about the camera again, and nothing below can be starved by it.
            if (nav.begin(mx, my, button, mods) !== "") return
            // Then the hand: an instrument out means the click is the
            // instrument's, and it decides click-versus-drag itself.
            if (hands.held) { hands.press(mx, my); return }
            const w = worldAt(mx, my)
            pressW = w; dragged = false; dragElem = null
            const hit = w ? root.hitAt(w.x, w.z) : null
            // empty board (or off-board): a click there means "nothing"
            if (!hit) {
                root.selectedId = -1
                if (!root.eraser) root.wiringFrom = null
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
            root.currentFlow.takeOver()   // the learner is driving now, not the flow
        }

        function releaseAt() {
            nav.end()          // a flicked drag coasts to a stop from here
            if (hands.release()) return   // the click was the instrument's
            if (dragElem && !dragged) {
                const el = root.elemAt(dragElem)
                if (el && el.type === "switch") root.toggleSwitch(dragElem)
                // a resistor is set with the slider on its selection card
            }
            dragElem = null; dragged = false
        }
    }

    // A right CLICK is "put it down" - the RTS cancel. It empties the hand and
    // drops whatever the board had half-started, in that order, so one press
    // walks back one step. A right DRAG still turns the view and cancels
    // nothing; only the distance travelled tells them apart.
    Connections {
        target: nav
        function onCancelled() {
            if (!hands.empty) { hands.putAway(); return }
            if (root.wiringFrom) { root.wiringFrom = null; return }
            if (root.eraser) { root.eraser = false; return }
            root.selectedId = -1
        }
    }

    // --- palette sections --------------------------------------------------
    // Eleven parts, eleven presets and four tools stopped fitting a laptop
    // screen. Shrinking the type would be the wrong fix - it is the same list
    // either way, only harder to read. So the reader folds away the half they
    // are not using, and what stays open is theirs, which is why it rides in
    // viewState() rather than resetting on every reload.
    property var sectionsOpen: ({ presets: true, parts: true, tools: true })
    function sectionOpen(k) { return sectionsOpen[k] !== false }
    function toggleSection(k) {
        const s = Object.assign({}, sectionsOpen)
        s[k] = !sectionOpen(k)
        sectionsOpen = s
    }

    component PaletteSection: Column {
        id: sec
        property string title: ""
        property string sectionKey: ""
        default property alias content: _inner.data
        readonly property bool open: root.sectionOpen(sectionKey)
        width: LabTheme.px(188)
        spacing: LabTheme.spaceS

        Rectangle {
            width: sec.width
            height: LabTheme.px(20)
            radius: LabTheme.px(4)
            color: _hdr.containsMouse ? LabTheme.paper : "transparent"
            Text {
                x: LabTheme.px(3)
                anchors.verticalCenter: parent.verticalCenter
                width: sec.width - LabTheme.px(6)
                elide: Text.ElideRight
                text: (sec.open ? "▾ " : "▸ ") + sec.title
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontSmall; font.bold: true
                font.letterSpacing: 1.2
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: _hdr
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.toggleSection(sec.sectionKey)
            }
        }
        Column {
            id: _inner
            width: sec.width
            spacing: LabTheme.spaceS
            visible: sec.open
            height: visible ? implicitHeight : 0
        }
    }

    // --- how much page there is -------------------------------------------
    // Turn the text size up and the left column stops fitting. Two answers,
    // both measured rather than switched on the scale: the palette lays its
    // parts and tools two across and drops their one-line hints (captions give
    // way before things you click), and the schematic steps out from under it
    // into the empty middle. On a tall screen at the same scale neither fires.
    readonly property bool compactPalette:
        root.height < LabTheme.px(760)
    readonly property bool planUnderPalette:
        plan.y > palette.y + palette.height + LabTheme.px(16)

    // --- palette ----------------------------------------------------------
    readonly property var partCatalog: [
        { type: "battery", color: "#3e9b92" },
        { type: "switch", color: "#c56c54" },
        { type: "resistor", color: "#d9c9a0" },
        { type: "led", color: "#e05a40" },
        { type: "bulb", color: "#d4ba6a" },
        { type: "diode", color: "#3a3630" },
        { type: "transistor", color: "#2a2724" },
        { type: "gate", color: "#4a4f55" },
        { type: "ammeter", color: "#3f7a57" },
        { type: "voltmeter", color: "#8160a8" }
    ]

    LabPanel {
        id: palette
        // Named so a figure can ask for it by name: a paper wants a picture of
        // "the palette", and a pixel rectangle for it goes wrong the moment the
        // UI scale changes. See clayrender --crop.
        objectName: "palette"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(208)
        title: LabLang.t("lab.title")

        // Bounded and flickable, so nothing in here can ever be off the bottom
        // of the screen. Folding a section is the fast way to make room; this
        // is the guarantee that the slow way always exists.
        Flickable {
            id: paletteScroll
            width: LabTheme.px(188)
            height: Math.min(contentHeight,
                             root.height - palette.y - LabTheme.px(58))
            contentWidth: width
            contentHeight: paletteCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: paletteCol
                width: parent.width
                spacing: LabTheme.spaceS

        PaletteSection {
            title: LabLang.t("section.presets")
            sectionKey: "presets"
            // The presets, clickable and each carrying what it is worth
            // noticing. They used to be reachable only by pressing 1..4, with
            // nothing but the active name on screen - the best material in the
            // lab, hidden.
            ScenarioBar {
                lab: root
                width: LabTheme.px(188)
            }
            // and the offer to be taught, from the first frame
            FlowChip { flow: root.currentFlow }
        }

        PaletteSection {
            title: LabLang.t("section.parts")
            sectionKey: "parts"
        // The parts. Turn the text size up and this list alone is taller than
        // the window, so it reflows into two columns and drops the one-line
        // hints - captions give way before the things you click, and the
        // symbol beside each name still says what the part is.
        Grid {
            id: partGrid
            columns: root.compactPalette ? 2 : 1
            spacing: LabTheme.spaceS
            readonly property real cellW: columns === 1 ? LabTheme.px(188)
                                        : (LabTheme.px(188) - LabTheme.spaceS) / 2
            Repeater {
                model: root.partCatalog
                Rectangle {
                    width: partGrid.cellW
                    height: root.compactPalette ? LabTheme.px(28) : LabTheme.px(40)
                    radius: LabTheme.px(6)
                    color: partArea.containsMouse ? LabTheme.panel : LabTheme.paper
                    border.color: partArea.containsMouse ? LabTheme.secondary : LabTheme.panelEdge
                    Rectangle {  // the part's colour on the board
                        x: LabTheme.px(6); anchors.verticalCenter: parent.verticalCenter
                        width: LabTheme.px(10); height: LabTheme.px(10); radius: LabTheme.px(3)
                        color: modelData.color
                    }
                    // and its schematic symbol: the palette is where a kit can
                    // teach "this lump is that squiggle" for free
                    SymbolIcon {
                        visible: !root.compactPalette
                        x: LabTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                        type: modelData.type
                        ink: LabTheme.inkSoft
                    }
                    Column {
                        x: root.compactPalette ? LabTheme.px(22) : LabTheme.px(60)
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: LabLang.t("part." + modelData.type)
                            width: partGrid.cellW - LabTheme.px(28)
                            elide: Text.ElideRight
                            color: LabTheme.ink; font.pixelSize: LabTheme.fontBody
                            font.bold: true; font.family: LabTheme.monoFont
                        }
                        // bounded: a translated hint is often longer than the
                        // English one and must not run out of the panel
                        Text {
                            visible: !root.compactPalette
                            text: LabLang.t("part." + modelData.type + ".hint")
                            width: LabTheme.px(122); elide: Text.ElideRight
                            color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                            font.family: LabTheme.handFont
                        }
                    }
                    // Clicking a part TAKES it, it does not place it. The
                    // press-here-release-there drag this replaces dropped the
                    // part wherever the release happened to land - including
                    // under the palette panel itself, which is where most of
                    // them ended up. Now the board shows a ghost where it
                    // would go, a click puts it there, and Esc or the right
                    // button puts it back down.
                    MouseArea {
                        id: partArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (hands.held === placer
                                && placer.partType === modelData.type) {
                                hands.putAway()          // clicking it again puts it back
                                return
                            }
                            placer.partType = modelData.type
                            hands.takeNamed("place")
                        }
                    }
                }
            }
        }
        }

        PaletteSection {
            title: LabLang.t("section.tools")
            sectionKey: "tools"
        // The tools. Two across when the column is tight, one when it is not.
        Grid {
            id: toolGrid
            columns: root.compactPalette ? 2 : 1
            spacing: LabTheme.spaceS
            readonly property real cellW: columns === 1 ? LabTheme.px(188)
                                        : (LabTheme.px(188) - LabTheme.spaceS) / 2
            Rectangle {
                width: toolGrid.cellW; height: LabTheme.px(30); radius: LabTheme.px(6)
                color: root.eraser ? LabTheme.clay : LabTheme.paper
                border.color: root.eraser ? LabTheme.alarm : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    width: parent.width - LabTheme.spaceL
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t(root.eraser ? "btn.eraser.on" : "btn.eraser")
                    color: LabTheme.inkOn(parent.color); font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.eraser = !root.eraser }
            }
            Rectangle {
                width: toolGrid.cellW; height: LabTheme.px(30); radius: LabTheme.px(6)
                color: LabTheme.paper
                border.color: root.showValues ? LabTheme.secondary : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    width: parent.width - LabTheme.spaceL
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t(root.showValues ? "btn.values.on" : "btn.values.off")
                    color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.showValues = !root.showValues }
            }
            Rectangle {
                width: toolGrid.cellW; height: LabTheme.px(30); radius: LabTheme.px(6)
                color: LabTheme.paper
                border.color: grid.snap ? LabTheme.secondary : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    width: parent.width - LabTheme.spaceL
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t(grid.snap ? "btn.grid.snap" : "btn.grid.free")
                    color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: grid.toggle() }
            }
            Rectangle {
                width: toolGrid.cellW; height: LabTheme.px(30); radius: LabTheme.px(6)
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    width: parent.width - LabTheme.spaceL
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t("btn.clear")
                    color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearBoard() }
            }
        }
        }
            }

            // Only there when there IS more below: a bar that is always visible
            // teaches nothing, and one that never appears leaves the reader
            // wondering whether the list simply ended. It lives INSIDE the
            // Flickable, so it has to be drawn at contentY to stay put - a
            // child of a Flickable scrolls with the content by definition.
            Rectangle {
                readonly property real over:
                    paletteScroll.contentHeight - paletteScroll.height
                visible: over > 1
                x: paletteScroll.width - width
                y: paletteScroll.contentY
                   + (over > 0 ? paletteScroll.contentY / over : 0)
                     * (paletteScroll.height - height)
                width: LabTheme.px(3)
                height: Math.max(LabTheme.px(24),
                                 paletteScroll.height * paletteScroll.height
                                 / Math.max(1, paletteScroll.contentHeight))
                radius: width / 2
                color: LabTheme.panelEdge
            }
        }
    }

    // --- flow (SPIKE) ------------------------------------------------------
    // "Why does the LED light?" - a demo that builds the circuit, hands the
    // switch to the learner, then explains the number it produced.
    Flow {
        id: ledFlow
        lab: root
        camera: rig                       // so a step may name where to look from
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
    // --- flow: from one transistor to XOR ----------------------------------
    // The second lesson, and the one the new parts are for. It does not build
    // anything by hand: each step jumps to the preset that already holds the
    // circuit and then asks the learner to work its truth table, because what
    // is being taught here is what a gate DOES, not where to click.
    Flow {
        id: logicFlow
        lab: root
        camera: rig
        flowId: "logic-gates"
        titleKey: "flow.logic-gates.title"

        FlowStep {
            key: "meet"
            demo: [["scenario", "transistor"], ["showValues", false],
                   ["setInputs", 0], ["frame", "setup"]]
        }
        FlowStep {
            key: "switch"
            task: ({ "until": () => root.logicRowIndex() === 1,
                     "hint": "flow.logic-gates.switch.hint",
                     "hintAfter": 7,
                     "solve": [["setInputs", 1]] })
        }
        FlowStep {
            key: "gain"
            demo: [["showValues", true]]
        }
        FlowStep {
            key: "and"
            demo: [["scenario", "logic-and"], ["setInputs", 0],
                   ["showValues", false], ["frame", "setup"]]
        }
        FlowStep {
            key: "andtask"
            task: ({ "until": () => root.logicRowIndex() === 3,
                     "hint": "flow.logic-gates.andtask.hint",
                     "hintAfter": 8,
                     "solve": [["setInputs", 3]] })
            // the gate is what the preset claims it is, or this step fails
            expect: () => {
                const t = root.truthTable()
                return t.length === 4 && !t[0].out && !t[1].out && !t[2].out && t[3].out
            }
        }
        FlowStep {
            key: "or"
            demo: [["scenario", "logic-or"], ["setInputs", 1], ["frame", "setup"]]
            expect: () => {
                const t = root.truthTable()
                return t.length === 4 && !t[0].out && t[1].out && t[2].out && t[3].out
            }
        }
        FlowStep {
            key: "xor"
            demo: [["scenario", "logic-xor"], ["setInputs", 0], ["frame", "setup"]]
        }
        FlowStep {
            key: "xortask"
            task: ({ "until": () => { const r = root.logicRowIndex()
                                      return r === 1 || r === 2 },
                     "hint": "flow.logic-gates.xortask.hint",
                     "hintAfter": 8,
                     "solve": [["setInputs", 1]] })
            expect: () => {
                const t = root.truthTable()
                return t.length === 4 && !t[0].out && t[1].out && t[2].out && !t[3].out
            }
        }
        FlowStep {
            key: "both"
            demo: [["setInputs", 3]]
        }
        FlowStep {
            key: "cost"
            demo: [["showValues", false], ["frame", "setup"]]
        }
        // --- and now the same thing as a part ------------------------------
        FlowStep {
            key: "chip"
            demo: [["scenario", "gates"], ["gateFunc", "xor"],
                   ["setInputs", 0], ["frame", "setup"]]
        }
        FlowStep {
            key: "chiptask"
            task: ({ "until": () => { const r = root.logicRowIndex()
                                      return r === 1 || r === 2 },
                     "hint": "flow.logic-gates.chiptask.hint",
                     "hintAfter": 8,
                     "solve": [["setInputs", 1]] })
            // the package answers the same as the five transistors did
            expect: () => {
                const t = root.truthTable()
                return t.length === 4 && !t[0].out && t[1].out && t[2].out && !t[3].out
            }
        }
        FlowStep {
            key: "switchit"
            demo: [["gateFunc", "nand"], ["setInputs", 3]]
            expect: () => {
                const t = root.truthTable()
                return t.length === 4 && t[0].out && t[1].out && t[2].out && !t[3].out
            }
        }
        FlowStep {
            key: "adder"
            demo: [["scenario", "half-adder"], ["setInputs", 3], ["frame", "setup"]]
            expect: () => {
                const t = root.truthTable()
                if (t.length !== 4) return false
                // SUM = A xor B, CARRY = A and B
                const sum = t.map(r => r.outs[0]), carry = t.map(r => r.outs[1])
                return !sum[0] && sum[1] && sum[2] && !sum[3]
                    && !carry[0] && !carry[1] && !carry[2] && carry[3]
            }
        }
    }

    Narrator {
        flow: root.currentFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceXl
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
        anchors.margins: LabTheme.spaceXl
        spacing: LabTheme.spaceM
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ScaleSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }

    // --- compass: which way the board faces while you circle it ------------
    Compass {
        // beside the palette rather than under it: the palette carries the
        // presets and the tour offer now, and the slot below it is the
        // schematic's
        x: palette.x + palette.width + LabTheme.px(10)
        y: LabTheme.px(12)
        yaw: rig.yaw
        aspect: root.cols / root.rows
    }

    // The 2D label that used to follow the cursor while a part was dragged
    // out of the palette is gone with the drag: what the part will look like
    // and exactly where it will land are now shown by the ghost ON THE BOARD,
    // which is the thing the question was actually about.

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
            height: LabTheme.px(24)
            radius: LabTheme.px(12)
            color: LabTheme.panel
            border.color: modelData.type === "ammeter" ? LabTheme.forest : LabTheme.plum
            border.width: Math.max(1, 1.5 * LabTheme.uiScale)
            Text {
                id: readingText
                anchors.centerIn: parent
                text: (modelData.type === "ammeter" ? "A " : "V ") + parent.reading
                color: LabTheme.ink; font.pixelSize: LabTheme.fontLabel; font.bold: true
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
        objectName: "schematic"
        visible: root.showPlan
        // steps out from under the palette when the palette reaches it
        anchors.left: root.planUnderPalette ? parent.left : palette.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: LabTheme.spaceXl
        anchors.bottomMargin: LabTheme.px(44)
        width: LabTheme.px(250)
        height: LabTheme.px(176)
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

                // wires first, so symbols sit on top of their leads. The very
                // path the board draws, mapped into the panel: a diagram whose
                // wires ran diagonally while the board's turned corners would
                // be a diagram of a different board - and right angles are what
                // a circuit diagram is drawn with anyway.
                function traceOf(w) {
                    const r = root.wireRoutes[w.id]
                    if (r && r.length > 1) return r
                    const a = root.terminalPos(w.a[0], w.a[1])
                    const b = root.terminalPos(w.b[0], w.b[1])
                    return [{ x: a.x, z: a.z }, { x: b.x, z: b.z }]
                }
                for (const w of root.wires) {
                    const r = traceOf(w)
                    const i = root.sim.wireCurrent ? root.sim.wireCurrent[w.id] : null
                    const amps = (i === null || i === undefined) ? 0 : Math.abs(i)
                    const hot = amps > root.ratedCurrent
                    ctx.strokeStyle = (hot ? LabTheme.alarm
                                     : amps > 1e-5 ? LabTheme.ink
                                     : LabTheme.inkFaint).toString()
                    ctx.lineWidth = hot ? 2.4 : (amps > 1e-5 ? 1.6 : 1.2)
                    ctx.lineJoin = "round"
                    ctx.beginPath()
                    for (let k = 0; k < r.length; ++k) {
                        const cx = px(r[k].x / root.cell + (root.cols - 1) / 2)
                        const cy = py(r[k].z / root.cell + (root.rows - 1) / 2)
                        if (k === 0) ctx.moveTo(cx, cy); else ctx.lineTo(cx, cy)
                    }
                    ctx.stroke()
                }

                for (const el of root.elements) {
                    const sel = el.id === root.selectedId
                    const hov = root.hoverHit && root.hoverHit.el === el.id
                    const sw = Math.max(22, Math.min(40, fit.s * 1.5))
                    Symbols.draw(ctx, el.type, px(el.col), py(el.row),
                                 sw, sw * Symbols.aspect(el.type), {
                        ink: (sel || hov ? LabTheme.secondary : LabTheme.ink).toString(),
                        lineWidth: sel ? 2.2 : 1.5,
                        rot: el.rot || 0,
                        on: el.type === "switch" ? el.on : false
                    })
                }
            }
        }
    }

    // --- truth table -------------------------------------------------------
    // What the gate on the board actually does, for every combination of its
    // inputs. Not a picture of a table from a textbook: each row is a fresh
    // solve of this exact board with those switches set, so editing the
    // circuit edits the table. The row you are standing on is highlighted, so
    // flipping a switch walks you down it.
    LabPanel {
        id: truth
        objectName: "truthTable"
        visible: root.hasLogic
        anchors.right: parent.right
        anchors.top: topSwitches.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.spaceL
        // wide enough for the columns it actually has: an adder brings a
        // second answer column, and the panel must not elide it
        width: LabTheme.px(96) + truth.colW * (root.logicInputs.length
                                               + root.logicOutputs.length * 1.4)
        title: LabLang.t("truth.title")

        readonly property var rows: {
            root.elemRev; root.sim; root.logicInputs; root.logicOutputs
            return root.truthTable()
        }
        readonly property int liveRow: { root.elemRev; return root.logicRowIndex() }
        readonly property real colW: LabTheme.px(30)
        readonly property real outW: colW + LabTheme.px(14)

        Row {
            spacing: LabTheme.px(3)
            Repeater {
                model: root.logicInputs.length
                Text {
                    required property int index
                    width: truth.colW
                    horizontalAlignment: Text.AlignHCenter
                    text: root.logicInputName(index)
                    color: LabTheme.inkSoft
                    font.pixelSize: LabTheme.fontSmall; font.bold: true
                    font.letterSpacing: 1.0
                    font.family: LabTheme.monoFont
                }
            }
            Repeater {
                model: root.logicOutputs.length
                Text {
                    required property int index
                    width: truth.outW
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.logicOutputName(index)
                    color: LabTheme.primary
                    font.pixelSize: LabTheme.fontSmall; font.bold: true
                    font.letterSpacing: 1.0
                    font.family: LabTheme.monoFont
                }
            }
        }
        Repeater {
            model: truth.rows
            Rectangle {
                id: _row
                required property var modelData
                required property int index
                readonly property bool live: index === truth.liveRow
                // ink follows the fill: the live row is FILLED, and a colour
                // pinned to ink disappears on it
                readonly property color rowInk: LabTheme.inkOn(color)
                width: truth.body.width
                height: LabTheme.px(21)
                radius: LabTheme.px(4)
                color: live ? LabTheme.secondary : LabTheme.panel
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: LabTheme.px(3)
                    Repeater {
                        model: _row.modelData.inputs
                        Text {
                            required property bool modelData
                            width: truth.colW
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData ? "1" : "0"
                            color: _row.rowInk
                            font.pixelSize: LabTheme.fontBody
                            font.family: LabTheme.monoFont
                        }
                    }
                    Repeater {
                        model: _row.modelData.outs
                        Text {
                            required property bool modelData
                            width: truth.outW
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData ? "●" : "○"
                            color: modelData ? LabTheme.accent : _row.rowInk
                            font.pixelSize: LabTheme.fontBody
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
        Text {
            width: truth.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("truth.note")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontBody
            font.family: LabTheme.handFont
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
            height: LabTheme.px(20)
            radius: LabTheme.px(5)
            color: LabTheme.panel
            border.color: LabTheme.panelEdge; border.width: LabTheme.px(1)
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
                color: LabTheme.primary; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
        }
    }
    Repeater {
        model: root.showValues ? root.wires : []
        Text {
            readonly property var screenAt: {
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const m = root.wireMid(modelData)
                return view3d.mapFrom3DScene(Qt.vector3d(m.x, 0.6, m.z))
            }
            visible: root.showValues && screenAt.z > 0
            x: screenAt.x - width / 2
            y: screenAt.y - height / 2
            text: {
                const i = root.sim.wireCurrent ? root.sim.wireCurrent[modelData.id] : null
                if (i === null || i === undefined) return "?"
                return root.fmtA(Math.abs(i))
            }
            color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.family: LabTheme.monoFont
            style: Text.Outline; styleColor: LabTheme.paperDeep
        }
    }

    // --- watch marks -------------------------------------------------------
    // A tag in the curve's own colour, so "which line is which part" is read
    // off the board instead of guessed from the legend order.
    Repeater {
        model: root.watch
        WatchMark {
            readonly property int pid: modelData
            // the projection needs the camera's own scene transform listed, or
            // the binding freezes the moment the rig moves
            readonly property var screenAt: {
                root.elemRev; rig.camera.scenePosition; rig.camera.sceneRotation
                const e = root.elemAt(pid)
                if (!e) return Qt.vector3d(0, 0, 0)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    root.cellX(e.col), 6.0, root.cellZ(e.row)))
            }
            monitor: root.watchMonitor
            target: pid
            label: { root.elemRev; return root.partLabel(pid) }
            visible: screenAt.z > 0 && root.isWatched(pid)
            x: Math.max(2, Math.min(root.width - width - 2, screenAt.x - width / 2))
            // steps aside for the value label when V is on
            y: Math.max(2, Math.min(root.height - height - 2,
                                    screenAt.y - height
                                    - (root.showValues ? LabTheme.px(23) : 0)))
        }
    }

    // --- selection card (what is selected, what it reads, what you can do) -
    LabPanel {
        id: selCard
        objectName: "partCard"
        padding: 10
        spacing: LabTheme.px(1)
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
        width: Math.max(selCol.width + 20,
                        (isResistor || isBattery) ? LabTheme.px(196) : 0,
                        isGate ? LabTheme.px(228) : 0)
        height: selCol.height + 14
        readonly property bool isResistor: el !== null && el.type === "resistor"
        readonly property bool isBattery: el !== null && el.type === "battery"
        readonly property bool isGate: el !== null && el.type === "gate"
        readonly property var bat: {
            root.elemRev; root.sim
            return el && el.type === "battery" ? root.batteryOf(el.id) : null
        }

        Column {
            id: selCol
            spacing: LabTheme.px(1)
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
                    if (e.type === "transistor") {
                        const m = root.simOf(e.id).mode
                        return name + "  " + LabLang.t("npn." + (m === undefined ? "off" : m))
                    }
                    if (e.type === "gate")
                        return LabLang.t("gate." + (e.func || "and")).toUpperCase()
                    return name
                }
                color: LabTheme.primary; font.pixelSize: LabTheme.fontSmall; font.bold: true
                font.letterSpacing: 1.0; font.family: LabTheme.monoFont
            }
            Text {
                text: {
                    root.elemRev
                    if (!selCard.el) return ""
                    const s = root.simOf(selCard.el.id)
                    return root.fmtV(s.v) + "   " + root.fmtA(s.i)
                }
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            // The transistor's own account of itself. Its v/i line above is
            // the collector-emitter pair, which is what every other readout in
            // the lab shows for it; what only this card can add is the tiny
            // current on the third leg, and the ratio between the two - which
            // is the entire reason the part exists.
            Text {
                visible: selCard.el !== null && selCard.el.type === "transistor"
                text: {
                    root.elemRev; root.sim
                    if (!selCard.el || selCard.el.type !== "transistor") return ""
                    const s = root.simOf(selCard.el.id)
                    const gain = Math.abs(s.ib) > 1e-9
                                 ? LabLang.num(Math.abs(s.ic / s.ib), 0) : "—"
                    return "Ib " + root.fmtA(s.ib) + "   Ic " + root.fmtA(s.ic)
                         + "   ×" + gain
                }
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            // Which logic the selected package performs. Same idiom as the
            // resistor's slider: you place one part and then say what it is,
            // and the case, the schematic symbol and the truth table all
            // follow. Changing it re-solves, so the table redraws under your
            // finger - which is the fastest way there is to learn what six
            // gates actually do.
            // A Grid and not a Flow: `Flow` in this file is the LAB's Flow -
            // the narrated walkthrough - because Clayground.Lab is imported
            // after QtQuick and wins the name. Three across, two rows.
            Grid {
                id: funcGrid
                visible: selCard.el !== null && selCard.el.type === "gate"
                width: selCard.width - 20
                height: visible ? implicitHeight : 0
                columns: 3
                spacing: LabTheme.px(3)
                readonly property real cellW:
                    (selCard.width - 20 - 2 * LabTheme.px(3)) / 3
                Repeater {
                    model: root.gateFuncs
                    Rectangle {
                        required property string modelData
                        readonly property bool active:
                            selCard.el !== null && selCard.el.func === modelData
                        width: funcGrid.cellW
                        height: LabTheme.px(20)
                        radius: LabTheme.px(4)
                        color: active ? LabTheme.secondary : LabTheme.paper
                        border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                        border.width: LabTheme.borderWidth
                        Text {
                            id: _fn
                            anchors.centerIn: parent
                            text: LabLang.t("gate." + modelData).toUpperCase()
                            color: LabTheme.inkOn(parent.color)
                            font.pixelSize: LabTheme.fontSmall; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (selCard.el)
                                           root.setGateFunc(selCard.el.id, modelData)
                        }
                    }
                }
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
                    width: parent.width; height: LabTheme.px(16)
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
                        width: parent.width; height: LabTheme.px(4); radius: LabTheme.px(2)
                        color: LabTheme.panelEdge
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: rSlider.ratio * parent.width
                        height: LabTheme.px(4); radius: LabTheme.px(2)
                        color: LabTheme.secondary
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: rSlider.ratio * (parent.width - width)
                        width: LabTheme.px(12); height: LabTheme.px(12); radius: LabTheme.px(6)
                        color: LabTheme.panel
                        border.color: LabTheme.ink; border.width: LabTheme.px(2)
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
                font.pixelSize: LabTheme.fontBody
                font.family: LabTheme.handFont
            }
            // Monitoring is a per-part act, like selecting: this puts the part
            // on the plot in the colour it then wears on the board. The chip
            // is the kernel's - it reads the series limit off the monitor
            // itself, so this card can no longer disagree with the plot about
            // whether there is a colour left - and a junction hides it by
            // having no target rather than by a second visibility rule.
            WatchChip {
                monitor: root.watchMonitor
                target: selCard.el !== null && selCard.el.type !== "junction"
                        ? selCard.el.id : undefined
                labels: ({ add: "card.watch", on: "card.watched",
                           full: "card.watch.full" })
            }
            Text {
                text: LabLang.t(selCard.isResistor ? "card.hint.resistor"
                     : selCard.isBattery ? "card.hint.battery" : "card.hint.part")
                color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                font.family: LabTheme.handFont
            }
        }
    }

    // --- short-circuit banner ---------------------------------------------
    // Two different faults, two different messages. Drawing more current than
    // the cell is rated for is not a short - the old banner cried short at any
    // load above 1.5 A, which taught the wrong lesson. Only the short blinks:
    // a banner that always pulses stops meaning anything.
    LabBanner {
        active: root.sim.shorted || root.sim.overloaded
        alarm: root.sim.shorted
        blink: root.sim.shorted
        guard: palette                // never grows in under the parts list
        maxWidth: LabTheme.px(560)    // both messages are a whole sentence
        text: LabLang.t(root.sim.shorted ? "banner.short" : "banner.heavy")
    }

    // The clock, on screen: this lab's solver runs continuously and its plot
    // is a time series, so "how long has that LED been at 40 mA" was a
    // question the page could not answer.
    TransportChip {
        id: transport
        clock: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // under the banner's slot, not in it: a short circuit outranks the
        // clock for the top line of the page
        anchors.topMargin: LabTheme.px(58)
    }

    // --- hint bar ----------------------------------------------------------
    HintBar {
        id: hintBar
        flow: root.currentFlow        // the narrator owns this slot while it runs
        rightGuard: monitor
        text: {
            // the hand outranks everything: while an instrument is out, a hint
            // about clicking pads describes something you are not doing
            if (!hands.empty) return LabLang.t(hands.held.hint)
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
        anchors.margins: LabTheme.px(10)
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
        pointer: nav
        hands: hands
        flow: root.currentFlow
        recorder: recorder
        keys: [
            { key: "C", label: "key.clear", action: () => root.clearBoard() },
            { key: "E", label: "key.eraser", action: () => root.eraser = !root.eraser },
            { key: "V", label: "key.values", action: () => root.showValues = !root.showValues },
            { key: "M", label: "key.plan", action: () => root.showPlan = !root.showPlan },
            { key: "Q", label: "key.watch", action: () => {
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
        width: LabTheme.px(300)
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        // what is left is this lab's own cancel: the flow's Esc has already
        // had its turn inside handle()
        if (ev.key === Qt.Key_Escape) {
            wiringFrom = null; eraser = false; selectedId = -1
        }
    }
    // the other half of the Space quasimode: without it the hand stays down
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
