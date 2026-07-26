// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Common
import Clayground.Lab
import "../kits/traffic"
import "../kits/traffic/roadgraph.js" as RoadGraph
import "../kits/traffic/lanemodel.js" as LaneModel
import "../kits/traffic/traffic.js" as Traffic
import "../kits/traffic/strings.js" as TrafficStrings
import "strings.js" as Strings

// Street Network 101 - a city plan you draw yourself. Drag out roads; they
// join whatever they touch and split whatever they cross, so intersections
// appear because of what you drew, not because you placed them. The lane
// model is DERIVED, never drawn: lanes, turn curves and dead ends all follow
// from the graph. Press Simulate and cars drive the lanes they were given.
//
// Keys: 1..4 scenarios · S simulate · C clear · E erase · L lane model ·
// V flow numbers · M lane graph · W plot the selected road · # grid mode ·
// Del remove · Esc cancel · Shift+R record. View: right-drag turns, wheel
// zooms, arrows/+/- nudge, F frames the selection, 0 resets.
Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        // the kit owns the vocabulary, the lab its own copy
        LabLang.register(TrafficStrings.dict)
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("crossroads")
    }

    // --- clock -------------------------------------------------------------
    // The clock is the throttle: stopping the traffic means stopping TIME, not
    // skipping the step. That keeps the sim a pure function of clock.time, so
    // the reload path (Lab.applyViewState re-steps a world-less clock) replays
    // exactly the same traffic that was on screen before.
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.25
        timeScale: root.running ? Lab.p("simSpeed") : 0
    }

    readonly property real fixedDt: 1 / 60
    property real _lastTime: 0
    property real _stepAccum: 0
    property int _stepsTaken: 0

    Connections {
        target: clock
        function onTimeChanged() {
            var dt = clock.time - root._lastTime
            root._lastTime = clock.time
            if (dt <= 0) return                 // a reset rewinds; ignore it
            root._stepAccum += dt
            // fixed steps only, and never more than a handful in one frame: a
            // hitch must not turn into a freeze while the sim catches up
            var budget = 8
            while (root._stepAccum >= root.fixedDt && budget-- > 0) {
                root._stepAccum -= root.fixedDt
                root.stepSim(root.fixedDt)
            }
            if (budget <= 0) root._stepAccum = 0
        }
    }
    Connections {
        target: clock
        function onWasReset() {
            root._lastTime = 0
            root._stepAccum = 0
            root._stepsTaken = 0
            root.simState = Traffic.createState()
            root.simRev++
        }
    }
    // buckets for the chevron speed, refreshed on the sample grid rather than
    // per frame (see Streets3D.flowRev)
    Connections {
        target: Lab
        function onSampled(t) { root.refreshFlow() }
    }

    // --- parameters --------------------------------------------------------
    // Global because they genuinely have no owner - a road does not have a
    // density. Everything that DOES belong to a road (its lane count) lives on
    // the road's own card instead.
    // Deliberately allowed to run well past what the grid can hold: the
    // plateau - asking for three times the traffic and getting the same cars,
    // slower - is the capacity lesson, and it has to be reachable.
    Parameter {
        name: "demand"; value: 0.5; from: 0.05; to: 3.0; stepSize: 0.05
        description: "cars asked for per unit of lane"
    }
    Parameter {
        name: "speed"; value: 15; from: 5; to: 28; stepSize: 1; unit: "u/s"
        description: "free-flow speed"
    }
    Parameter {
        name: "simSpeed"; value: 1; from: 0.25; to: 3; stepSize: 0.25; unit: "x"
        description: "wall-clock pace only"
    }

    // --- probes ------------------------------------------------------------
    Probe {
        name: "cars"; unit: ""
        expr: () => root.simState.cars.length
    }
    Probe {
        name: "meanSpeed"; unit: "u/s"
        expr: () => Traffic.meanSpeed(root.simState)
    }
    Probe {
        name: "waiting"; unit: "%"
        expr: () => Traffic.stoppedShare(root.simState) * 100
    }

    DataRecorder { id: recorder; destination: "street-network-101-run.csv" }

    // --- monitoring --------------------------------------------------------
    // The plotted set is the WATCHED set, and what you watch is a road you
    // picked off the plan - same act as selecting it, same colour on the board
    // as in the legend.
    property var watch: []                   // road ids, in plot order
    property string watchQuantity: "flow"    // flow | load | speed
    readonly property int watchMax: 6
    readonly property var watchQuantities: [
        { key: "flow", label: "quantity.flow", unit: "/min" },
        { key: "load", label: "quantity.load", unit: "" },
        { key: "speed", label: "quantity.speed", unit: "u/s" }]
    readonly property string watchUnitText:
        watchQuantity === "flow" ? "/min" : (watchQuantity === "speed" ? "u/s" : "")

    function watchValueOf(roadId) {
        if (watchQuantity === "flow") return Traffic.roadRate(simState, roadId)
        var n = 0, sum = 0
        for (const c of simState.cars) {
            if (c.kind !== 0) continue
            if (net.lanes[c.idx].roadId !== roadId) continue
            ++n; sum += c.v
        }
        if (watchQuantity === "load") return n
        return n ? sum / n : 0
    }
    function isWatched(id) { return watch.indexOf(id) !== -1 }
    function watchColorOf(id) {
        const i = watch.indexOf(id)
        return i === -1 ? "transparent"
            : LabTheme.seriesColors[i % LabTheme.seriesColors.length]
    }
    function setWatched(id, on) {
        if (on === isWatched(id)) return
        if (on) {
            if (watch.length >= watchMax) return
            watch = watch.concat([id])
        } else watch = watch.filter(x => x !== id)
    }
    function toggleWatch(id) { setWatched(id, !isWatched(id)) }
    function watchOnly(ids) { watch = ids.slice(0, watchMax) }

    // a new quantity is a new unit, so the old samples would draw a nonsense
    // step across the axis change
    onWatchQuantityChanged: {
        for (const id of watch) {
            const pr = Lab.probe("road" + id)
            if (pr) pr.clear()
        }
    }

    Instantiator {
        model: root.watch
        delegate: Probe {
            required property var modelData
            readonly property int rid: modelData
            name: "road" + rid
            unit: root.watchUnitText
            expr: () => root.watchValueOf(rid)
        }
    }

    // --- the network -------------------------------------------------------
    property var graph: RoadGraph.empty()
    property var net: LaneModel.derive(RoadGraph.empty())
    property var simState: Traffic.createState()
    property int graphRev: 0        // bumped on every edit, bindings depend on it
    property int simRev: 0          // bumped when the car set is replaced wholesale
    property int flowRev: 0
    property var laneFlow: []       // per-lane relative business, 0..1

    property bool running: false
    // Someone else may be holding time still - the inspector's pause, or a
    // flow saying "look at this before it moves on". Saying "Stop" while
    // nothing moves would be a lie.
    readonly property bool held: running && Clayground.paused

    readonly property real cell: 10
    readonly property int cols: 23
    readonly property int rows: 15
    readonly property real boardW: cols * cell
    readonly property real boardH: rows * cell

    function simParams() {
        const p = Traffic.defaultParams()
        p.demand = Lab.p("demand")
        p.vmax = Lab.p("speed")
        return p
    }

    // Re-derive the lane model and carry the traffic over. Called after EVERY
    // graph edit: the lane model is never edited, only ever derived, which is
    // the whole point of the lab.
    function rebuild() {
        const old = net
        net = LaneModel.derive(graph)
        Traffic.rehome(net, old, simState)
        graphRev++
        simRev++
        refreshFlow()
    }

    function stepSim(dt) {
        Traffic.step(net, simState, dt, () => clock.random(), simParams())
        _stepsTaken++
        cars3d.cars = simState.cars
        cars3d.sync()
    }

    // How busy is each lane, relative to the busiest? Drives the chevron speed,
    // so a junction that splits a stream visibly splits its flow. Reads the car
    // list only - a visualisation must never draw from the sim's RNG.
    function refreshFlow() {
        const counts = new Array(net.lanes.length).fill(0)
        for (const c of simState.cars)
            if (c.kind === 0 && c.idx < counts.length) counts[c.idx] += c.v
        let max = 0
        for (const v of counts) max = Math.max(max, v)
        const out = new Array(counts.length)
        for (let i = 0; i < counts.length; ++i)
            out[i] = max > 1e-6 ? counts[i] / max : 0
        laneFlow = out
        flowRev++
    }

    // --- editing -----------------------------------------------------------
    function snapWorld(v) {
        return snapToGrid ? Math.round(v / cell) * cell : v
    }
    function inBoard(x, z) {
        return Math.abs(x) <= boardW / 2 && Math.abs(z) <= boardH / 2
    }

    function addRoad(x1, z1, x2, z2) {
        const r = RoadGraph.insertRoad(graph, x1, z1, x2, z2, { lanes: newLanes })
        if (r.ok) { rebuild(); lastRefusal = "" }
        else lastRefusal = r.reason
        return r
    }
    function removeRoad(id) {
        if (!RoadGraph.removeRoad(graph, id)) return
        if (selectedRoad === id) selectedRoad = -1
        if (isWatched(id)) watch = watch.filter(x => x !== id)
        rebuild()
    }
    function setRoadLanes(id, n) {
        if (!RoadGraph.setLanes(graph, id, n)) return
        rebuild()
    }
    function clearPlan() {
        graph = RoadGraph.empty()
        simState = Traffic.createState()
        selectedRoad = -1
        watch = []
        rebuild()
    }

    // Moving a node drags every road that ends on it. The graph must stay
    // planar, so a move that would make two roads cross without a junction is
    // simply refused - the alternative is a plan whose lane model quietly
    // stops matching what you see.
    function moveNode(id, x, z) {
        const n = RoadGraph.nodeById(graph, id)
        if (!n) return false
        const ox = n.x, oz = n.z
        n.x = Math.max(-boardW / 2, Math.min(boardW / 2, x))
        n.z = Math.max(-boardH / 2, Math.min(boardH / 2, z))
        if (_anyCrossing()) { n.x = ox; n.z = oz; return false }
        rebuild()
        return true
    }
    function _anyCrossing() {
        const rs = graph.roads
        for (let i = 0; i < rs.length; ++i)
            for (let j = i + 1; j < rs.length; ++j) {
                const a = rs[i], b = rs[j]
                if (a.a === b.a || a.a === b.b || a.b === b.a || a.b === b.b) continue
                const p = RoadGraph.nodeById(graph, a.a), q = RoadGraph.nodeById(graph, a.b)
                const u = RoadGraph.nodeById(graph, b.a), v = RoadGraph.nodeById(graph, b.b)
                if (_segHit(p.x, p.z, q.x, q.z, u.x, u.z, v.x, v.z)) return true
            }
        return false
    }
    function _segHit(ax, az, bx, bz, cx, cz, dx, dz) {
        const r1x = bx - ax, r1z = bz - az, r2x = dx - cx, r2z = dz - cz
        const den = r1x * r2z - r1z * r2x
        if (Math.abs(den) < 1e-9) return false
        const t = ((cx - ax) * r2z - (cz - az) * r2x) / den
        const u = ((cx - ax) * r1z - (cz - az) * r1x) / den
        return t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999
    }

    // --- lookups -----------------------------------------------------------
    function roadRecord(id) {
        for (const r of net.roads) if (r.id === id) return r
        return null
    }
    function roadMidpoint(id) {
        const r = roadRecord(id)
        return r ? Qt.vector3d((r.x0 + r.x1) / 2, 0, (r.z0 + r.z1) / 2)
                 : Qt.vector3d(0, 0, 0)
    }
    function roadLabel(id) {
        let n = 0, mine = 0
        for (const r of graph.roads) { ++n; if (r.id === id) mine = n }
        return "R" + mine
    }
    function carsOnRoad(id) {
        let n = 0
        for (const c of simState.cars)
            if (c.kind === 0 && net.lanes[c.idx].roadId === id) ++n
        return n
    }
    function turnsAtNode(id) {
        let n = 0
        for (const c of net.connectors) if (c.node === id) ++n
        return n
    }
    // dead ends are a property of the LANES, and the lab's whole lesson, so
    // the plan marks the nodes where journeys end
    function deadEndNodes() {
        const out = []
        for (const nd of net.nodes) if (nd.degree === 1) out.push(nd)
        return out
    }

    // world-space hit test against the model - no per-model picking
    function hitAt(wx, wz) {
        for (const nd of net.nodes) {
            if (Math.hypot(nd.x - wx, nd.z - wz) < Math.max(3.2, nd.pad * 0.75))
                return { kind: "node", id: nd.id }
        }
        for (const r of net.roads) {
            const dx = r.x1 - r.x0, dz = r.z1 - r.z0
            const len2 = dx * dx + dz * dz
            const t = len2 < 1e-9 ? 0
                : Math.max(0, Math.min(1, ((wx - r.x0) * dx + (wz - r.z0) * dz) / len2))
            const d = Math.hypot(r.x0 + t * dx - wx, r.z0 + t * dz - wz)
            if (d < r.width / 2 + 0.5) return { kind: "road", id: r.id }
        }
        return null
    }

    // --- camera ------------------------------------------------------------
    function framePoints(pts) {
        if (!pts || !pts.length) {
            rig.pivot = Qt.vector3d(0, 0, 0)
            rig.distance = 210
            rig.clamp()
            return
        }
        rig.frame(pts, 1.12)
    }
    function framePlan() {
        const pts = graph.nodes.map(n => Qt.vector3d(n.x, 0, n.z))
        framePoints(pts.length ? pts : null)
    }
    function frameSelection() {
        const r = roadRecord(selectedRoad)
        if (!r) { framePlan(); return }
        framePoints([Qt.vector3d(r.x0, 0, r.z0), Qt.vector3d(r.x1, 0, r.z1)])
    }

    // --- interaction state -------------------------------------------------
    property bool eraser: false
    property bool snapToGrid: true
    property bool showLanes: true
    property bool showValues: false
    property bool showPlan: true
    property int newLanes: 1              // lane count for the next road drawn
    property int selectedRoad: -1
    property var hoverHit: null
    property var drawFrom: null           // {x, z} while a road is being dragged
    property var drawTo: null
    property string lastRefusal: ""
    property var cursorW: Qt.vector3d(0, 0, 0)

    readonly property bool drawValid: drawFrom !== null && drawTo !== null
        && Math.hypot(drawTo.x - drawFrom.x, drawTo.z - drawFrom.z) >= 7.0

    // --- serialization (the viewState convention) --------------------------
    function planState() {
        return { graph: RoadGraph.clone(graph), newLanes: newLanes }
    }
    function loadPlan(s) {
        graph = RoadGraph.clone(s.graph)
        if (s.newLanes) newLanes = s.newLanes
        selectedRoad = -1
        simState = Traffic.createState()
        rebuild()
    }
    function viewState() {
        return Object.assign(Lab.viewState(), {
            plan: planState(),
            watch: watch.slice(), watchQuantity: watchQuantity,
            running: running, lang: LabLang.lang,
            toggles: { lanes: showLanes, values: showValues, plan: showPlan,
                       snap: snapToGrid },
            cam: rig.state()
        })
    }
    // The plan the user drew wins over the scenario preset: with a payload the
    // scenario is NOT re-run, the exact plan comes back instead. The viewpoint
    // is restored last so nothing can yank the camera afterwards.
    function applyViewState(s) {
        if (s.plan) {
            loadPlan(s.plan)
            if (s.scenario) Lab.scenario = s.scenario
        } else if (s.scenario) applyScenario(s.scenario)
        if (s.lang) LabLang.lang = s.lang
        if (s.toggles) {
            showLanes = s.toggles.lanes; showValues = s.toggles.values
            showPlan = s.toggles.plan; snapToGrid = s.toggles.snap
        }
        if (s.watchQuantity) watchQuantity = s.watchQuantity
        if (s.watch) watch = s.watch.filter(id => roadRecord(id) !== null)
        if (s.running !== undefined) running = s.running
        // parameters and the clock re-step happen here; the scenario above has
        // already reset both, so the replay is exact
        Lab.applyViewState(s)
        if (s.cam) rig.applyState(s.cam)
    }

    // --- scenarios ---------------------------------------------------------
    // Four networks that answer one question between them: what does the SHAPE
    // of a network do to the traffic on it?
    ScenarioSet {
        id: scenarioSet
        Scenario {
            // the canonical object of study: one crossing, four stubs
            name: "crossroads"
            script: () => {
                root.clearPlan()
                root.addRoad(-90, 0, 90, 0)
                root.addRoad(0, -60, 0, 60)
            }
        }
        Scenario {
            // nine crossings: turns everywhere, so a car can circulate for
            // ever and the network holds its traffic
            name: "grid"
            script: () => {
                root.clearPlan()
                for (let i = -1; i <= 1; ++i) {
                    root.addRoad(i * 60, -70, i * 60, 70)
                    root.addRoad(-100, i * 50, 100, i * 50)
                }
            }
        }
        Scenario {
            // a tree: every branch ends. Cars leave faster than turns can
            // recirculate them, and the plan bleeds traffic.
            name: "cul-de-sac"
            script: () => {
                root.clearPlan()
                root.addRoad(-100, 0, 100, 0)
                root.addRoad(-60, 0, -60, -55)
                root.addRoad(-20, 0, -20, 55)
                root.addRoad(20, 0, 20, -55)
                root.addRoad(60, 0, 60, 55)
                root.addRoad(-60, -55, -20, -55)
                root.addRoad(20, 55, 60, 55)
            }
        }
        Scenario {
            // a loop with spurs: the ring keeps traffic in circulation while
            // the spurs quietly drain it
            name: "ring"
            script: () => {
                root.clearPlan()
                root.addRoad(-70, -50, 70, -50)
                root.addRoad(70, -50, 70, 50)
                root.addRoad(70, 50, -70, 50)
                root.addRoad(-70, 50, -70, -50)
                root.addRoad(0, -50, 0, 50)
                root.addRoad(-70, 0, -110, 0)
                root.addRoad(70, 0, 110, 0)
            }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) {
        const r = scenarioSet.apply(n)
        clock.reset()
        framePlan()
        return r
    }

    // --- the action layer (flowActions convention) -------------------------
    // One mutation API: the UI below calls these, a Flow calls them by name,
    // and an agent reaches them through the inspector's eval.
    function flowActions() {
        return {
            "road":     (x1, z1, x2, z2) => addRoad(x1, z1, x2, z2),
            "remove":   (id) => removeRoad(id),
            "lanes":    (id, n) => setRoadLanes(id, n),
            "select":   (id) => { selectedRoad = id },
            "watch":    (id, on) => setWatched(id, on),
            "simulate": (on) => { running = on },
            "clear":    () => clearPlan(),
            "scenario": (n) => applyScenario(n),
            "showLanes": (on) => { showLanes = on },
            "showValues": (on) => { showValues = on },
            "frame":    (what) => what === "selection" ? frameSelection() : framePlan()
        }
    }

    function labInfo() {
        const info = Lab.labInfo()
        info.network = {
            roads: graph.roads.length, nodes: graph.nodes.length,
            junctions: net.stats.junctions, deadEnds: net.stats.deadEnds,
            lanes: net.stats.lanes, turns: net.stats.connectors,
            laneLength: Math.round(net.stats.laneLength),
            conflictPairs: net.stats.conflictPairs
        }
        info.traffic = Traffic.summary(net, simState, simParams())
        info.traffic.running = running
        // the inspector's time action can hold the whole engine; a lab that
        // reported "running" through that would send an agent hunting a
        // simulation bug that is really a paused clock
        info.traffic.heldByPause = running && Clayground.paused
        info.traffic.steps = _stepsTaken
        // language-neutral for agents: ids and types, not display labels
        info.ui = { selected: selectedRoad, snap: snapToGrid, eraser: eraser,
                    watching: watch.slice(), quantity: watchQuantity,
                    lang: LabLang.lang }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- 3D scene ----------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera

        environment: SceneEnvironment {
            // a touch lighter than the table, so a horizon line appears at low
            // camera angles and the eye keeps a reference
            clearColor: "#f2eee7"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
        }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 0, 0)
            yaw: 0
            pitch: 52
            distance: 210
            minPitch: 20
            maxPitch: 86
            minDistance: 30
            maxDistance: 420
            minHeight: 14        // taller than anything on the plan
        }

        // Key light with real shadows, plus two fills. Nothing here is glossy;
        // depth comes from value, not glare. shadowMapFar has to cover the
        // board at full zoom-out (the range is camera-relative) and the table
        // is kept modest, because a ground plane the size of the horizon
        // starves the shadow map.
        DirectionalLight {
            eulerRotation.x: -38
            eulerRotation.y: -28
            brightness: 0.92
            castsShadow: true
            shadowFactor: 58
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            shadowMapFar: 420
            csmNumSplits: 2
            shadowBias: 3
            softShadowQuality: Light.PCF4
            pcfFactor: 1
        }
        DirectionalLight { eulerRotation.x: -60; eulerRotation.y: 145; brightness: 0.34 }
        DirectionalLight { eulerRotation.x: -22; eulerRotation.y: 18; brightness: 0.26 }

        Model {  // the table the plan lies on
            source: "#Cube"
            position: Qt.vector3d(0, -3.0, 0)
            scale: Qt.vector3d(root.boardW * 1.22 / 100, 0.02, root.boardH * 1.3 / 100)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColor: LabTheme.paper
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }

        Model {  // the plan sheet - the only pickable model; everything maps through it
            id: sheet
            source: "#Cube"
            pickable: true
            position: Qt.vector3d(0, -0.4, 0)
            scale: Qt.vector3d(root.boardW / 100, 0.008, root.boardH / 100)
            materials: PrincipledMaterial {
                baseColor: LabTheme.paperDeep
                roughness: 1.0; metalness: 0.0; specularAmount: 0.0
            }
        }
        Box3D {  // the sheet's ink rim
            width: root.boardW + 2.4; height: 0.9; depth: root.boardH + 2.4
            position: Qt.vector3d(0, -1.3, 0)
            color: LabTheme.ink
            useToonShading: true
        }

        // Plan grid: crosses while the grid snaps, dots when placement is
        // free - the sheet itself says which mode you are in (grafli's cue).
        Repeater3D {
            model: root.cols * root.rows
            Model {
                required property int index
                source: root.snapToGrid ? "#Cube" : "#Cylinder"
                castsShadows: false
                position: Qt.vector3d(
                    (index % root.cols - (root.cols - 1) / 2) * root.cell, 0.02,
                    (Math.floor(index / root.cols) - (root.rows - 1) / 2) * root.cell)
                scale: root.snapToGrid ? Qt.vector3d(0.010, 0.0006, 0.010)
                                       : Qt.vector3d(0.008, 0.0008, 0.008)
                materials: PrincipledMaterial {
                    baseColor: LabTheme.grid
                    lighting: PrincipledMaterial.NoLighting
                }
            }
        }

        Streets3D {
            id: streets
            net: root.net
            surfaceY: 0.07
            showLanes: root.showLanes
            hoveredRoad: root.hoverHit && root.hoverHit.kind === "road"
                         ? root.hoverHit.id : -1
            selectedRoad: root.selectedRoad
            eraser: root.eraser
            flowTime: clock.time
            flowRev: root.flowRev
            flowOf: function (i) {
                return i < root.laneFlow.length ? root.laneFlow[i] : 0
            }
        }

        // Dead ends get a mark of their own: a barrier laid ACROSS the road,
        // the way a real one is. This is where journeys end, and noticing that
        // is most of what the lab is for.
        Repeater3D {
            model: { root.graphRev; return LaneModel.deadEnds(root.net) }
            Node {
                required property var modelData
                position: Qt.vector3d(modelData.x, 0, modelData.z)
                eulerRotation.y: modelData.yaw * 180 / Math.PI
                Box3D {
                    width: modelData.width * 0.94; height: 0.7; depth: 0.9
                    position: Qt.vector3d(0, 0.1, 0)
                    color: LabTheme.accent
                    useToonShading: true
                }
            }
        }

        Cars3D {
            id: cars3d
            net: root.net
            roadY: 0.09
            capacity: 160
        }

        // the road being dragged out, previewed at its real width
        MultiLine3D {
            visible: root.drawFrom !== null && root.drawTo !== null
            orientation: LineBatch3D.Flat
            coords: {
                if (!root.drawFrom || !root.drawTo) return []
                return [[Qt.vector3d(root.drawFrom.x, 0.16, root.drawFrom.z),
                         Qt.vector3d(root.drawTo.x, 0.16, root.drawTo.z)]]
            }
            color: root.drawValid ? LabTheme.secondary : LabTheme.alarm
            width: root.newLanes * LaneModel.LANE_W * 2
        }
    }

    // --- mouse -------------------------------------------------------------
    // Left drag DRAWS - it is what this lab is for. The view is on the right
    // button, so building never fights with looking.
    MouseArea {
        id: planMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool orbiting: false
        property var dragNode: null
        property real lastX: 0
        property real lastY: 0

        function snapping(mods) {
            return root.snapToGrid !== ((mods & Qt.AltModifier) !== 0)
        }
        function worldAt(mx, my) {
            const res = view3d.pick(mx, my)
            if (res && res.objectHit === sheet) return res.scenePosition
            return null
        }
        function snapped(w, mods) {
            return snapping(mods)
                ? { x: Math.round(w.x / root.cell) * root.cell,
                    z: Math.round(w.z / root.cell) * root.cell }
                : { x: w.x, z: w.z }
        }

        onWheel: (wheel) => rig.zoomBy(wheel.angleDelta.y > 0 ? 0.88 : 1.14)

        // The gesture lives in three named functions rather than in the signal
        // handlers, so a flow, a test or an agent can perform the SAME drag a
        // hand does - the inspector can synthesize a click but not a drag, and
        // drawing a road is the one thing this lab is for.
        function pressAt(mx, my, button, mods) {
            root.forceActiveFocus()
            lastX = mx; lastY = my
            orbiting = false; dragNode = null
            root.drawFrom = null; root.drawTo = null

            if (button === Qt.RightButton) { orbiting = true; return }

            const w = worldAt(mx, my)
            if (!w) { orbiting = true; return }
            const hit = root.hitAt(w.x, w.z)

            if (root.eraser) {
                if (hit && hit.kind === "road") root.removeRoad(hit.id)
                return
            }
            if (hit && hit.kind === "node") {
                root.selectedRoad = -1
                dragNode = hit.id
                return
            }
            if (hit && hit.kind === "road") {
                root.selectedRoad = hit.id
                return
            }
            // empty plan: start drawing
            root.selectedRoad = -1
            root.lastRefusal = ""
            root.drawFrom = snapped(w, mods)
            root.drawTo = root.drawFrom
        }

        function moveAt(mx, my, mods, isDown) {
            if (isDown && orbiting) {
                rig.orbitBy((mx - lastX) * 0.34, -(my - lastY) * 0.24)
                lastX = mx; lastY = my
                return
            }
            const w = worldAt(mx, my)
            if (!w) return
            root.cursorW = w
            if (isDown && dragNode !== null) {
                const p = snapped(w, mods)
                root.moveNode(dragNode, p.x, p.z)
                return
            }
            if (isDown && root.drawFrom) {
                root.drawTo = snapped(w, mods)
                return
            }
            root.hoverHit = root.hitAt(w.x, w.z)
        }

        function releaseAt() {
            if (root.drawFrom && root.drawTo) {
                const r = root.addRoad(root.drawFrom.x, root.drawFrom.z,
                                       root.drawTo.x, root.drawTo.z)
                if (r.ok && r.roads.length) root.selectedRoad = r.roads[0]
            }
            root.drawFrom = null; root.drawTo = null
            dragNode = null; orbiting = false
        }

        // Drag a road from one window point to another in one call - the whole
        // gesture, for scripts that cannot hold a button down.
        function dragRoad(x1, y1, x2, y2, mods) {
            pressAt(x1, y1, Qt.LeftButton, mods || 0)
            moveAt(x2, y2, mods || 0, true)
            releaseAt()
        }

        onPressed: (mouse) => pressAt(mouse.x, mouse.y, mouse.button, mouse.modifiers)
        onPositionChanged: (mouse) => moveAt(mouse.x, mouse.y, mouse.modifiers, pressed)
        onReleased: releaseAt()
    }

    // --- palette -----------------------------------------------------------
    Rectangle {
        id: palette
        x: 12; y: 12
        width: 214
        height: paletteCol.height + 20
        radius: LabTheme.radius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth

        Column {
            id: paletteCol
            x: 10; y: 10
            spacing: 5

            Text {
                text: LabLang.t("lab.title")
                color: LabTheme.primary; font.pixelSize: 13; font.bold: true
                font.letterSpacing: 1.4; font.family: LabTheme.monoFont
            }
            Text {
                text: Lab.scenario !== "" ? LabLang.t("scenario." + Lab.scenario)
                                          : LabLang.t("lab.empty")
                color: Lab.scenario !== "" ? LabTheme.accent : LabTheme.inkFaint
                font.pixelSize: 13; font.family: LabTheme.handFont
            }
            Item { width: 1; height: 4 }

            // the one button the lab is named for
            Rectangle {
                width: 194; height: 40; radius: 6
                color: root.held ? LabTheme.muted
                     : (root.running ? LabTheme.tertiary : LabTheme.secondary)
                border.color: root.held ? LabTheme.inkFaint
                     : (root.running ? LabTheme.forest : LabTheme.primary)
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: root.held ? LabLang.t("btn.held")
                        : LabLang.t(root.running ? "btn.stop" : "btn.simulate") + "   (S)"
                    color: "#ffffff"; font.pixelSize: 13; font.bold: true
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.running = !root.running }
            }

            // how wide the NEXT road will be - the road already on the plan is
            // changed on its own card instead
            Row {
                spacing: 5
                Repeater {
                    model: [1, 2]
                    Rectangle {
                        required property int modelData
                        width: 94; height: 30; radius: 6
                        color: root.newLanes === modelData ? LabTheme.paperDeep : LabTheme.paper
                        border.color: root.newLanes === modelData ? LabTheme.secondary
                                                                  : LabTheme.panelEdge
                        border.width: LabTheme.borderWidth
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.t(modelData === 1 ? "road.oneLane.short"
                                                            : "road.twoLanes.short")
                            width: 86; horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: LabTheme.inkSoft; font.pixelSize: 10
                            font.family: LabTheme.monoFont
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.newLanes = modelData }
                    }
                }
            }

            Rectangle {
                width: 194; height: 32; radius: 6
                color: root.eraser ? LabTheme.clay : LabTheme.paper
                border.color: root.eraser ? LabTheme.alarm : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    width: 186; horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t(root.eraser ? "tool.erase.on" : "tool.erase") + "  (E)"
                    color: root.eraser ? "#ffffff" : LabTheme.inkSoft
                    font.pixelSize: 11; font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.eraser = !root.eraser }
            }

            Repeater {
                model: [
                    { key: "lanes", on: "btn.lanes.on", off: "btn.lanes.off" },
                    { key: "values", on: "btn.values.on", off: "btn.values.off" },
                    { key: "grid", on: "btn.grid.snap", off: "btn.grid.free" }
                ]
                Rectangle {
                    required property var modelData
                    readonly property bool state: modelData.key === "lanes" ? root.showLanes
                        : (modelData.key === "values" ? root.showValues : root.snapToGrid)
                    width: 194; height: 28; radius: 6
                    color: LabTheme.paper
                    border.color: state ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        anchors.centerIn: parent
                        width: 186; horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: LabLang.t(parent.state ? modelData.on : modelData.off)
                        color: LabTheme.inkSoft; font.pixelSize: 10
                        font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.key === "lanes") root.showLanes = !root.showLanes
                            else if (modelData.key === "values") root.showValues = !root.showValues
                            else root.snapToGrid = !root.snapToGrid
                        }
                    }
                }
            }

            Rectangle {
                width: 194; height: 28; radius: 6
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t("btn.clear") + "  (C)"
                    color: LabTheme.inkSoft; font.pixelSize: 10
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearPlan() }
            }
            Rectangle {
                width: 194; height: 28; radius: 6
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: LabLang.tf("btn.view", Math.round(((rig.yaw % 360) + 360) % 360))
                    color: LabTheme.inkSoft; font.pixelSize: 10
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.framePlan() }
            }
        }
    }

    // --- compass: which way the plan faces while you circle it -------------
    Rectangle {
        id: compass
        x: 12; y: palette.y + palette.height + 10
        width: 68; height: 68; radius: 34
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth
        Rectangle {
            anchors.centerIn: parent
            width: 40; height: 26; radius: 3
            color: LabTheme.paperDeep
            border.color: LabTheme.ink; border.width: 1.5
            rotation: -rig.yaw
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 14; height: 3
                color: LabTheme.accent
            }
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            width: 8; height: 8; radius: 4
            color: LabTheme.secondary
        }
    }

    // --- language ----------------------------------------------------------
    LangSwitch {
        id: langSwitch
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
    }

    // --- parameters --------------------------------------------------------
    ParamPanel {
        id: params
        anchors.right: parent.right
        anchors.top: langSwitch.bottom
        anchors.rightMargin: 12
        anchors.topMargin: 10
        width: 232
    }

    // --- network stats -----------------------------------------------------
    Rectangle {
        id: stats
        anchors.right: parent.right
        anchors.top: params.bottom
        anchors.rightMargin: 12
        anchors.topMargin: 10
        width: 232
        height: statsCol.height + 18
        radius: LabTheme.radius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth

        Column {
            id: statsCol
            x: 11; y: 9
            spacing: 3
            width: parent.width - 22

            Text {
                text: LabLang.t("stats.title")
                color: LabTheme.primary; font.pixelSize: 11; font.bold: true
                font.letterSpacing: 1.4; font.family: LabTheme.monoFont
            }
            // the derivation in one line: what you drew, and what it became
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                    root.graphRev
                    return root.graph.roads.length + " " + LabLang.t("traffic.roads")
                         + "  ->  " + root.net.stats.lanes + " " + LabLang.t("traffic.lanes")
                         + ", " + root.net.stats.connectors + " " + LabLang.t("traffic.turns")
                }
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Text {
                width: parent.width
                text: {
                    root.graphRev
                    return root.net.stats.junctions + " " + LabLang.t("traffic.junctions")
                         + " · " + root.net.stats.deadEnds + " " + LabLang.t("traffic.deadEnds")
                }
                color: LabTheme.inkFaint; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Item { width: 1; height: 4 }
            // where the cars are: rolling or standing. At low density the bar
            // is all one colour; turn density up and the split IS the lesson.
            BudgetBar {
                width: parent.width
                unit: ""
                decimals: 0
                // simState is mutated in place by the sim, so reading
                // cars.length alone never re-evaluates - it froze at 1 and the
                // bar drew a single full-width segment. Every binding that
                // reads the sim needs the revision counter.
                total: { root.flowRev; return Math.max(1, root.simState.cars.length) }
                segments: {
                    root.simRev; root.flowRev
                    const n = root.simState.cars.length
                    const stopped = Math.round(Traffic.stoppedShare(root.simState) * n)
                    return [{ label: LabLang.t("stats.moving"), value: n - stopped,
                              color: LabTheme.tertiary },
                            { label: LabLang.t("stats.waiting"), value: stopped,
                              color: LabTheme.accent }]
                }
            }
            Text {
                width: parent.width
                text: {
                    root.flowRev
                    return LabLang.t("stats.meanSpeed") + "  "
                         + LabLang.num(Traffic.meanSpeed(root.simState), 1) + " u/s"
                }
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            // Cars held vs cars asked for. Turn the demand up far enough and
            // these stop tracking each other: a spawn needs a clear gap, so
            // past a point the network simply will not take more traffic. That
            // gap IS the network's capacity, and it is the second lesson.
            Text {
                readonly property int asked: {
                    root.graphRev; root.flowRev
                    return Traffic.targetCount(root.net, root.simParams())
                }
                readonly property bool saturated: {
                    root.flowRev
                    return asked > 0 && root.simState.cars.length < asked * 0.82
                }
                visible: { root.flowRev; return root.running
                           || root.simState.cars.length > 0 }
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                    root.flowRev
                    const s = LabLang.tf("stats.asked", root.simState.cars.length, asked)
                    return saturated ? s + " — " + LabLang.t("stats.atCapacity") : s
                }
                color: saturated ? LabTheme.accent : LabTheme.inkSoft
                font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    root.flowRev
                    return LabLang.t("stats.arrived") + "  " + root.simState.gone
                }
                color: LabTheme.inkFaint; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
        }
    }

    // --- the lane graph: the same model, drawn as what it IS ---------------
    // The plan shows what you built; this shows how a car sees it - nodes,
    // one arrow per lane, and the turns that join them. Both read the same
    // model, so they can never disagree.
    Rectangle {
        id: planPanel
        visible: root.showPlan
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 44
        width: 258
        height: 190
        radius: LabTheme.radius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge; border.width: LabTheme.borderWidth

        Text {
            x: 12; y: 8
            text: LabLang.t("plan.title")
            color: LabTheme.primary; font.pixelSize: 11; font.bold: true
            font.letterSpacing: 1.4; font.family: LabTheme.monoFont
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 12; y: 8
            text: "M"
            color: LabTheme.inkFaint; font.pixelSize: 11
            font.family: LabTheme.monoFont
        }

        Canvas {
            id: planCanvas
            anchors.fill: parent
            anchors.topMargin: 24
            anchors.margins: 9

            readonly property int rev: root.graphRev * 7 + root.selectedRoad * 7919
                                       + root.flowRev
            onRevChanged: requestPaint()
            Connections {
                target: root
                function onHoverHitChanged() { planCanvas.requestPaint() }
                function onShowPlanChanged() { planCanvas.requestPaint() }
            }

            // fits what exists, not the whole sheet: an empty plan would
            // otherwise squeeze the graph into a corner
            readonly property var fit: {
                root.graphRev
                const pad = 16
                const b = RoadGraph.bounds(root.graph)
                const spanX = Math.max(20, b.x1 - b.x0)
                const spanZ = Math.max(20, b.z1 - b.z0)
                const s = Math.min((width - 2 * pad) / spanX, (height - 2 * pad) / spanZ)
                return { s: s, ox: width / 2, oy: height / 2,
                         cx: (b.x0 + b.x1) / 2, cy: (b.z0 + b.z1) / 2, empty: b.empty }
            }
            function px(x) { return fit.ox + (x - fit.cx) * fit.s }
            function py(z) { return fit.oy + (z - fit.cy) * fit.s }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                if (fit.empty) {
                    ctx.fillStyle = LabTheme.inkFaint.toString()
                    ctx.font = "12px sans-serif"
                    ctx.textAlign = "center"
                    ctx.fillText(LabLang.t("plan.empty"), width / 2, height / 2)
                    return
                }

                // One arrow per lane, pushed out to its own side of the road by
                // a FIXED number of pixels rather than by its true offset: at
                // panel scale the real half-lane is well under a pixel, so a
                // faithful miniature would draw the two directions on top of
                // each other and lose the one thing this view exists to show.
                const SEP = 2.6
                for (let i = 0; i < root.net.lanes.length; ++i) {
                    const L = root.net.lanes[i]
                    const sel = L.roadId === root.selectedRoad
                    const busy = i < root.laneFlow.length ? root.laneFlow[i] : 0
                    const nx = -L.uz * SEP, ny = L.ux * SEP     // to the lane's right
                    const ax = px(L.x0) + nx, ay = py(L.z0) + ny
                    const bx = px(L.x1) + nx, by = py(L.z1) + ny
                    ctx.strokeStyle = (L.terminal ? LabTheme.accent
                                     : sel ? LabTheme.secondary
                                     : busy > 0.05 ? LabTheme.teal
                                     : LabTheme.muted).toString()
                    ctx.lineWidth = sel ? 2.2 : (1.0 + busy * 1.6)
                    ctx.beginPath()
                    ctx.moveTo(ax, ay)
                    ctx.lineTo(bx, by)
                    ctx.stroke()
                    // arrowhead: direction is the whole point of a lane
                    const a = Math.atan2(by - ay, bx - ax)
                    ctx.beginPath()
                    ctx.moveTo(bx, by)
                    ctx.lineTo(bx - 5 * Math.cos(a - 0.4), by - 5 * Math.sin(a - 0.4))
                    ctx.lineTo(bx - 5 * Math.cos(a + 0.4), by - 5 * Math.sin(a + 0.4))
                    ctx.closePath()
                    ctx.fillStyle = ctx.strokeStyle
                    ctx.fill()
                }

                // the turns, faint: they are what makes it a graph rather than
                // a heap of arrows
                ctx.strokeStyle = LabTheme.panelEdge.toString()
                ctx.lineWidth = 0.9
                for (const C of root.net.connectors) {
                    ctx.beginPath()
                    ctx.moveTo(px(C.pts[0]), py(C.pts[1]))
                    for (let p = 1; p < C.pts.length / 2; ++p)
                        ctx.lineTo(px(C.pts[p * 2]), py(C.pts[p * 2 + 1]))
                    ctx.stroke()
                }

                // nodes: a junction is a filled dot, a dead end an open ring
                for (const nd of root.net.nodes) {
                    const dead = nd.degree === 1
                    ctx.beginPath()
                    ctx.arc(px(nd.x), py(nd.z), dead ? 3.4 : 2.6 + nd.degree * 0.5, 0,
                            2 * Math.PI)
                    if (dead) {
                        ctx.strokeStyle = LabTheme.accent.toString()
                        ctx.lineWidth = 1.8
                        ctx.stroke()
                    } else {
                        ctx.fillStyle = (nd.degree >= 3 ? LabTheme.primary
                                                        : LabTheme.inkFaint).toString()
                        ctx.fill()
                    }
                }
            }
        }
    }

    // --- flow numbers ------------------------------------------------------
    // The toggle that states the lesson: with V on, every road shows what is
    // actually flowing along it, so a grid and a tree of cul-de-sacs stop
    // needing to be explained.
    Repeater {
        model: root.showValues ? root.net.roads : []
        WorldLabel {
            required property var modelData
            view: view3d
            camera: rig.camera
            worldPosition: Qt.vector3d((modelData.x0 + modelData.x1) / 2, 1.2,
                                       (modelData.z0 + modelData.z1) / 2)
            placement: WorldLabel.Centered
            accent: LabTheme.panelEdge
            text: {
                root.flowRev
                return LabLang.num(Traffic.roadRate(root.simState, modelData.id), 0)
                     + LabLang.t("unit.perMin")
            }
        }
    }

    // --- watch marks -------------------------------------------------------
    Repeater {
        model: root.watch
        WorldLabel {
            required property var modelData
            readonly property int rid: modelData
            view: view3d
            camera: rig.camera
            worldPosition: {
                root.graphRev
                const m = root.roadMidpoint(rid)
                return Qt.vector3d(m.x, 3.0, m.z)
            }
            placement: WorldLabel.Above
            accent: root.watchColorOf(rid)
            visible: active && onScreen && root.roadRecord(rid) !== null
            Row {
                spacing: 4
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 4
                    color: root.watchColorOf(rid)
                }
                Text {
                    text: { root.graphRev; return root.roadLabel(rid) }
                    color: LabTheme.inkSoft; font.pixelSize: 10; font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
        }
    }

    // --- selection card ----------------------------------------------------
    WorldLabel {
        id: selCard
        readonly property var road: {
            root.graphRev
            return root.selectedRoad === -1 ? null : root.roadRecord(root.selectedRoad)
        }
        view: view3d
        camera: rig.camera
        active: road !== null
        worldPosition: road ? Qt.vector3d((road.x0 + road.x1) / 2, 0,
                                          (road.z0 + road.z1) / 2)
                            : Qt.vector3d(0, 0, 0)
        placement: WorldLabel.Below
        gap: 10
        accent: LabTheme.secondary

        Column {
            spacing: 3
            Text {
                text: {
                    root.graphRev
                    if (!selCard.road) return ""
                    return LabLang.t("card.road") + " " + root.roadLabel(selCard.road.id)
                }
                color: LabTheme.primary; font.pixelSize: 11; font.bold: true
                font.letterSpacing: 1.0; font.family: LabTheme.monoFont
            }
            Text {
                text: {
                    root.flowRev; root.graphRev
                    if (!selCard.road) return ""
                    return LabLang.t("card.flow") + " "
                         + LabLang.num(Traffic.roadRate(root.simState, selCard.road.id), 0)
                         + LabLang.t("unit.perMin") + "   ·   "
                         + LabLang.t("card.load") + " "
                         + root.carsOnRoad(selCard.road.id)
                }
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            // the per-object control: this road's own lane count
            Row {
                spacing: 4
                Repeater {
                    model: [1, 2]
                    Rectangle {
                        required property int modelData
                        readonly property bool on:
                            selCard.road !== null && selCard.road.lanes === modelData
                        width: 92; height: 20; radius: 5
                        color: on ? LabTheme.secondary : LabTheme.paper
                        border.color: on ? LabTheme.secondary : LabTheme.panelEdge
                        border.width: 1.5
                        Text {
                            anchors.centerIn: parent
                            // short form: the card already says ROAD, and the
                            // German long form does not fit a chip
                            text: LabLang.t(modelData === 1 ? "road.oneLane.short"
                                                            : "road.twoLanes.short")
                            width: 86; horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: parent.on ? LabTheme.paper : LabTheme.inkSoft
                            font.pixelSize: 9; font.family: LabTheme.monoFont
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (selCard.road)
                                root.setRoadLanes(selCard.road.id, modelData)
                        }
                    }
                }
            }
            Rectangle {
                readonly property bool watched:
                    selCard.road !== null && root.isWatched(selCard.road.id)
                readonly property bool full:
                    !watched && root.watch.length >= root.watchMax
                width: watchLabel.width + 16; height: 20
                radius: LabTheme.radius
                color: watched ? root.watchColorOf(selCard.road.id) : LabTheme.panel
                border.color: watched || full ? LabTheme.panelEdge : LabTheme.secondary
                border.width: 1.5
                Text {
                    id: watchLabel
                    anchors.centerIn: parent
                    text: LabLang.t(parent.watched ? "card.watched"
                        : (parent.full ? "card.watch.full" : "card.watch"))
                    color: parent.watched ? LabTheme.paper
                         : (parent.full ? LabTheme.inkFaint : LabTheme.secondary)
                    font.pixelSize: 11; font.family: LabTheme.handFont
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !parent.full
                    onClicked: if (selCard.road) root.toggleWatch(selCard.road.id)
                }
            }
            Text {
                text: LabLang.t("card.hint.road")
                color: LabTheme.inkFaint; font.pixelSize: 11
                font.family: LabTheme.handFont
            }
        }
    }

    // --- banner ------------------------------------------------------------
    Rectangle {
        readonly property bool allDead:
            root.net.stats.lanes > 0 && root.net.stats.connectors === 0
        readonly property bool jammed: {
            root.flowRev
            return root.running && root.simState.cars.length > 4
                   && Traffic.stoppedShare(root.simState) > 0.65
        }
        id: banner
        visible: allDead || jammed
        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        // Capped against the panels on both sides, never against the text: a
        // width that read back from the label it sizes would be a loop, and a
        // German banner is routinely a quarter longer than the English one.
        width: Math.min(340, root.width - 2 * (palette.width + 40))
        height: 34; radius: 8
        color: jammed ? LabTheme.alarm : LabTheme.highlight
        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            text: LabLang.t(banner.jammed ? "banner.jammed" : "banner.allDeadEnds")
            color: banner.jammed ? "#ffffff" : LabTheme.ink
            font.pixelSize: 13; font.bold: true
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
            // centred, so it may only grow until it would reach the monitor -
            // a longer translation is clipped, never overlapped
            width: Math.min(implicitWidth, 2 * (plot.x - 8 - root.width / 2) - 30)
            elide: Text.ElideRight
            color: LabTheme.inkSoft; font.pixelSize: 15
            font.family: LabTheme.handFont
            text: {
                if (root.lastRefusal === "short") return LabLang.t("hint.tooShort")
                if (root.eraser) return LabLang.t("hint.erasing")
                if (root.drawFrom) return LabLang.t("hint.drawing")
                if (root.selectedRoad !== -1) return LabLang.t("hint.selected")
                if (root.running) return LabLang.t("hint.running")
                return LabLang.t("hint.idle")
            }
        }
    }

    // --- monitor -----------------------------------------------------------
    Row {
        anchors.bottom: plot.top; anchors.bottomMargin: 6
        anchors.right: plot.right
        spacing: 6
        Repeater {
            model: root.watchQuantities
            Rectangle {
                required property var modelData
                readonly property bool active: modelData.key === root.watchQuantity
                width: chipLabel.width + 16; height: 22
                radius: LabTheme.radius
                color: active ? LabTheme.secondary : LabTheme.panel
                border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: LabLang.t(modelData.label)
                         + (modelData.unit ? " (" + modelData.unit + ")" : "")
                    color: parent.active ? LabTheme.paper : LabTheme.inkSoft
                    font.pixelSize: 12; font.family: LabTheme.handFont
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.watchQuantity = modelData.key
                }
            }
        }
    }

    Plot2D {
        id: plot
        anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 10
        width: 340; height: 142
        windowSeconds: 40
        series: {
            root.graphRev
            return root.watch.map((id, i) => ({
                probe: "road" + id,
                label: root.roadLabel(id),
                color: LabTheme.seriesColors[i % LabTheme.seriesColors.length] }))
        }
        placeholder: LabLang.t("plot.empty")
        onSeriesClicked: (probe) => root.setWatched(parseInt(probe.substring(4)), false)
    }

    // --- keys --------------------------------------------------------------
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_1) applyScenario("crossroads")
        else if (ev.key === Qt.Key_2) applyScenario("grid")
        else if (ev.key === Qt.Key_3) applyScenario("cul-de-sac")
        else if (ev.key === Qt.Key_4) applyScenario("ring")
        else if (ev.key === Qt.Key_S) running = !running
        else if (ev.key === Qt.Key_C) clearPlan()
        else if (ev.key === Qt.Key_E) eraser = !eraser
        else if (ev.key === Qt.Key_L) showLanes = !showLanes
        else if (ev.key === Qt.Key_V) showValues = !showValues
        else if (ev.key === Qt.Key_M) showPlan = !showPlan
        else if (ev.key === Qt.Key_W) { if (selectedRoad !== -1) toggleWatch(selectedRoad) }
        else if (ev.key === Qt.Key_Escape) {
            eraser = false; selectedRoad = -1; drawFrom = null; drawTo = null
        }
        else if (ev.key === Qt.Key_NumberSign || ev.key === Qt.Key_G)
            snapToGrid = !snapToGrid
        else if (ev.key === Qt.Key_Delete || ev.key === Qt.Key_Backspace) {
            if (selectedRoad !== -1) removeRoad(selectedRoad)
        }
        else if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ShiftModifier))
            recorder.recording = !recorder.recording
        // --- view ---
        else if (ev.key === Qt.Key_Left) rig.orbitBy(-6, 0)
        else if (ev.key === Qt.Key_Right) rig.orbitBy(6, 0)
        else if (ev.key === Qt.Key_Up) rig.orbitBy(0, 4)
        else if (ev.key === Qt.Key_Down) rig.orbitBy(0, -4)
        else if (ev.key === Qt.Key_Plus || ev.key === Qt.Key_Equal) rig.zoomBy(0.88)
        else if (ev.key === Qt.Key_Minus) rig.zoomBy(1.14)
        else if (ev.key === Qt.Key_F) frameSelection()
        else if (ev.key === Qt.Key_0 || ev.key === Qt.Key_Home) framePlan()
    }
}
