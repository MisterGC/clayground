// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "../kits/circuit"
import "../kits/circuit/circuit.js" as Circuit

// Electronics 101 — a school electronics kit on a pegboard: battery,
// switch, resistor, LED, bulb and meters, wired freely by clicking
// terminals. A DC nodal solver lights things up in real time.
// Keys: 1 led-basic · 2 series · 3 parallel · 4 metering · C clear ·
// E eraser · Esc cancel · R record.
Item {
    id: root
    anchors.fill: parent
    focus: true
    Component.onCompleted: { forceActiveFocus(); applyScenario("led-basic") }

    // --- parameters / clock / probes ------------------------------------
    Parameter { id: pBatteryV; name: "batteryV"; value: 4.5; from: 1.5; to: 12; unit: "V" }

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
        name: "iLed"; unit: "mA"
        expr: () => {
            for (const el of root.elements)
                if (el.type === "led") return root.simOf(el.id).i * 1000
            return 0
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

    // --- circuit state ---------------------------------------------------
    // elements: {id, type, col, row, value, on} - wires: {id, a:[el,ti], b:[el,ti]}
    property var elements: []
    property var wires: []
    property int nextId: 1
    property var sim: ({ ok: true, perElement: {}, shorted: false, iterations: 0 })
    property int elemRev: 0          // bumped on moves so positions rebind

    readonly property int cols: 10
    readonly property int rows: 6
    readonly property real cell: 10

    function cellX(col) { return (col - (cols - 1) / 2) * cell }
    function cellZ(row) { return (row - (rows - 1) / 2) * cell }
    function elemAt(id) {
        for (const el of elements) if (el.id === id) return el
        return null
    }
    function simOf(id) {
        const e = sim.perElement[id]
        return e ? e : { v: 0, i: 0, on: false, power: 0 }
    }
    function terminalPos(elId, ti) {
        elemRev
        const el = elemAt(elId)
        if (!el) return Qt.vector3d(0, 0, 0)
        return Qt.vector3d(cellX(el.col) + (ti === 0 ? -3.5 : 3.5), 1.9, cellZ(el.row))
    }

    function resolve() {
        const els = elements.map(el => ({
            id: el.id, type: el.type, on: el.on,
            value: el.type === "battery" ? pBatteryV.value : el.value
        }))
        sim = Circuit.solve(els, wires)
    }
    Connections { target: pBatteryV; function onValueChanged() { root.resolve() } }

    function cellFree(col, row, ignoreId) {
        for (const el of elements)
            if (el.id !== ignoreId && el.col === col && el.row === row) return false
        return true
    }
    function nearestFreeCell(col, row) {
        col = Math.max(0, Math.min(cols - 1, Math.round(col)))
        row = Math.max(0, Math.min(rows - 1, Math.round(row)))
        for (let radius = 0; radius < cols; ++radius)
            for (let dr = -radius; dr <= radius; ++dr)
                for (let dc = -radius; dc <= radius; ++dc) {
                    const c = col + dc, r = row + dr
                    if (c < 0 || c >= cols || r < 0 || r >= rows) continue
                    if (cellFree(c, r, -1)) return { col: c, row: r }
                }
        return null
    }

    function addElement(type, col, row) {
        const spot = nearestFreeCell(col === undefined ? 5 : col,
                                     row === undefined ? 3 : row)
        if (!spot) return -1
        const el = { id: nextId++, type: type, col: spot.col, row: spot.row,
                     value: type === "resistor" ? 470 : 0, on: false }
        elements = elements.concat([el])
        resolve()
        return el.id
    }
    function removeElement(id) {
        wires = wires.filter(w => w.a[0] !== id && w.b[0] !== id)
        elements = elements.filter(el => el.id !== id)
        resolve()
    }
    function moveElement(id, col, row) {
        const el = elemAt(id)
        if (!el) return
        col = Math.max(0, Math.min(cols - 1, Math.round(col)))
        row = Math.max(0, Math.min(rows - 1, Math.round(row)))
        if (!cellFree(col, row, id)) return
        el.col = col; el.row = row
        elemRev++
    }
    function toggleSwitch(id) {
        const el = elemAt(id)
        if (!el || el.type !== "switch") return
        el.on = !el.on
        elemRev++
        resolve()
    }
    function cycleResistor(id) {
        const el = elemAt(id)
        if (!el || el.type !== "resistor") return
        const steps = [100, 220, 470, 1000]
        el.value = steps[(steps.indexOf(el.value) + 1) % steps.length]
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
        resolve()
    }

    // --- serialization (survives reloads via the viewState convention) ---
    function circuitState() {
        return { elements: elements.map(el => Object.assign({}, el)),
                 wires: wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() })),
                 nextId: nextId }
    }
    function loadCircuit(s) {
        elements = s.elements.map(el => Object.assign({}, el))
        wires = s.wires.map(w => ({ id: w.id, a: w.a.slice(), b: w.b.slice() }))
        nextId = s.nextId
        wiringFrom = null
        resolve()
    }

    function viewState() {
        return Object.assign(Lab.viewState(), { circuit: circuitState() })
    }
    // The user's board wins over the scenario preset: with a circuit payload
    // the scenario is NOT re-applied, the exact board comes back instead.
    function applyViewState(s) {
        if (s.circuit) loadCircuit(s.circuit)
        else if (s.scenario) applyScenario(s.scenario)
        Lab.applyViewState(s)
    }

    // --- scenarios --------------------------------------------------------
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "led-basic"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 3, 1)
                const sw = root.addElement("switch", 6, 1)
                const res = root.addElement("resistor", 3, 4)
                const led = root.addElement("led", 6, 4)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [led, 1])
                root.addWire([led, 0], [res, 1])
                root.addWire([res, 0], [bat, 0])
            }
        }
        Scenario {
            name: "series"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 2, 1)
                const sw = root.addElement("switch", 5, 1)
                const b1 = root.addElement("bulb", 8, 1)
                const b2 = root.addElement("bulb", 8, 4)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [b1, 0])
                root.addWire([b1, 1], [b2, 1])
                root.addWire([b2, 0], [bat, 0])
            }
        }
        Scenario {
            name: "parallel"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 2, 1)
                const sw = root.addElement("switch", 5, 1)
                const b1 = root.addElement("bulb", 8, 1)
                const b2 = root.addElement("bulb", 8, 4)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [b1, 0])
                root.addWire([sw, 1], [b2, 0])
                root.addWire([b1, 1], [bat, 0])
                root.addWire([b2, 1], [bat, 0])
            }
        }
        Scenario {
            name: "metering"
            script: () => {
                root.clearBoard()
                const bat = root.addElement("battery", 2, 1)
                const sw = root.addElement("switch", 5, 1)
                const amp = root.addElement("ammeter", 8, 1)
                const res = root.addElement("resistor", 2, 4)
                const led = root.addElement("led", 5, 4)
                const volt = root.addElement("voltmeter", 8, 4)
                root.addWire([bat, 1], [sw, 0])
                root.addWire([sw, 1], [amp, 1])
                root.addWire([amp, 0], [led, 1])
                root.addWire([led, 0], [res, 1])
                root.addWire([res, 0], [bat, 0])
                root.addWire([volt, 0], [led, 0])
                root.addWire([volt, 1], [led, 1])
            }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }

    function labInfo() {
        const info = Lab.labInfo()
        const byType = {}
        for (const el of elements) byType[el.type] = (byType[el.type] || 0) + 1
        info.circuit = { elements: byType, wires: wires.length,
                         nets: sim.netCount || 0, shorted: sim.shorted,
                         iterations: sim.iterations }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- interaction state ------------------------------------------------
    property var wiringFrom: null       // {el, ti} while a wire is dangling
    property bool eraser: false
    property var hoverHit: null         // last hit under the cursor
    property var cursorW: Qt.vector3d(0, 1.9, 0)
    property string paletteDrag: ""     // element type while dragging from GUI

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
            if (Math.abs(x - wx) < 4.6 && Math.abs(z - wz) < 3.4)
                return { kind: "element", el: el.id, type: el.type }
        }
        for (let i = 0; i < wires.length; ++i) {
            const apex = wireApex(wires[i], i)
            if (Math.hypot(apex.x - wx, apex.z - wz) < 2.0)
                return { kind: "wire", wire: wires[i].id }
        }
        return null
    }

    function wireApex(w, idx) {
        const a = terminalPos(w.a[0], w.a[1])
        const b = terminalPos(w.b[0], w.b[1])
        return Qt.vector3d((a.x + b.x) / 2, 3.0 + (idx % 3) * 0.8, (a.z + b.z) / 2)
    }
    function wirePath(w, idx) {
        const a = terminalPos(w.a[0], w.a[1])
        const b = terminalPos(w.b[0], w.b[1])
        const m = wireApex(w, idx)
        const pts = []
        for (let i = 0; i <= 14; ++i) {
            const t = i / 14
            const u = 1 - t
            pts.push(Qt.vector3d(
                u * u * a.x + 2 * u * t * m.x + t * t * b.x,
                u * u * a.y + 2 * u * t * (m.y + 1.6) + t * t * b.y,
                u * u * a.z + 2 * u * t * m.z + t * t * b.z))
        }
        return [pts]
    }
    readonly property var wireColors: ["#e04b3a", "#2e343d", "#3a7bd5", "#3fbf6f"]

    // --- 3D scene ---------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#0d0d1a"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(0, 60, 54)
            eulerRotation: Qt.vector3d(-47, 0, 0)
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -25
            castsShadow: true
            shadowFactor: 78
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
        }
        DirectionalLight {
            eulerRotation.x: -60
            eulerRotation.y: 140
            brightness: 0.35
        }

        Model {  // pegboard - the only pickable model; everything maps through it
            id: boardModel
            source: "#Cube"
            pickable: true
            position: Qt.vector3d(0, -2, 0)
            scale: Qt.vector3d(1.06, 0.04, 0.66)
            materials: PrincipledMaterial { baseColor: "#16222e"; roughness: 0.85 }
        }
        Box3D {  // rim
            width: 112; height: 1.6; depth: 72
            position: Qt.vector3d(0, -3.0, 0)
            color: "#0f9d9a"
        }
        Repeater3D {  // peg dots mark the cells
            model: root.cols * root.rows
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(root.cellX(index % root.cols), 0.05,
                                      root.cellZ(Math.floor(index / root.cols)))
                scale: Qt.vector3d(0.008, 0.001, 0.008)
                materials: PrincipledMaterial {
                    baseColor: "#38495c"
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
                position: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? Qt.vector3d(root.cellX(e.col), 0, root.cellZ(e.row))
                             : Qt.vector3d(0, 0, 0)
                }
                type: modelData.type
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
                shorted: modelData.type === "battery" && root.sim.shorted
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

        Repeater3D {  // wires
            model: root.wires
            Node {
                MultiLine3D {
                    coords: { root.elemRev; return root.wirePath(modelData, index) }
                    color: root.wireColors[index % root.wireColors.length]
                    width: 0.55
                }
                Model {  // grab/erase handle at the apex
                    source: "#Sphere"
                    position: { root.elemRev; return root.wireApex(modelData, index) }
                    scale: Qt.vector3d(0.011, 0.011, 0.011)
                    materials: PrincipledMaterial {
                        baseColor: root.wireColors[index % root.wireColors.length]
                        emissiveFactor: root.hoverHit !== null
                                        && root.hoverHit.kind === "wire"
                                        && root.hoverHit.wire === modelData.id
                                        ? Qt.vector3d(0.8, 0.2, 0.2) : Qt.vector3d(0, 0, 0)
                        roughness: 0.4
                    }
                }
            }
        }

        MultiLine3D {  // dangling wire preview
            visible: root.wiringFrom !== null
            coords: {
                if (!root.wiringFrom) return []
                const a = root.terminalPos(root.wiringFrom.el, root.wiringFrom.ti)
                const b = root.cursorW
                return [[a, Qt.vector3d((a.x + b.x) / 2, 4.5, (a.z + b.z) / 2), b]]
            }
            color: "#00d9ff"
            width: 0.4
        }
    }

    // --- mouse interaction ------------------------------------------------
    MouseArea {
        id: boardMouse
        anchors.fill: parent
        hoverEnabled: true
        property var dragElem: null
        property bool dragged: false
        property var pressW: null

        function worldAt(mx, my) {
            const res = view3d.pick(mx, my)
            if (res && res.objectHit === boardModel) return res.scenePosition
            return null
        }

        onPositionChanged: (mouse) => {
            const w = worldAt(mouse.x, mouse.y)
            if (!w) return
            root.cursorW = Qt.vector3d(w.x, 1.9, w.z)
            if (pressed && dragElem) {
                if (!dragged && pressW && Math.hypot(w.x - pressW.x, w.z - pressW.z) > 1.2)
                    dragged = true
                if (dragged)
                    root.moveElement(dragElem,
                                     w.x / root.cell + (root.cols - 1) / 2,
                                     w.z / root.cell + (root.rows - 1) / 2)
            } else {
                root.hoverHit = root.hitAt(w.x, w.z)
            }
        }
        onPressed: (mouse) => {
            root.forceActiveFocus()
            const w = worldAt(mouse.x, mouse.y)
            if (!w) return
            pressW = w; dragged = false; dragElem = null
            const hit = root.hitAt(w.x, w.z)
            if (!hit) { if (!root.eraser) root.wiringFrom = null; return }
            if (root.eraser) {
                if (hit.kind === "wire") root.removeWire(hit.wire)
                else if (hit.kind === "element" || hit.kind === "terminal")
                    root.removeElement(hit.el)
                return
            }
            if (hit.kind === "terminal") {
                if (root.wiringFrom === null)
                    root.wiringFrom = { el: hit.el, ti: hit.ti }
                else {
                    root.addWire([root.wiringFrom.el, root.wiringFrom.ti],
                                 [hit.el, hit.ti])
                    root.wiringFrom = null
                }
                return
            }
            if (hit.kind === "element")
                dragElem = hit.el
        }
        onReleased: {
            if (dragElem && !dragged) {
                const el = root.elemAt(dragElem)
                if (el && el.type === "switch") root.toggleSwitch(dragElem)
                else if (el && el.type === "resistor") root.cycleResistor(dragElem)
            }
            dragElem = null; dragged = false
        }
    }

    // --- palette ----------------------------------------------------------
    readonly property var partCatalog: [
        { type: "battery", label: "Battery", hint: "voltage from the slider", color: "#0f9d9a" },
        { type: "switch", label: "Switch", hint: "click to flip", color: "#c74a52" },
        { type: "resistor", label: "Resistor", hint: "click cycles Ω", color: "#d9c9a0" },
        { type: "led", label: "LED", hint: "gold foot = +", color: "#ff5a4a" },
        { type: "bulb", label: "Bulb", hint: "brightness = power", color: "#ffd98c" },
        { type: "ammeter", label: "Ammeter", hint: "wire it in series", color: "#0f9d9a" },
        { type: "voltmeter", label: "Voltmeter", hint: "wire it across", color: "#ff3366" }
    ]

    Rectangle {
        id: palette
        x: 12; y: 12
        width: 168
        height: paletteCol.height + 20
        radius: 8
        color: "#e60a0f14"
        border.color: "#5500d9ff"; border.width: 1

        Column {
            id: paletteCol
            x: 10; y: 10
            spacing: 4
            Text {
                text: "ELECTRONICS 101"
                color: "#00d9ff"; font.pixelSize: 13; font.bold: true
                font.letterSpacing: 1.5
            }
            Text {
                text: "drag parts onto the board"
                color: "#889099"; font.pixelSize: 10
            }
            Item { width: 1; height: 6 }
            Repeater {
                model: root.partCatalog
                Rectangle {
                    width: 148; height: 40; radius: 6
                    color: partArea.containsMouse ? "#1c2c3c" : "#141f2a"
                    border.color: partArea.containsMouse ? "#7700d9ff" : "#33222f3a"
                    Rectangle {
                        x: 8; y: 11; width: 18; height: 18; radius: 4
                        color: modelData.color
                    }
                    Column {
                        x: 34; anchors.verticalCenter: parent.verticalCenter
                        Text { text: modelData.label; color: "#dfe7ee"; font.pixelSize: 12; font.bold: true }
                        Text { text: modelData.hint; color: "#889099"; font.pixelSize: 9 }
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
            Item { width: 1; height: 6 }
            Rectangle {
                width: 148; height: 34; radius: 6
                color: root.eraser ? "#66ff3366" : "#141f2a"
                border.color: root.eraser ? "#ff3366" : "#33222f3a"
                Text {
                    anchors.centerIn: parent
                    text: root.eraser ? "ERASER ON  (E)" : "Eraser  (E)"
                    color: root.eraser ? "#ffffff" : "#dfe7ee"; font.pixelSize: 11
                }
                MouseArea { anchors.fill: parent; onClicked: root.eraser = !root.eraser }
            }
            Rectangle {
                width: 148; height: 30; radius: 6
                color: "#141f2a"; border.color: "#33222f3a"
                Text {
                    anchors.centerIn: parent
                    text: "Clear board  (C)"
                    color: "#dfe7ee"; font.pixelSize: 11
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearBoard() }
            }
        }
    }

    // drag ghost following the cursor while dragging out of the palette
    Rectangle {
        visible: root.paletteDrag !== "" && ghostArea.mx > 0
        x: ghostArea.mx + 10; y: ghostArea.my - 14
        width: ghostLabel.width + 18; height: 26; radius: 6
        color: "#cc0f2a38"; border.color: "#00d9ff"
        Text {
            id: ghostLabel
            anchors.centerIn: parent
            text: root.paletteDrag
            color: "#00d9ff"; font.pixelSize: 12
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
                root.elemRev
                const e = root.elemAt(modelData.id)
                if (!e) return Qt.vector3d(0, 0, 0)
                return view3d.mapFrom3DScene(Qt.vector3d(
                    root.cellX(e.col), 7.5, root.cellZ(e.row)))
            }
            readonly property string reading: {
                const s = root.simOf(modelData.id)
                if (modelData.type === "ammeter")
                    return Math.abs(s.i) >= 0.9995 ? s.i.toFixed(2) + " A"
                                                   : (s.i * 1000).toFixed(1) + " mA"
                return s.v.toFixed(2) + " V"
            }
            visible: isMeter && screenAt.z > 0
            x: screenAt.x - width / 2
            y: screenAt.y - height
            width: readingText.width + 18
            height: 24
            radius: 12
            color: "#e60a0f14"
            border.color: modelData.type === "ammeter" ? "#0f9d9a" : "#ff3366"
            border.width: 1.5
            Text {
                id: readingText
                anchors.centerIn: parent
                text: (modelData.type === "ammeter" ? "A " : "V ") + parent.reading
                color: "#dfe7ee"; font.pixelSize: 13; font.bold: true
            }
        }
    }

    // --- short-circuit banner ---------------------------------------------
    Rectangle {
        visible: root.sim.shorted
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: shortText.width + 40; height: 36; radius: 8
        color: "#d8ff3366"
        Text {
            id: shortText
            anchors.centerIn: parent
            text: "⚠ SHORT CIRCUIT — check your wiring!"
            color: "#ffffff"; font.pixelSize: 14; font.bold: true
        }
        SequentialAnimation on opacity {
            running: root.sim.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
            NumberAnimation { to: 0.55; duration: 300 }
            NumberAnimation { to: 1.0; duration: 300 }
        }
    }

    // --- hint bar ----------------------------------------------------------
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        width: hintText.width + 30; height: 26; radius: 6
        color: "#c80a0f14"
        Text {
            id: hintText
            anchors.centerIn: parent
            color: "#889099"; font.pixelSize: 11
            text: {
                if (root.eraser) return "eraser: click parts or wire knots to remove · E exits"
                if (root.wiringFrom) return "click a second terminal to connect · Esc cancels"
                return "wire: click two gold terminals · click switch to flip · click resistor to change Ω · drag to move · 1-4 presets"
            }
        }
    }

    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    Plot2D {
        id: plot
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 10
        width: 330; height: 140
        probes: ["iBattery", "iLed"]
        seriesColors: ["#ffd93d", "#ff5a4a"]
        windowSeconds: 30
    }

    // --- keys --------------------------------------------------------------
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_1) applyScenario("led-basic")
        else if (ev.key === Qt.Key_2) applyScenario("series")
        else if (ev.key === Qt.Key_3) applyScenario("parallel")
        else if (ev.key === Qt.Key_4) applyScenario("metering")
        else if (ev.key === Qt.Key_C) clearBoard()
        else if (ev.key === Qt.Key_E) eraser = !eraser
        else if (ev.key === Qt.Key_Escape) { wiringFrom = null; eraser = false }
        else if (ev.key === Qt.Key_R) recorder.recording = !recorder.recording
    }
}
