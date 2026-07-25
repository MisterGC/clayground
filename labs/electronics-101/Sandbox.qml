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
// E eraser · # grid mode · R turn selected · Del remove selected ·
// Shift+R record · Esc cancel. View: drag the empty board to orbit,
// wheel zooms, arrows/+/- nudge, F frames the selection, 0 resets.
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
    // elements: {id, type, col, row, rot, value, on} - col/row are fractional
    // cell coordinates (snapping rounds them) - wires: {id, a:[el,ti], b:[el,ti]}
    property var elements: []
    property var wires: []
    property int nextId: 1
    property var sim: ({ ok: true, perElement: {}, shorted: false, iterations: 0 })
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
        const off = ti === 0 ? -3.5 : 3.5
        const a = (el.rot || 0) * Math.PI / 180
        return Qt.vector3d(cellX(el.col) + off * Math.cos(a), 1.9,
                           cellZ(el.row) - off * Math.sin(a))
    }

    function resolve() {
        const els = elements.map(el => ({
            id: el.id, type: el.type, on: el.on,
            value: el.type === "battery" ? pBatteryV.value : el.value
        }))
        sim = Circuit.solve(els, wires)
    }
    Connections { target: pBatteryV; function onValueChanged() { root.resolve() } }

    // Two pegs of clearance: parts are wider than one raster step
    function cellFree(col, row, ignoreId) {
        for (const el of elements)
            if (el.id !== ignoreId && Math.abs(el.col - col) < 1.6
                && Math.abs(el.row - row) < 1.6) return false
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
        const spot = nearestFreeCell(col === undefined ? 10 : col,
                                     row === undefined ? 6 : row)
        if (!spot) return -1
        const el = { id: nextId++, type: type, col: spot.col, row: spot.row, rot: 0,
                     value: type === "resistor" ? 470 : 0, on: false }
        elements = elements.concat([el])
        resolve()
        return el.id
    }
    function removeElement(id) {
        wires = wires.filter(w => w.a[0] !== id && w.b[0] !== id)
        elements = elements.filter(el => el.id !== id)
        if (selectedId === id) selectedId = -1
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
            if (!cellFree(col, row, id)) return
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
        selectedId = -1
        resolve()
    }

    // --- camera -----------------------------------------------------------
    // An orbit cam on a leash: it always looks at the setup, always stays
    // above the board and outside the parts, and it reframes itself for the
    // scenario that is on the board. You can circle it and zoom in, but you
    // cannot fly into a part or end up lost under the table.
    property real camYaw: 0        // degrees around the setup
    property real camPitch: 48     // degrees above the board plane
    property real camDist: 80      // distance to the pivot
    property var camPivot: Qt.vector3d(0, 2, 0)

    readonly property real camPitchMin: 22   // never skim along the board
    readonly property real camPitchMax: 84   // never flip over the top
    readonly property real camDistMin: 20    // clears a single part
    readonly property real camDistMax: 170
    readonly property real camHeightMin: 9   // taller than anything on the board

    // The leash: pitch and distance are bounded, and on top of that the
    // camera must stay at least camHeightMin above the pivot plane. That one
    // rule is what makes clipping into a part impossible - flatten the angle
    // and the rig backs off instead of diving through the setup.
    function clampCam() {
        camPitch = Math.max(camPitchMin, Math.min(camPitchMax, camPitch))
        let d = Math.max(camDistMin, Math.min(camDistMax, camDist))
        const sinP = Math.sin(camPitch * Math.PI / 180)
        d = Math.max(d, camHeightMin / Math.max(0.05, sinP))
        camDist = Math.min(d, camDistMax)
    }
    function orbitBy(dYaw, dPitch) {
        camYaw += dYaw
        camPitch -= dPitch
        clampCam()
    }
    function zoomBy(f) { camDist *= f; clampCam() }

    // Frame a set of cells: pivot on their centre, back off far enough to
    // hold them all in view. With no argument it frames the whole setup.
    function frameCells(cells) {
        if (!cells || !cells.length) {
            camPivot = Qt.vector3d(0, 2, 0)
            camDist = camDistMax
            clampCam()
            return
        }
        let x0 = Infinity, x1 = -Infinity, z0 = Infinity, z1 = -Infinity
        for (const c of cells) {
            const x = cellX(c.col), z = cellZ(c.row)
            x0 = Math.min(x0, x); x1 = Math.max(x1, x)
            z0 = Math.min(z0, z); z1 = Math.max(z1, z)
        }
        camPivot = Qt.vector3d((x0 + x1) / 2, 2, (z0 + z1) / 2)
        const r = Math.max(9, Math.hypot(x1 - x0, z1 - z0) / 2 + 7)
        camDist = r * 1.7 + 20
        clampCam()
    }
    function frameSetup() { frameCells(elements) }
    function frameSelection() {
        const el = elemAt(selectedId)
        frameCells(el ? [el] : elements)
    }

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
            cam: { yaw: camYaw, pitch: camPitch, dist: camDist,
                   px: camPivot.x, pz: camPivot.z }
        })
    }
    // The user's board wins over the scenario preset: with a circuit payload
    // the scenario is NOT re-applied, the exact board comes back instead.
    // The viewpoint is restored last, so a rearmed scenario cannot yank the
    // camera away from where the user was looking.
    function applyViewState(s) {
        if (s.circuit) loadCircuit(s.circuit)
        else if (s.scenario) applyScenario(s.scenario)
        if (s.cam) {
            camPivot = Qt.vector3d(s.cam.px, 2, s.cam.pz)
            camYaw = s.cam.yaw; camPitch = s.cam.pitch; camDist = s.cam.dist
            clampCam()
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
                const bat = root.addElement("battery", 4, 2)
                const sw = root.addElement("switch", 10, 2)
                const b1 = root.addElement("bulb", 16, 2)
                const b2 = root.addElement("bulb", 16, 8)
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
            }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        const r = scenarioSet.apply(n)
        frameSetup()   // every preset arrives properly framed
        return r
    }

    function labInfo() {
        const info = Lab.labInfo()
        const byType = {}
        for (const el of elements) byType[el.type] = (byType[el.type] || 0) + 1
        info.circuit = { elements: byType, wires: wires.length,
                         nets: sim.netCount || 0, shorted: sim.shorted,
                         iterations: sim.iterations }
        info.ui = { selected: selectedId, snap: snapToGrid }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- interaction state ------------------------------------------------
    property var wiringFrom: null       // {el, ti} while a wire is dangling
    property bool eraser: false
    property var hoverHit: null         // last hit under the cursor
    property var cursorW: Qt.vector3d(0, 1.9, 0)
    property string paletteDrag: ""     // element type while dragging from GUI
    property int selectedId: -1         // -1 = nothing selected
    property bool snapToGrid: true      // grafli-style grid mode, # toggles it

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
            // body box turned by the part's yaw -> axis-aligned bound of it
            const a = (el.rot || 0) * Math.PI / 180
            const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a))
            if (Math.abs(x - wx) < 4.6 * c + 3.4 * s
                && Math.abs(z - wz) < 4.6 * s + 3.4 * c)
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
    readonly property var wireColors: LabTheme.seriesColors

    // --- 3D scene ---------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            // slightly lighter than the table below, so that a horizon line
            // appears at low camera angles - the eye keeps a reference
            clearColor: "#f2eee7"
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
                baseColor: LabTheme.paper
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
        // Orbit rig: the camera hangs off a yaw node at the pivot, so it can
        // never look anywhere but at the setup.
        Node {
            position: root.camPivot
            eulerRotation.y: root.camYaw
            Behavior on position { Vector3dAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Node {
                eulerRotation.x: -root.camPitch
                PerspectiveCamera {
                    id: cam
                    position: Qt.vector3d(0, 0, root.camDist)
                    clipNear: 1
                    clipFar: 900
                    Behavior on position { Vector3dAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }
            }
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
            shadowFactor: 62          // present, not dramatic
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
                baseColor: LabTheme.paperDeep
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
        Box3D {  // rim
            width: 112; height: 1.6; depth: 72
            position: Qt.vector3d(0, -3.0, 0)
            color: LabTheme.ink
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
                position: {
                    root.elemRev
                    const e = root.elemAt(modelData.id)
                    return e ? Qt.vector3d(root.cellX(e.col), 0, root.cellZ(e.row))
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
                Wire3D {
                    points: { root.elemRev; return root.wirePath(modelData, index)[0] }
                    color: root.wireColors[index % root.wireColors.length]
                    radius: 0.3
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
            return root.snapToGrid !== ((mods & Qt.AltModifier) !== 0)
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
            if (hit.kind === "element") {
                root.selectedId = hit.el
                dragElem = hit.el
            }
        }
        onReleased: {
            if (dragElem && !dragged) {
                const el = root.elemAt(dragElem)
                if (el && el.type === "switch") root.toggleSwitch(dragElem)
                else if (el && el.type === "resistor") root.cycleResistor(dragElem)
            }
            dragElem = null; dragged = false; orbiting = false
        }
    }

    // --- palette ----------------------------------------------------------
    readonly property var partCatalog: [
        { type: "battery", label: "Battery", hint: "voltage from the slider", color: "#3e9b92" },
        { type: "switch", label: "Switch", hint: "click to flip", color: "#c56c54" },
        { type: "resistor", label: "Resistor", hint: "click cycles Ω", color: "#d9c9a0" },
        { type: "led", label: "LED", hint: "gold foot = +", color: "#e05a40" },
        { type: "bulb", label: "Bulb", hint: "brightness = power", color: "#d4ba6a" },
        { type: "ammeter", label: "Ammeter", hint: "wire it in series", color: "#3f7a57" },
        { type: "voltmeter", label: "Voltmeter", hint: "wire it across", color: "#8160a8" }
    ]

    Rectangle {
        id: palette
        x: 12; y: 12
        width: 168
        height: paletteCol.height + 20
        radius: 8
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth

        Column {
            id: paletteCol
            x: 10; y: 10
            spacing: 4
            Text {
                text: "ELECTRONICS 101"
                color: LabTheme.primary; font.pixelSize: 13; font.bold: true
                font.letterSpacing: 1.5; font.family: LabTheme.monoFont
            }
            Text {
                text: "drag parts onto the board"
                color: LabTheme.inkFaint; font.pixelSize: 13
                font.family: LabTheme.handFont
            }
            Item { width: 1; height: 6 }
            Repeater {
                model: root.partCatalog
                Rectangle {
                    width: 148; height: 40; radius: 6
                    color: partArea.containsMouse ? "#ffffff" : LabTheme.paper
                    border.color: partArea.containsMouse ? LabTheme.secondary : LabTheme.panelEdge
                    Rectangle {
                        x: 8; y: 11; width: 18; height: 18; radius: 4
                        color: modelData.color
                    }
                    Column {
                        x: 34; anchors.verticalCenter: parent.verticalCenter
                        Text { text: modelData.label; color: LabTheme.ink; font.pixelSize: 12; font.bold: true; font.family: LabTheme.monoFont }
                        Text { text: modelData.hint; color: LabTheme.inkFaint; font.pixelSize: 12; font.family: LabTheme.handFont }
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
                color: root.eraser ? LabTheme.clay : LabTheme.paper
                border.color: root.eraser ? LabTheme.alarm : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: root.eraser ? "ERASER ON  (E)" : "Eraser  (E)"
                    color: root.eraser ? "#ffffff" : LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.eraser = !root.eraser }
            }
            Rectangle {
                width: 148; height: 30; radius: 6
                color: LabTheme.paper
                border.color: root.snapToGrid ? LabTheme.secondary : LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: root.snapToGrid ? "Grid: snap  (#)" : "Grid: free  (#)"
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.snapToGrid = !root.snapToGrid }
            }
            Rectangle {
                width: 148; height: 30; radius: 6
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: "Clear board  (C)"
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearBoard() }
            }
            Rectangle {
                width: 148; height: 30; radius: 6
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                Text {
                    anchors.centerIn: parent
                    text: "View " + Math.round(((root.camYaw % 360) + 360) % 360)
                          + "°   reset (0)"
                    color: LabTheme.inkSoft; font.pixelSize: 11
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.frameSetup() }
            }
        }
    }

    // --- compass: which way the board faces while you circle it ------------
    Rectangle {
        x: 12; y: palette.y + palette.height + 10
        width: 72; height: 72; radius: 36
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth

        Rectangle {  // the board, seen from above, turning with the view
            anchors.centerIn: parent
            width: 40; height: 26; radius: 3
            color: LabTheme.paperDeep
            border.color: LabTheme.ink; border.width: 1.5
            rotation: -root.camYaw
            Rectangle {  // front edge marker
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 14; height: 3
                color: LabTheme.accent
            }
        }
        Rectangle {  // you: fixed at the bottom, the board turns instead
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            width: 8; height: 8; radius: 4
            color: LabTheme.secondary
        }
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
            text: root.paletteDrag
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
                root.elemRev; cam.scenePosition; cam.sceneRotation
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

    // --- selection card (what is selected, what it reads, what you can do) -
    Rectangle {
        id: selCard
        readonly property var el: {
            root.elemRev
            return root.selectedId === -1 ? null : root.elemAt(root.selectedId)
        }
        readonly property var screenAt: {
            root.elemRev; cam.scenePosition; cam.sceneRotation
            if (!el) return Qt.vector3d(0, 0, 0)
            return view3d.mapFrom3DScene(Qt.vector3d(root.cellX(el.col), 0,
                                                     root.cellZ(el.row) + 5.5))
        }
        visible: el !== null && screenAt.z > 0
        // kept inside the window: zoomed in, the anchor point can sit far
        // below the viewport
        x: Math.max(8, Math.min(root.width - width - 8, screenAt.x - width / 2))
        y: Math.max(8, Math.min(root.height - height - 44, screenAt.y + 6))
        width: selCol.width + 20
        height: selCol.height + 14
        radius: LabTheme.radius
        color: LabTheme.panel
        border.color: LabTheme.secondary
        border.width: LabTheme.borderWidth

        Column {
            id: selCol
            x: 10; y: 7
            spacing: 1
            Text {
                text: {
                    if (!selCard.el) return ""
                    const e = selCard.el
                    if (e.type === "resistor") return "RESISTOR  " + e.value + " Ω"
                    if (e.type === "battery") return "BATTERY  " + pBatteryV.value.toFixed(1) + " V"
                    if (e.type === "switch") return "SWITCH  " + (e.on ? "closed" : "open")
                    return e.type.toUpperCase()
                }
                color: LabTheme.primary; font.pixelSize: 11; font.bold: true
                font.letterSpacing: 1.0; font.family: LabTheme.monoFont
            }
            Text {
                text: {
                    if (!selCard.el) return ""
                    const s = root.simOf(selCard.el.id)
                    return s.v.toFixed(2) + " V   " + (s.i * 1000).toFixed(1) + " mA"
                }
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Text {
                text: "R turn · Del remove · drag to move"
                color: LabTheme.inkFaint; font.pixelSize: 12
                font.family: LabTheme.handFont
            }
        }
    }

    // --- short-circuit banner ---------------------------------------------
    Rectangle {
        visible: root.sim.shorted
        anchors.horizontalCenter: parent.horizontalCenter
        y: 16
        width: shortText.width + 40; height: 36; radius: 8
        color: LabTheme.alarm
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
        color: LabTheme.panel
        Text {
            id: hintText
            anchors.centerIn: parent
            color: LabTheme.inkSoft; font.pixelSize: 15
            font.family: LabTheme.handFont
            text: {
                if (root.eraser) return "eraser: click parts or wire knots to remove · E exits"
                if (root.wiringFrom) return "click a second terminal to connect · Esc cancels"
                if (root.selectedId !== -1)
                    return "R turns the part · Del removes it · drag moves it"
                    + (root.snapToGrid ? " (Alt places freely)" : " (Alt snaps)")
                    + " · F frames it"
                return "click two gold terminals to wire · click a part to select · drag the empty board to look around · wheel zooms · 0 resets the view"
            }
        }
    }

    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    Plot2D {
        id: plot
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 10
        width: 330; height: 140
        probes: ["iBattery", "iLed"]
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
        else if (ev.key === Qt.Key_Escape) { wiringFrom = null; eraser = false; selectedId = -1 }
        else if (ev.key === Qt.Key_NumberSign || ev.key === Qt.Key_G)
            snapToGrid = !snapToGrid
        else if (ev.key === Qt.Key_Delete || ev.key === Qt.Key_Backspace) {
            if (selectedId !== -1) removeElement(selectedId)
        }
        else if (ev.key === Qt.Key_R) {
            if (ev.modifiers & Qt.ShiftModifier) recorder.recording = !recorder.recording
            else if (selectedId !== -1) rotateElement(selectedId)
        }
        // --- view ---
        else if (ev.key === Qt.Key_Left) orbitBy(-6, 0)
        else if (ev.key === Qt.Key_Right) orbitBy(6, 0)
        else if (ev.key === Qt.Key_Up) orbitBy(0, 4)
        else if (ev.key === Qt.Key_Down) orbitBy(0, -4)
        else if (ev.key === Qt.Key_Plus || ev.key === Qt.Key_Equal) zoomBy(0.88)
        else if (ev.key === Qt.Key_Minus) zoomBy(1.14)
        else if (ev.key === Qt.Key_F) frameSelection()
        else if (ev.key === Qt.Key_0 || ev.key === Qt.Key_Home) frameSetup()
    }
}
