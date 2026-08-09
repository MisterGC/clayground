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
// Interaction, in one rule: A CLICK SELECTS, A DRAG DRAWS. Drag from open
// ground, from a dead end (that is how you join two of them), or off the middle
// of a road (that is how you get a T). Select a junction and its turns become
// clickable, so single movements can be closed - directed, so A->B and B->A are
// separate. Moving a node is a second act: select it, then drag it.
//
// Keys: 1..4 scenarios · S simulate · C clear · E erase · L lane model ·
// V flow numbers · M lane graph · W plot the selected road · X close/open the
// selected junction · # grid mode · Del remove · Esc cancel · Shift+R record.
//
// There is no mode. The LEFT BUTTON IS ALWAYS THE PLAN'S: an empty hand draws
// a road on a drag and selects on a click, and whatever is on the belt (H)
// takes the click instead while it is out. Navigation never competes for it -
// right-drag turns the world about the point under the cursor, a right CLICK
// puts down whatever is in the hand, the middle button drags the world, the
// wheel zooms towards the cursor, double-click on bare sheet re-centres there,
// and holding Space pans on the left button while held. Arrows travel,
// Shift+arrows turn, +/- zoom, F frames, 0 resets.
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
    // Fixed steps are the clock's job: a variable frame time would make the
    // run depend on the machine it ran on, and the whole lab rests on the sim
    // being a pure function of clock.time.
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.25
        timeScale: root.running ? Lab.p("simSpeed") : 0
        fixedStep: 1 / 60
        onStepped: (dt) => root.stepSim(dt)
    }

    property int _stepsTaken: 0

    Connections {
        target: clock
        function onWasReset() {
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
    // The throughput of a plan whose journeys have somewhere to end: cars
    // reaching a house, per minute, smoothed over the kit's 12 s window. Flat
    // zero without houses, which is the honest reading - nothing arrives
    // anywhere when there is nowhere to arrive.
    Probe {
        name: "arrivals"; unit: "/min"
        expr: () => Traffic.arrivalRate(root.simState)
    }

    // Shift+R writes a scratch run record into the lab's own records/ dir. No
    // command: a frame-driven session cannot be regenerated, and the citable
    // records are the ones a committed driver steps out (see the clay-lab skill).
    DataRecorder {
        id: recorder
        lab: "street-network-101"
        destination: "labs/street-network-101/records/session.labrec"
    }

    // --- monitoring --------------------------------------------------------
    // The plotted set is the WATCHED set, and what you watch is a road you
    // picked off the plan - same act as selecting it, same colour on the board
    // as in the legend.
    // The plotted set is the WATCHED set, and what you watch is a road you
    // picked off the plan - same act as selecting it, same colour on the board
    // as in the legend. The mechanism is the kernel's WatchMonitor; what stays
    // here is what a road is worth right now.
    readonly property alias watch: monitor.watched

    // The monitor under a name the kernel's own widgets can reach. A WatchChip
    // and a WatchMark both declare a property CALLED monitor, which shadows the
    // id inside them - `monitor: monitor` there is a property assigned to
    // itself, and it fails silently as an invisible chip.
    readonly property alias watchMonitor: monitor

    function watchValueOf(roadId) {
        if (monitor.quantity === "flow") return Traffic.roadRate(simState, roadId)
        var n = 0, sum = 0
        for (const c of simState.cars) {
            if (c.kind !== 0) continue
            if (net.lanes[c.idx].roadId !== roadId) continue
            ++n; sum += c.v
        }
        if (monitor.quantity === "load") return n
        return n ? sum / n : 0
    }
    function isWatched(id) { return monitor.isWatched(id) }
    function watchColorOf(id) { return monitor.colorOf(id) }
    function setWatched(id, on) { monitor.setWatched(id, on) }
    function toggleWatch(id) { monitor.toggle(id) }
    function watchOnly(ids) { monitor.watchOnly(ids) }

    // --- the network -------------------------------------------------------
    property var graph: RoadGraph.empty()
    property var net: LaneModel.derive(RoadGraph.empty())
    property var simState: Traffic.createState()
    property int graphRev: 0        // bumped on every edit, bindings depend on it
    property int simRev: 0          // bumped when the car set is replaced wholesale
    property int flowRev: 0
    property var laneFlow: []       // per-lane relative business, 0..1

    property bool running: false

    // --- houses ------------------------------------------------------------
    // Four fixed places traffic comes from and goes to. Without them `demand`
    // spreads over lane length, so drawing more road quietly buys more cars and
    // "which network shape is better?" turns into "which one did I draw more
    // of". Pinning the houses - and with them the fleet size - is what makes
    // two plans over the same four points comparable, which is the whole reason
    // the studies under studies/ can be run at all.
    //
    // A house is a POINT, declared by a scenario or a study; it binds to
    // whatever node lands under it. It is not a destination anybody drives
    // TOWARDS: the sim has no routing, so a car leaving one house wanders until
    // it happens to reach a house. Every study using them has to say so.
    property var houses: []                 // [{x, z}] as declared
    readonly property real houseSnap: 9.0   // how close a node must be to count

    // Which nodes the declared houses actually landed on. Re-derived on every
    // graph edit, so declaring houses before drawing the roads works - which is
    // the order a study writes anyway.
    readonly property var houseNodes: {
        graphRev
        const out = []
        for (const h of houses) {
            const nd = RoadGraph.nearestNode(graph, h.x, h.z, houseSnap)
            if (nd && out.indexOf(nd.id) === -1) out.push(nd.id)
        }
        return out
    }
    // A house with no node under it is drawn differently rather than ignored
    // silently - "why is nothing moving?" should be answerable by looking.
    function houseNodeAt(h) {
        const nd = RoadGraph.nearestNode(graph, h.x, h.z, houseSnap)
        return nd ? nd.id : -1
    }
    // cars per house at demand 1.0; the fleet is then demand x this x houses
    readonly property int carsPerHouse: 10

    function setHouses(list) {
        const out = []
        for (const h of (list || []))
            out.push(Array.isArray(h) ? { x: h[0], z: h[1] } : { x: h.x, z: h.z })
        houses = out
        rebuild()
    }
    function houseLabel(i) { return String.fromCharCode(65 + i) }   // A, B, C, D

    // --- starting and stopping ---------------------------------------------
    // Stopping is not pausing: the cars dissolve and the plan is handed back
    // empty, because the reason to stop is to model without traffic in the way.
    // Starting seeds a fresh run from the seed, so the same plan always gives
    // the same traffic - which is what makes a before/after comparison mean
    // anything after you have changed the network.
    function startSim() {
        if (running) return
        drainAnim.stop()
        cars3d.fleetAlpha = 1.0
        clock.reset()          // clears cars, RNG and the plots
        running = true
    }
    function stopSim() {
        if (!running) return
        running = false        // freezes sim time immediately
        drainAnim.restart()    // then dissolve what is left, on the wall clock
    }
    function toggleSim() { running ? stopSim() : startSim() }

    NumberAnimation {
        id: drainAnim
        target: cars3d
        property: "fleetAlpha"
        from: 1.0; to: 0.0
        duration: 380
        easing.type: Easing.InQuad
        onFinished: {
            root.simState = Traffic.createState()
            root.simRev++
            root.refreshFlow()
            cars3d.cars = root.simState.cars
            cars3d.sync()
            cars3d.fleetAlpha = 1.0
        }
    }
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
        const hn = houseNodes
        if (hn.length) {
            p.houses = hn
            // With houses the fleet is pinned to the HOUSES, not to how much
            // road there is - see the houses block above for why that is the
            // difference between a comparison and a coincidence.
            p.target = Math.round(Lab.p("demand") * carsPerHouse * hn.length)
        }
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
    function snapWorld(v, modifiers) {
        return grid.quantize(v, modifiers === undefined ? Qt.NoModifier : modifiers)
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
        if (selectedRoad === id) clearSelection()
        monitor.setWatched(id, false)
        rebuild()
    }
    // Erasing a junction takes its roads with it - a bare node is not a thing
    // you can have, so removing one has to mean removing what met there.
    function removeNodeAndRoads(id) {
        const doomed = RoadGraph.incident(graph, id).map(r => r.id)
        if (!RoadGraph.removeNode(graph, id)) return
        clearSelection()
        monitor.prune(id => doomed.indexOf(id) === -1)
        rebuild()
    }
    function removeSelection() {
        if (selection.kind === "road") removeRoad(selection.id)
        else if (selection.kind === "node") removeNodeAndRoads(selection.id)
    }
    function setRoadLanes(id, n) {
        if (!RoadGraph.setLanes(graph, id, n)) return
        rebuild()
    }
    function clearPlan() {
        graph = RoadGraph.empty()
        // houses belong to the plan they were declared for; leaving them behind
        // would strand four markers on the next scenario's empty sheet
        houses = []
        simState = Traffic.createState()
        clearSelection()
        monitor.clear()
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
    function nodeRecord(id) {
        for (const nd of net.nodes) if (nd.id === id) return nd
        return null
    }
    function turnRecord(id) {
        return id >= 0 && id < net.connectors.length ? net.connectors[id] : null
    }

    // --- turn restrictions -------------------------------------------------
    // The movements at one junction, one row per (arriving road -> leaving
    // road) pair. Derived from the connectors, but collapsed to road pairs
    // because that is what a ban is keyed on: on a two-lane road the same
    // movement exists twice and must toggle as one thing.
    function movementsAt(nodeId) {
        const seen = {}, out = []
        for (const c of net.connectors) {
            if (c.node !== nodeId) continue
            const key = c.fromRoad + ">" + c.toRoad
            if (seen[key]) continue
            seen[key] = true
            out.push({ from: c.fromRoad, to: c.toRoad, turn: c.turn,
                       banned: c.banned, connector: c.id })
        }
        // stable order so the card does not reshuffle under the cursor
        out.sort((p, q) => p.from - q.from || p.to - q.to)
        return out
    }
    // The roads meeting at a node, in graph order, so the matrix's rows and
    // columns keep the same identity from one repaint to the next.
    function legsAt(nodeId) {
        return RoadGraph.incident(graph, nodeId).map(r => r.id)
    }
    // One cell of the matrix: the movement from one leg to another, or null
    // when there is none (the diagonal - a U-turn is never offered).
    function movementAt(nodeId, fromRoad, toRoad) {
        if (fromRoad === toRoad) return null
        for (const c of net.connectors) {
            if (c.node !== nodeId) continue
            if (c.fromRoad === fromRoad && c.toRoad === toRoad)
                return { from: fromRoad, to: toRoad, turn: c.turn,
                         banned: c.banned, connector: c.id }
        }
        return null
    }
    // Where to hang a leg's name: a little way out along the road from the
    // junction, so the label sits ON the leg it names rather than in the box.
    function legAnchor(nodeId, roadId) {
        const nd = nodeRecord(nodeId), r = roadRecord(roadId)
        if (!nd || !r) return Qt.vector3d(0, 0, 0)
        const away = r.a === nodeId ? 1 : -1
        const d = Math.min(r.length * 0.42, Math.max(nd.pad + 5, 11))
        return Qt.vector3d(nd.x + r.ux * away * d, 1.6, nd.z + r.uz * away * d)
    }
    readonly property var turnGlyphs: ({ straight: "↑", left: "←",
                                         right: "→", back: "↓" })

    function setTurnBanned(nodeId, fromRoad, toRoad, banned) {
        if (!RoadGraph.setBanned(graph, nodeId, fromRoad, toRoad, banned)) return
        rebuild()
    }
    function toggleTurnBanned(nodeId, fromRoad, toRoad) {
        setTurnBanned(nodeId, fromRoad, toRoad,
                      !RoadGraph.isBanned(graph, nodeId, fromRoad, toRoad))
    }
    // toggling by connector id: what clicking a curve in the 3D view does
    function toggleTurnByConnector(connId) {
        const c = turnRecord(connId)
        if (!c) return
        toggleTurnBanned(c.node, c.fromRoad, c.toRoad)
    }
    function turnLabel(m) {
        return roadLabel(m.from) + " → " + roadLabel(m.to)
    }
    // Close a whole junction, or open it again. Closing every movement makes
    // each arriving lane a dead end, which is a striking thing to be able to
    // do in one keystroke and see immediately.
    function junctionClosed(nodeId) {
        const ms = movementsAt(nodeId)
        return ms.length > 0 && ms.every(m => m.banned)
    }
    function toggleJunctionClosed() {
        const id = activeNode
        if (id === -1) return
        const close = !junctionClosed(id)
        for (const m of movementsAt(id))
            RoadGraph.setBanned(graph, id, m.from, m.to, close)
        rebuild()
    }

    // World-space hit test against the model - no per-model picking.
    //
    // Turn curves come FIRST, but only at the junction that is already
    // selected. That ordering is deliberate: a turn curve lives inside its
    // junction box, so if it were always hittable you could never click the
    // junction itself, and an idle click near a crossing would silently flip a
    // restriction. Select the junction, and only then do its turns respond.
    function hitAt(wx, wz) {
        if (activeNode !== -1) {
            // The node keeps a CORE that always wins. Every turn curve at a
            // junction passes through its middle, so without this the moment
            // you selected a junction its own centre became a turn: you could
            // no longer grab it to move it, and clicking it silently flipped a
            // restriction. The fan is clickable everywhere outside the core.
            const nd = nodeRecord(activeNode)
            if (nd && Math.hypot(nd.x - wx, nd.z - wz) < Math.max(2.2, nd.pad * 0.45))
                return { kind: "node", id: nd.id }
            let best = null, bd = 1.5
            for (const c of net.connectors) {
                if (c.node !== activeNode) continue
                const d = distToConnector(c, wx, wz)
                if (d < bd) { bd = d; best = c }
            }
            if (best) return { kind: "turn", id: best.id }
        }
        for (const nd of net.nodes) {
            if (Math.hypot(nd.x - wx, nd.z - wz) < Math.max(3.2, nd.pad * 0.75))
                return { kind: "node", id: nd.id }
        }
        for (const r of net.roads) {
            const d = distToRoad(r, wx, wz)
            if (d < r.width / 2 + 0.5) return { kind: "road", id: r.id }
        }
        return null
    }

    function distToRoad(r, wx, wz) {
        const dx = r.x1 - r.x0, dz = r.z1 - r.z0
        const len2 = dx * dx + dz * dz
        const t = len2 < 1e-9 ? 0
            : Math.max(0, Math.min(1, ((wx - r.x0) * dx + (wz - r.z0) * dz) / len2))
        return Math.hypot(r.x0 + t * dx - wx, r.z0 + t * dz - wz)
    }
    function distToConnector(c, wx, wz) {
        let best = Infinity
        for (let i = 0; i + 3 < c.pts.length; i += 2) {
            const ax = c.pts[i], az = c.pts[i + 1]
            const bx = c.pts[i + 2], bz = c.pts[i + 3]
            const dx = bx - ax, dz = bz - az
            const len2 = dx * dx + dz * dz
            const t = len2 < 1e-9 ? 0
                : Math.max(0, Math.min(1, ((wx - ax) * dx + (wz - az) * dz) / len2))
            best = Math.min(best, Math.hypot(ax + t * dx - wx, az + t * dz - wz))
        }
        return best
    }

    // What would an endpoint dropped here attach to? Drives the drawing
    // preview: the answer has to be visible BEFORE the mouse is released,
    // because "will this connect?" is the whole question when you are joining
    // two dead ends.
    readonly property real snapNodeRadius: 8.0     // forgiving: aiming is hard in 3D
    readonly property real snapRoadRadius: 4.0

    function snapTargetAt(wx, wz) {
        const nd = RoadGraph.nearestNode(graph, wx, wz, snapNodeRadius)
        if (nd) return { kind: "node", id: nd.id, x: nd.x, z: nd.z }
        const hit = RoadGraph.nearestRoad(graph, wx, wz, snapRoadRadius)
        if (hit) return { kind: "road", id: hit.road.id, x: hit.x, z: hit.z }
        return { kind: "free", id: -1, x: wx, z: wz }
    }

    // --- camera ------------------------------------------------------------
    function framePoints(pts) {
        if (!pts || !pts.length) {
            // one applyState, not a pivot write plus a setDistance: the rig
            // eases, so two writes would start two glides and the sheet would
            // slide sideways while it zoomed back out
            rig.applyState({ px: 0, py: 0, pz: 0, distance: 210 })
            return
        }
        rig.frame(pts, 1.12)
    }
    function frameAll() { framePlan() }   // the name LabKeys looks for
    function framePlan() {
        const pts = graph.nodes.map(n => Qt.vector3d(n.x, 0, n.z))
        framePoints(pts.length ? pts : null)
    }
    function frameSelection() {
        if (selection.kind === "road") {
            const r = roadRecord(selection.id)
            if (r) {
                framePoints([Qt.vector3d(r.x0, 0, r.z0), Qt.vector3d(r.x1, 0, r.z1)])
                return
            }
        }
        if (activeNode !== -1) {
            const nd = nodeRecord(activeNode)
            if (nd) {
                // a junction alone is a point; frame it with its legs so the
                // camera lands on something with extent
                const pts = [Qt.vector3d(nd.x, 0, nd.z)]
                for (const r of RoadGraph.incident(graph, nd.id)) {
                    const o = RoadGraph.nodeById(graph, r.a === nd.id ? r.b : r.a)
                    if (o) pts.push(Qt.vector3d((nd.x + o.x) / 2, 0, (nd.z + o.z) / 2))
                }
                framePoints(pts)
                return
            }
        }
        framePlan()
    }

    // --- interaction state -------------------------------------------------
    property bool eraser: false
    // grafli's grid contract: # cycles it, Alt inverts it for one gesture
    GridMode { id: grid; step: root.cell }
    readonly property bool snapToGrid: grid.snap
    property bool showLanes: true
    property bool showValues: false
    property bool showPlan: true
    property int newLanes: 1              // lane count for the next road drawn

    // One selection, three things it can be. A junction being selected is what
    // makes its turns editable, so this is not just a highlight.
    property var selection: ({ kind: "", id: -1 })
    readonly property int selectedRoad: selection.kind === "road" ? selection.id : -1
    readonly property int selectedNode: selection.kind === "node" ? selection.id : -1
    readonly property int selectedTurn: selection.kind === "turn" ? selection.id : -1
    // a selected turn keeps its junction lit, so the card and the curves stay put
    readonly property int activeNode: {
        if (selection.kind === "node") return selection.id
        if (selection.kind === "turn") {
            const c = turnRecord(selection.id)
            return c ? c.node : -1
        }
        return -1
    }
    function select(kind, id) { selection = { kind: kind, id: id } }
    function clearSelection() { selection = { kind: "", id: -1 } }

    property var hoverHit: null
    property var drawFrom: null           // {x, z} while a road is being dragged
    property var drawTo: null
    property var drawFromSnap: null       // what each end would attach to
    property var drawToSnap: null
    property string lastRefusal: ""
    property var cursorW: Qt.vector3d(0, 0, 0)

    readonly property bool drawValid: drawFrom !== null && drawTo !== null
        && Math.hypot(drawTo.x - drawFrom.x, drawTo.z - drawFrom.z) >= 7.0

    // --- serialization (the viewState convention) --------------------------
    function planState() {
        return { graph: RoadGraph.clone(graph), newLanes: newLanes,
                 houses: houses.map(h => ({ x: h.x, z: h.z })) }
    }
    function loadPlan(s) {
        graph = RoadGraph.clone(s.graph)
        if (s.newLanes) newLanes = s.newLanes
        houses = (s.houses || []).map(h => ({ x: h.x, z: h.z }))
        clearSelection()
        simState = Traffic.createState()
        rebuild()
    }
    function viewState() {
        return Object.assign(Lab.viewState(), {
            plan: planState(),
            watch: monitor.watched.slice(), watchQuantity: monitor.quantity,
            running: running, lang: LabLang.lang,
            toggles: { lanes: showLanes, values: showValues, plan: showPlan,
                       snap: grid.snap },
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
            showPlan = s.toggles.plan; grid.snap = s.toggles.snap
        }
        if (s.watchQuantity) monitor.quantity = s.watchQuantity
        if (s.watch) monitor.watchOnly(s.watch.filter(id => roadRecord(id) !== null))
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
            "houses":   (list) => setHouses(list),
            "remove":   (id) => removeRoad(id),
            "lanes":    (id, n) => setRoadLanes(id, n),
            "select":   (kind, id) => root.select(kind, id),
            "banTurn":  (node, from, to, on) =>
                            setTurnBanned(node, from, to, on !== false),
            "watch":    (id, on) => setWatched(id, on),
            "simulate": (on) => on === false ? stopSim() : startSim(),
            "clear":    () => clearPlan(),
            "scenario": (n) => applyScenario(n),
            "showLanes": (on) => { showLanes = on },
            "showValues": (on) => { showValues = on },
            "frame":    (what) => what === "selection" ? frameSelection() : framePlan(),
            "view":     (name) => rig.goTo(name)
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
        // Declared vs bound is the distinction that matters: a house floating
        // off the road network is why a run produced no traffic, and an agent
        // has to be able to see that without a screenshot.
        info.network.houses = {
            declared: houses.length, bound: houseNodes.length,
            nodes: houseNodes.slice(),
            at: houses.map((h, i) => ({ label: houseLabel(i), x: h.x, z: h.z,
                                        node: houseNodeAt(h) }))
        }
        info.traffic = Traffic.summary(net, simState, simParams())
        info.traffic.running = running
        // the inspector's time action can hold the whole engine; a lab that
        // reported "running" through that would send an agent hunting a
        // simulation bug that is really a paused clock
        info.traffic.heldByPause = running && Clayground.paused
        info.traffic.steps = _stepsTaken
        // language-neutral for agents: ids and types, not display labels
        info.network.bannedTurns = net.stats.bannedTurns
        info.ui = { selected: { kind: selection.kind, id: selection.id },
                    snap: grid.snap, eraser: eraser,
                    watching: monitor.watched.slice(), quantity: monitor.quantity,
                    lang: LabLang.lang }
        return info
    }
    function flagInfo() { return labInfo() }

    // --- 3D scene ----------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera

        // The whole stage - ground, light rig, environment - in one block. The
        // plan sheet is the shared lab surface: an endless sheet of squared
        // paper whose raster is drawn in the fragment shader, showing crosses
        // while the grid snaps and dots when placement is free. Everything the
        // mouse does maps through it (see worldAt).
        LabStage3D {
            id: stage
            cellSize: root.cell
            majorEvery: 5                 // a heavier rule every 50 units
            gridMode: grid
            workExtent: Qt.vector2d(root.boardW, root.boardH)
            shadowMapFar: 420             // measured: covers the plan at maxDistance 420
        }
        CameraAnchorMark { pointer: nav }
        // The tape measure, in the same screen space and for the same reason:
        // "how long is that road, and how sharp is that junction" is asked of
        // a plan constantly, and until now the only answer was counting grid
        // squares. The plan is in the lab's own units, so "u" it is.
        InstrumentBelt { id: hands; pointer: nav }
        environment: stage.environment

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
            // The pan leash. A plan is drawn edge to edge, so travelling has
            // to reach a full plan-width out - but no further, or the sheet
            // disappears behind you on an endless ground.
            homePivot: Qt.vector3d(0, 0, 0)
            panLeash: stage.workRadius
            viewpoints: ({
                "plan":  { yaw: 0, pitch: 52, distance: 210, px: 0, py: 0, pz: 0 },
                "top":   { yaw: 0, pitch: 86, distance: 260 },
                "kerb":  { pitch: 22, distance: 70 }
            })
        }

        Streets3D {
            id: streets
            net: root.net
            surfaceY: stage.overlayY(3)   // inside the stage's overlay budget
            showLanes: root.showLanes
            hoveredRoad: root.hoverHit && root.hoverHit.kind === "road"
                         ? root.hoverHit.id : -1
            hoveredTurn: root.hoverHit && root.hoverHit.kind === "turn"
                         ? root.hoverHit.id : -1
            selectedRoad: root.selectedRoad
            activeNode: root.activeNode
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

        // The houses: where journeys start and end once a study pins them down.
        // A body and a gable, nothing more - at this camera pitch a plain box
        // reads as a building only once it has a roof line, and a roof is one
        // box turned 45 degrees whose lower half hides inside the walls.
        //
        // A house that found no node under it is drawn in the muted grey and
        // sunk to the sheet, because it is doing nothing: no traffic will start
        // or end there, and that has to be visible rather than merely reported.
        Repeater3D {
            model: { root.graphRev; return root.houses }
            Node {
                required property var modelData
                required property int index
                // graphRev is READ, not merely implied: houseNodeAt() looks at
                // the graph inside a function call, which a binding cannot see,
                // so without this a house declared before its roads were drawn
                // stays "unbound" for ever - grey and flat next to a road that
                // is plainly there.
                readonly property bool bound: {
                    root.graphRev
                    return root.houseNodeAt(modelData) !== -1
                }
                position: Qt.vector3d(modelData.x, 0, modelData.z)
                Box3D {
                    width: 7.6; height: bound ? 4.4 : 1.0; depth: 7.6
                    position: Qt.vector3d(0, height / 2, 0)
                    color: bound ? LabTheme.clay : LabTheme.muted
                    useToonShading: true
                }
                Box3D {
                    visible: bound
                    width: 5.6; height: 5.6; depth: 8.0
                    position: Qt.vector3d(0, 6.2, 0)
                    eulerRotation.z: 45
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

        // What each end of the drag will ATTACH to. A ring means "joins this
        // node", a cross means "splits this road here", nothing means "a new
        // node in open ground". Without this the only way to find out was to
        // let go and see - which is exactly why joining two dead ends felt
        // impossible.
        Repeater3D {
            model: [root.drawFromSnap, root.drawToSnap]
            Node {
                required property var modelData
                visible: modelData !== null && modelData !== undefined
                         && modelData.kind !== "free"
                position: modelData ? Qt.vector3d(modelData.x, 0.2, modelData.z)
                                    : Qt.vector3d(0, -999, 0)
                // joins an existing node: a ring around it
                Model {
                    source: "#Cylinder"
                    visible: modelData && modelData.kind === "node"
                    castsShadows: false
                    scale: Qt.vector3d(0.115, 0.0002, 0.115)
                    materials: PrincipledMaterial {
                        baseColor: LabTheme.tertiary
                        lighting: PrincipledMaterial.NoLighting
                        opacity: 0.55; alphaMode: PrincipledMaterial.Blend
                    }
                }
                // splits a road: a cross on the spot
                Node {
                    visible: modelData && modelData.kind === "road"
                    Box3D {
                        width: 7.0; height: 0.4; depth: 0.7
                        position: Qt.vector3d(0, 0, 0)
                        color: LabTheme.tertiary
                        useToonShading: true
                    }
                    Box3D {
                        width: 0.7; height: 0.4; depth: 7.0
                        position: Qt.vector3d(0, 0, 0)
                        color: LabTheme.tertiary
                        useToonShading: true
                    }
                }
            }
        }

        // Every node that a road can be attached to wears a faint open ring
        // while you are drawing, so the plan says where the anchors ARE rather
        // than making you hunt for them.
        Repeater3D {
            model: root.drawFrom !== null ? root.net.nodes : []
            Model {
                required property var modelData
                source: "#Cylinder"
                castsShadows: false
                position: Qt.vector3d(modelData.x, 0.13, modelData.z)
                scale: Qt.vector3d(0.085, 0.0002, 0.085)
                materials: PrincipledMaterial {
                    baseColor: LabTheme.secondary
                    lighting: PrincipledMaterial.NoLighting
                    opacity: 0.22; alphaMode: PrincipledMaterial.Blend
                }
            }
        }

        // The junction being edited: a ring so it is obvious which crossing the
        // turn card belongs to.
        Model {
            readonly property var nd: {
                root.graphRev
                return root.activeNode === -1 ? null : root.nodeRecord(root.activeNode)
            }
            source: "#Cylinder"
            visible: nd !== null
            castsShadows: false
            position: nd ? Qt.vector3d(nd.x, 0.12, nd.z) : Qt.vector3d(0, -999, 0)
            scale: nd ? Qt.vector3d(nd.pad * 2.5 / 100, 0.0002, nd.pad * 2.5 / 100)
                      : Qt.vector3d(0.01, 0.0002, 0.01)
            materials: PrincipledMaterial {
                baseColor: LabTheme.secondary
                lighting: PrincipledMaterial.NoLighting
                opacity: 0.16; alphaMode: PrincipledMaterial.Blend
            }
        }
    }

    // --- navigation ---------------------------------------------------------
    // The camera gestures are the kernel's (OrbitInput3D), and so is the rule
    // for who owns which button. The rule is one sentence: the LEFT button is
    // never the camera's - not "not in build mode", not "not over a road", but
    // never, so a drag on this sheet always draws and a click always selects.
    // The camera gets the right button, the middle one, the wheel, the arrows,
    // and the left button only while Space is held.
    OrbitInput3D {
        id: nav
        rig: rig
        view: view3d
    }

    // --- mouse -------------------------------------------------------------
    // Left drag DRAWS - it is what this lab is for.
    MouseArea {
        id: planMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: nav.cursorShape
        property var dragNode: null

        // The grid mode owns both rules - Alt inverting the mode for one
        // gesture, and the rounding itself - so every lab quantizes alike.
        function snapping(mods) { return grid.snapping(mods) }
        function worldAt(mx, my) { return stage.worldAt(view3d, mx, my) }
        function snapped(w, mods) {
            return { x: grid.quantize(w.x, mods), z: grid.quantize(w.z, mods) }
        }

        onWheel: (wheel) => nav.wheel(wheel.angleDelta.y, wheel.x, wheel.y)

        onDoubleClicked: (mouse) => {
            // only over bare sheet: a double-click on a road or a junction is
            // the plan's, not the camera's
            const w = worldAt(mouse.x, mouse.y)
            if (w && !root.hitAt(w.x, w.z)) nav.recenterAt(mouse.x, mouse.y)
        }

        // The gesture lives in named functions rather than in the signal
        // handlers, so a flow, a test or an agent can perform the SAME drag a
        // hand does - the inspector can synthesize a click but not a drag, and
        // drawing a road is the one thing this lab is for.
        //
        // ONE RULE: a click selects, a drag draws. Nothing is decided on press,
        // because on press we do not yet know which it is - so the press only
        // remembers what it grabbed, and the first real movement commits. That
        // is what makes drawing FROM existing geometry possible: previously a
        // press on a node started moving it and a press on a road selected it,
        // so a road could only ever start in empty space, and joining two dead
        // ends was unreachable.
        //
        // Moving a node is therefore a second act: select it, then drag it.
        property var pressHit: null
        property var pressW: null
        property string mode: ""      // "" until the first movement decides

        function pressAt(mx, my, button, mods) {
            root.forceActiveFocus()
            nav.cancel()
            dragNode = null; mode = ""
            pressHit = null; pressW = null
            root.drawFrom = null; root.drawTo = null

            // Ask the camera first, and with the default buttons the answer for
            // the left button is always no - so nothing below thinks about the
            // camera again, and no press over the plan can be stolen by it.
            if (nav.begin(mx, my, button, mods) !== "") { mode = "nav"; return }
            // Then the hand: an instrument out means the click is the
            // instrument's, and it decides click-versus-drag itself.
            if (hands.held) { mode = "hand"; hands.press(mx, my); return }

            const w = worldAt(mx, my)
            // aimed at the sky: nothing to draw on, and nothing else to do
            if (!w) return

            const hit = root.hitAt(w.x, w.z)
            pressHit = hit
            pressW = { x: w.x, z: w.z }
            root.lastRefusal = ""

            // The eraser is a mode and acts immediately - a modal tool that
            // waited for a drag would feel broken.
            if (root.eraser) {
                mode = "erase"
                if (hit && hit.kind === "road") root.removeRoad(hit.id)
                else if (hit && hit.kind === "node") root.removeNodeAndRoads(hit.id)
                return
            }
        }

        // Where would a road started at this press begin? On a node, exactly
        // on it; on a road, at the point grabbed (which splits it, giving a T);
        // otherwise the snapped cursor.
        function drawOrigin(mods) {
            if (pressHit && pressHit.kind === "node") {
                const nd = RoadGraph.nodeById(root.graph, pressHit.id)
                if (nd) return { x: nd.x, z: nd.z }
            }
            if (pressHit && pressHit.kind === "road") return pressW
            return snapped(pressW, mods)
        }

        function moveAt(mx, my, mods, isDown) {
            if (isDown && mode === "nav") { nav.move(mx, my); return }
            if (isDown && mode === "hand") { hands.move(mx, my); return }
            if (!isDown) nav.hoverAt(mx, my)
            const w = worldAt(mx, my)
            if (!w) return
            root.cursorW = w

            if (!isDown) {
                root.hoverHit = root.hitAt(w.x, w.z)
                return
            }
            if (mode === "erase") return

            // First real movement decides what this gesture is
            if (mode === "" && pressW) {
                if (Math.hypot(w.x - pressW.x, w.z - pressW.z) < 1.6) return
                const grabbedSelectedNode = pressHit && pressHit.kind === "node"
                                            && root.selectedNode === pressHit.id
                if (grabbedSelectedNode) {
                    mode = "move"
                    dragNode = pressHit.id
                } else {
                    mode = "draw"
                    root.drawFrom = drawOrigin(mods)
                    root.drawFromSnap = root.snapTargetAt(root.drawFrom.x,
                                                          root.drawFrom.z)
                }
            }
            if (mode === "move" && dragNode !== null) {
                const p = snapped(w, mods)
                root.moveNode(dragNode, p.x, p.z)
                return
            }
            if (mode === "draw") {
                // The end follows what it would ATTACH to, not the raw cursor:
                // aim near a dead end and the preview jumps onto it, so "will
                // this connect?" is answered before the button comes up.
                const t = root.snapTargetAt(w.x, w.z)
                root.drawToSnap = t
                root.drawTo = t.kind === "free" ? snapped(w, mods)
                                               : { x: t.x, z: t.z }
            }
        }

        function releaseAt() {
            if (mode === "nav") {
                nav.end()          // a flicked drag coasts to a stop from here
                mode = ""; dragNode = null
                return
            }
            if (mode === "hand") {
                hands.release()    // a click measures, a drag was just a drag
                mode = ""; dragNode = null
                return
            }
            if (mode === "draw" && root.drawFrom && root.drawTo) {
                const r = root.addRoad(root.drawFrom.x, root.drawFrom.z,
                                       root.drawTo.x, root.drawTo.z)
                if (r.ok && r.roads.length) root.select("road", r.roads[0])
            } else if (mode === "" && pressHit !== null) {
                // never moved: this was a click, so it selects
                if (pressHit.kind === "turn") root.toggleTurnByConnector(pressHit.id)
                else root.select(pressHit.kind, pressHit.id)
            } else if (mode === "" && pressHit === null) {
                root.clearSelection()
            }
            root.drawFrom = null; root.drawTo = null
            root.drawFromSnap = null; root.drawToSnap = null
            dragNode = null; mode = ""
            pressHit = null; pressW = null
        }

        // Drag a road from one window point to another in one call - the whole
        // gesture, for scripts that cannot hold a button down.
        function dragRoad(x1, y1, x2, y2, mods) {
            pressAt(x1, y1, Qt.LeftButton, mods || 0)
            moveAt(x2, y2, mods || 0, true)
            releaseAt()
        }
        // A click, as one call: press and release with no movement between.
        function clickAt(x, y, mods) {
            pressAt(x, y, Qt.LeftButton, mods || 0)
            releaseAt()
        }

        onPressed: (mouse) => pressAt(mouse.x, mouse.y, mouse.button, mouse.modifiers)
        onPositionChanged: (mouse) => moveAt(mouse.x, mouse.y, mouse.modifiers, pressed)
        onReleased: releaseAt()
    }

    // A right CLICK is "put it down" - the RTS cancel. It empties the hand,
    // then leaves the eraser, then drops the selection, so one press walks back
    // one step. A right DRAG still turns the view and cancels nothing.
    Connections {
        target: nav
        function onCancelled() {
            if (!hands.empty) { hands.putAway(); return }
            if (root.eraser) { root.eraser = false; return }
            root.clearSelection()
        }
    }

    // --- palette -----------------------------------------------------------
    LabPanel {
        id: palette
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(214)
        title: LabLang.t("lab.title")
        spacing: LabTheme.px(5)

        // the presets, clickable, each carrying what it is worth noticing
        ScenarioBar {
            lab: root
            width: LabTheme.px(194)
        }
        Column {
            id: paletteCol
            spacing: LabTheme.px(5)

            // the one button the lab is named for
            Rectangle {
                width: LabTheme.px(194); height: LabTheme.px(40); radius: LabTheme.px(6)
                color: root.held ? LabTheme.muted
                     : (root.running ? LabTheme.tertiary : LabTheme.secondary)
                border.color: root.held ? LabTheme.inkFaint
                     : (root.running ? LabTheme.forest : LabTheme.primary)
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: root.held ? LabLang.t("btn.held")
                        : LabLang.t(root.running ? "btn.stop" : "btn.simulate") + "   (S)"
                    color: LabTheme.inkOn(parent.color); font.pixelSize: LabTheme.fontLabel; font.bold: true
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.toggleSim() }
            }

            // how wide the NEXT road will be - the road already on the plan is
            // changed on its own card instead
            Row {
                spacing: LabTheme.px(5)
                Repeater {
                    model: [1, 2]
                    Rectangle {
                        required property int modelData
                        width: LabTheme.px(94); height: LabTheme.px(30); radius: LabTheme.px(6)
                        color: root.newLanes === modelData ? LabTheme.paperDeep : LabTheme.paper
                        border.color: root.newLanes === modelData ? LabTheme.secondary
                                                                  : LabTheme.panelEdge
                        border.width: LabTheme.borderWidth
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.t(modelData === 1 ? "road.oneLane.short"
                                                            : "road.twoLanes.short")
                            width: LabTheme.px(86); horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontMicro
                            font.family: LabTheme.monoFont
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.newLanes = modelData }
                    }
                }
            }

            Rectangle {
                width: LabTheme.px(194); height: LabTheme.px(32); radius: LabTheme.px(6)
                color: root.eraser ? LabTheme.clay : LabTheme.paper
                border.color: root.eraser ? LabTheme.alarm : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    width: LabTheme.px(186); horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LabLang.t(root.eraser ? "tool.erase.on" : "tool.erase") + "  (E)"
                    color: LabTheme.inkOn(parent.color)
                    font.pixelSize: LabTheme.fontSmall; font.family: LabTheme.monoFont
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
                    width: LabTheme.px(194); height: LabTheme.px(28); radius: LabTheme.px(6)
                    color: LabTheme.paper
                    border.color: state ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        anchors.centerIn: parent
                        width: LabTheme.px(186); horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: LabLang.t(parent.state ? modelData.on : modelData.off)
                        color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontMicro
                        font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData.key === "lanes") root.showLanes = !root.showLanes
                            else if (modelData.key === "values") root.showValues = !root.showValues
                            else grid.toggle()
                        }
                    }
                }
            }

            Rectangle {
                width: LabTheme.px(194); height: LabTheme.px(28); radius: LabTheme.px(6)
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: LabLang.t("btn.clear") + "  (C)"
                    color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontMicro
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.clearPlan() }
            }
            Rectangle {
                width: LabTheme.px(194); height: LabTheme.px(28); radius: LabTheme.px(6)
                color: LabTheme.paper; border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    anchors.centerIn: parent
                    text: LabLang.tf("btn.view", Math.round(((rig.yaw % 360) + 360) % 360))
                    color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontMicro
                    font.family: LabTheme.monoFont
                }
                MouseArea { anchors.fill: parent; onClicked: root.framePlan() }
            }
        }
    }

    readonly property bool planUnderPalette:
        planPanel.y > palette.y + palette.height + LabTheme.px(16)

    // --- compass: which way the plan faces while you circle it -------------
    Compass {
        id: compass
        x: LabTheme.px(12); y: palette.y + palette.height + LabTheme.px(10)
        yaw: rig.yaw
        aspect: root.cols / root.rows
    }

    // --- language ----------------------------------------------------------
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

    // --- parameters --------------------------------------------------------
    ParamPanel {
        id: params
        anchors.right: parent.right
        anchors.top: topSwitches.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.px(10)
        width: LabTheme.px(232)
    }

    // --- network stats -----------------------------------------------------
    LabPanel {
        id: stats
        anchors.right: parent.right
        anchors.top: params.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.px(10)
        width: LabTheme.px(232)
        title: LabLang.t("stats.title")

        Column {
            id: statsCol
            spacing: LabTheme.spaceXs
            width: stats.body.width
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
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: {
                    root.graphRev
                    let t = root.net.stats.junctions + " " + LabLang.t("traffic.junctions")
                          + " · " + root.net.stats.deadEnds + " " + LabLang.t("traffic.deadEnds")
                    if (root.net.stats.bannedTurns > 0)
                        t += " · " + LabLang.tf("stats.banned", root.net.stats.bannedTurns)
                    return t
                }
                color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            Item { width: LabTheme.px(1); height: LabTheme.px(4) }
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
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
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
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    root.flowRev
                    return LabLang.t("stats.arrived") + "  " + root.simState.gone
                }
                color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
        }
    }

    // --- the lane graph: the same model, drawn as what it IS ---------------
    // The plan shows what you built; this shows how a car sees it - nodes,
    // one arrow per lane, and the turns that join them. Both read the same
    // model, so they can never disagree.
    LabPanel {
        id: planPanel
        visible: root.showPlan
        // Turn the text size up and the palette alone reaches the bottom of
        // the window, so the lane graph steps out from under it into the empty
        // middle. Measured against where the panels actually end, so on a tall
        // screen at the same scale the single column stays.
        anchors.left: root.planUnderPalette ? parent.left : palette.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: LabTheme.spaceXl
        anchors.bottomMargin: LabTheme.px(44)
        width: LabTheme.px(258)
        height: LabTheme.px(190)
        title: LabLang.t("plan.title")
        tag: "M"

        Canvas {
            id: planCanvas
            // the panel's body, by id: `parent` here is the panel's stacking
            // column, which is a generation too deep to anchor across
            width: planPanel.body.width
            height: planPanel.body.height

            readonly property int rev: root.graphRev * 7 + root.selectedRoad * 7919
                                       + root.activeNode * 104729 + root.flowRev
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

                // The turns, faint: they are what makes it a graph rather than
                // a heap of arrows. A CLOSED movement is drawn in the alarm
                // colour here too - the abstract view has to agree with the
                // plan about what is switched off.
                ctx.lineWidth = 0.9
                for (const C of root.net.connectors) {
                    ctx.strokeStyle = (C.banned ? LabTheme.alarm
                                     : LabTheme.panelEdge).toString()
                    ctx.lineWidth = C.banned ? 1.6 : 0.9
                    ctx.beginPath()
                    ctx.moveTo(px(C.pts[0]), py(C.pts[1]))
                    for (let p = 1; p < C.pts.length / 2; ++p)
                        ctx.lineTo(px(C.pts[p * 2]), py(C.pts[p * 2 + 1]))
                    ctx.stroke()
                }

                // nodes: a junction is a filled dot, a dead end an open ring
                for (const nd of root.net.nodes) {
                    const dead = nd.degree === 1
                    const active = nd.id === root.activeNode
                    ctx.beginPath()
                    ctx.arc(px(nd.x), py(nd.z), dead ? 3.4 : 2.6 + nd.degree * 0.5, 0,
                            2 * Math.PI)
                    if (dead) {
                        ctx.strokeStyle = LabTheme.accent.toString()
                        ctx.lineWidth = 1.8
                        ctx.stroke()
                    } else {
                        ctx.fillStyle = (active ? LabTheme.secondary
                                       : nd.degree >= 3 ? LabTheme.primary
                                       : LabTheme.inkFaint).toString()
                        ctx.fill()
                    }
                    if (!active) continue
                    // ring the junction being edited, so the card and the graph
                    // agree about which crossing is in hand
                    ctx.beginPath()
                    ctx.arc(px(nd.x), py(nd.z), 6.5, 0, 2 * Math.PI)
                    ctx.strokeStyle = LabTheme.secondary.toString()
                    ctx.lineWidth = 1.4
                    ctx.stroke()
                }
            }
        }
    }

    // --- flow numbers ------------------------------------------------------
    // The toggle that states the lesson: with V on, every road shows what is
    // actually flowing along it, so a grid and a tree of cul-de-sacs stop
    // needing to be explained.
    //
    // Every label takes its camera from the VIEW rather than from the rig: a
    // label projects through view3d, so the camera it must wait for is the one
    // view3d is actually rendering with. Naming the rig's camera instead gets
    // the label past its own null-guard while the view still has none, and the
    // first projection of the session goes through a warning.
    Repeater {
        model: root.showValues ? root.net.roads : []
        WorldLabel {
            required property var modelData
            view: view3d
            camera: view3d.camera
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

    // --- house names -------------------------------------------------------
    // A, B, C, D - so a study can say "the road from A to C" and mean something
    // anyone looking at the plan can find. The chip carries the arrivals at
    // that house while the traffic runs, because per-house arrival counts are
    // the one thing the plan cannot show by itself.
    Repeater {
        model: { root.graphRev; return root.houses }
        WorldLabel {
            required property var modelData
            required property int index
            readonly property int node: {
                root.graphRev
                return root.houseNodeAt(modelData)
            }
            view: view3d
            camera: view3d.camera
            worldPosition: Qt.vector3d(modelData.x, 9.5, modelData.z)
            placement: WorldLabel.Above
            accent: node === -1 ? LabTheme.muted : LabTheme.accent
            text: {
                root.flowRev
                const name = root.houseLabel(index)
                if (node === -1) return name + " " + LabLang.t("house.unbound")
                const n = root.simState.arrivedAt[node] || 0
                return n > 0 ? name + "  " + n : name
            }
        }
    }

    // --- leg names at the selected junction --------------------------------
    // The matrix says "R3 → R5"; these chips are what make that mean something
    // you can point at. They appear only while a junction is selected, sit out
    // along each leg rather than in the box, and use the very same labels as
    // the matrix headers.
    Repeater {
        model: {
            root.graphRev
            return root.activeNode === -1 ? [] : root.legsAt(root.activeNode)
        }
        WorldLabel {
            required property var modelData
            view: view3d
            camera: view3d.camera
            worldPosition: {
                root.graphRev
                return root.legAnchor(root.activeNode, modelData)
            }
            placement: WorldLabel.Centered
            accent: LabTheme.primary
            text: { root.graphRev; return root.roadLabel(modelData) }
        }
    }

    // --- watch marks -------------------------------------------------------
    Repeater {
        model: root.watch
        WorldLabel {
            required property var modelData
            readonly property int rid: modelData
            view: view3d
            camera: view3d.camera
            worldPosition: {
                root.graphRev
                const m = root.roadMidpoint(rid)
                return Qt.vector3d(m.x, 3.0, m.z)
            }
            placement: WorldLabel.Above
            accent: root.watchColorOf(rid)
            visible: active && onScreen && root.roadRecord(rid) !== null
            // the dot in the curve's colour is the kernel's mark now; the
            // WorldLabel around it is what pins it to a place on the plan
            WatchMark {
                monitor: root.watchMonitor
                target: rid
                label: { root.graphRev; return root.roadLabel(rid) }
            }
        }
    }

    // --- selection card ----------------------------------------------------
    // A road's card rides with the road, because it is small and belongs to a
    // place. The junction editor does NOT - see the panel further down: a
    // matrix pinned to a crossing covers the very legs it names.
    WorldLabel {
        id: selCard
        readonly property var road: {
            root.graphRev
            return root.selectedRoad === -1 ? null : root.roadRecord(root.selectedRoad)
        }
        view: view3d
        camera: view3d.camera
        active: road !== null
        worldPosition: road ? Qt.vector3d((road.x0 + road.x1) / 2, 0,
                                          (road.z0 + road.z1) / 2)
                            : Qt.vector3d(0, 0, 0)
        placement: WorldLabel.Below
        gap: LabTheme.px(10)
        accent: LabTheme.secondary

        Column {
            spacing: LabTheme.spaceXs
            Text {
                text: {
                    root.graphRev
                    if (!selCard.road) return ""
                    return LabLang.t("card.road") + " " + root.roadLabel(selCard.road.id)
                }
                color: LabTheme.primary; font.pixelSize: LabTheme.fontSmall; font.bold: true
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
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            // the per-object control: this road's own lane count
            Row {
                spacing: LabTheme.spaceS
                Repeater {
                    model: [1, 2]
                    Rectangle {
                        required property int modelData
                        readonly property bool on:
                            selCard.road !== null && selCard.road.lanes === modelData
                        width: LabTheme.px(92); height: LabTheme.px(20); radius: LabTheme.px(5)
                        color: on ? LabTheme.secondary : LabTheme.paper
                        border.color: on ? LabTheme.secondary : LabTheme.panelEdge
                        border.width: LabTheme.px(1.5)
                        Text {
                            anchors.centerIn: parent
                            // short form: the card already says ROAD, and the
                            // German long form does not fit a chip
                            text: LabLang.t(modelData === 1 ? "road.oneLane.short"
                                                            : "road.twoLanes.short")
                            width: LabTheme.px(86); horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: parent.on ? LabTheme.paper : LabTheme.inkSoft
                            font.pixelSize: LabTheme.fontMicro; font.family: LabTheme.monoFont
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: if (selCard.road)
                                root.setRoadLanes(selCard.road.id, modelData)
                        }
                    }
                }
            }
            // the kernel's chip: it reads the series limit off the monitor,
            // so this card can no longer disagree with the plot about whether
            // there is a colour left - and its ink comes from its own fill
            WatchChip {
                monitor: root.watchMonitor
                target: selCard.road ? selCard.road.id : undefined
                labels: ({ add: "card.watch", on: "card.watched",
                           full: "card.watch.full" })
            }
            Text {
                text: LabLang.t("card.hint.road")
                color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.handFont
            }
        }

    }

    // --- junction editor ---------------------------------------------------
    // A FIXED panel, not a card pinned to the crossing. The matrix is large
    // enough that anchoring it to the junction covered the very leg labels it
    // refers to - so instead the junction is ringed on the plan, its legs wear
    // the same names the matrix uses, and the editor sits still on the right
    // where a panel of this size can breathe.
    LabPanel {
        id: junctionPanel
        readonly property var node: {
            root.graphRev
            return root.activeNode === -1 ? null : root.nodeRecord(root.activeNode)
        }
        readonly property var moves: {
            root.graphRev
            return node ? root.movementsAt(node.id) : []
        }
        visible: node !== null
        anchors.right: parent.right
        anchors.top: stats.bottom
        anchors.rightMargin: LabTheme.spaceXl
        anchors.topMargin: LabTheme.px(10)
        width: LabTheme.px(232)
        // a closed junction says so in its own border
        border.color: node !== null && root.junctionClosed(node.id) ? LabTheme.alarm
                                                                   : LabTheme.secondary

      Column {
        id: junctionCol
        width: junctionPanel.body.width
        spacing: LabTheme.spaceXs

        Text {
            // German runs a quarter longer than the English it replaces, so the
            // title is capped and elides rather than escaping the panel
            width: junctionCol.width
            elide: Text.ElideRight
            text: {
                root.graphRev
                if (!junctionPanel.node) return ""
                const nd = junctionPanel.node
                const what = nd.degree === 1 ? "card.deadEnd"
                           : (nd.degree === 2 ? "card.bend" : "card.junction")
                return LabLang.t(what) + "  "
                     + LabLang.tf("card.legs", nd.degree)
            }
            color: LabTheme.primary; font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.letterSpacing: 1.0; font.family: LabTheme.monoFont
        }
        Text {
            visible: junctionPanel.moves.length > 0
            width: junctionCol.width
            wrapMode: Text.WordWrap
            text: LabLang.t("card.turns.hint")
            color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
        Text {
            visible: junctionPanel.moves.length === 0
            width: junctionCol.width
            wrapMode: Text.WordWrap
            text: LabLang.t("card.turns.none")
            color: LabTheme.accent; font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }

        // The movements as a MATRIX: rows are the road you arrive on,
        // columns the road you leave by, so every combination has a place
        // and you can see at a glance which way through the junction is
        // shut. The diagonal is blank - a U-turn is never offered.
        //
        // The row and column names are the same labels that appear on the
        // legs out on the plan while this junction is selected, which is
        // what makes "R3 → R5" mean something you can point at.
        Grid {
            id: turnMatrix
            readonly property var legs: {
                root.graphRev
                return junctionPanel.node ? root.legsAt(junctionPanel.node.id) : []
            }
            visible: legs.length > 1
            columns: legs.length + 1
            spacing: LabTheme.px(2)

            // corner: the axis legend
            Rectangle {
                width: LabTheme.px(30); height: LabTheme.px(17); color: "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "↓→"
                    color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontMicro
                    font.family: LabTheme.monoFont
                }
            }
            // column headers: the road you LEAVE by
            Repeater {
                model: turnMatrix.legs
                Rectangle {
                    required property var modelData
                    width: LabTheme.px(30); height: LabTheme.px(17); radius: LabTheme.px(3)
                    color: LabTheme.paperDeep
                    Text {
                        anchors.centerIn: parent
                        text: { root.graphRev; return root.roadLabel(modelData) }
                        color: LabTheme.primary; font.pixelSize: LabTheme.fontMicro; font.bold: true
                        font.family: LabTheme.monoFont
                    }
                }
            }

            // one row per arriving road: its header, then a cell per exit
            Repeater {
                model: turnMatrix.legs.length * (turnMatrix.legs.length + 1)
                Item {
                    required property int index
                    readonly property int col: index % (turnMatrix.legs.length + 1)
                    readonly property int row: Math.floor(index / (turnMatrix.legs.length + 1))
                    readonly property int fromRoad: turnMatrix.legs[row]
                    readonly property int toRoad: col > 0 ? turnMatrix.legs[col - 1] : -1
                    readonly property var move: {
                        root.graphRev
                        if (col === 0 || !junctionPanel.node) return null
                        return root.movementAt(junctionPanel.node.id, fromRoad, toRoad)
                    }
                    width: LabTheme.px(30); height: LabTheme.px(17)

                    // row header
                    Rectangle {
                        anchors.fill: parent
                        visible: col === 0
                        radius: LabTheme.px(3)
                        color: LabTheme.paperDeep
                        Text {
                            anchors.centerIn: parent
                            text: { root.graphRev; return root.roadLabel(fromRoad) }
                            color: LabTheme.primary; font.pixelSize: LabTheme.fontMicro; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                    // a movement cell
                    Rectangle {
                        anchors.fill: parent
                        visible: col > 0 && move !== null
                        radius: LabTheme.px(3)
                        readonly property bool off: move !== null && move.banned
                        readonly property bool hovered:
                            move !== null && root.hoverHit
                            && root.hoverHit.kind === "turn"
                            && root.hoverHit.id === move.connector
                        color: off ? LabTheme.alarm : LabTheme.paper
                        border.color: hovered ? LabTheme.secondary
                                    : (off ? LabTheme.alarm : LabTheme.panelEdge)
                        border.width: hovered ? 2 : 1
                        Text {
                            anchors.centerIn: parent
                            text: move ? (root.turnGlyphs[move.turn] || "·") : ""
                            color: LabTheme.inkOn(parent.color)
                            font.pixelSize: LabTheme.fontBody; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.hoverHit = { kind: "turn",
                                                         id: move.connector }
                            onExited: root.hoverHit = null
                            onClicked: root.toggleTurnBanned(junctionPanel.node.id,
                                                             fromRoad, toRoad)
                        }
                    }
                    // the diagonal, and any pair with no movement at all
                    Rectangle {
                        anchors.fill: parent
                        visible: col > 0 && move === null
                        radius: LabTheme.px(3)
                        color: "transparent"
                        border.color: LabTheme.panelEdge; border.width: LabTheme.px(1)
                        Text {
                            anchors.centerIn: parent
                            text: "·"
                            color: LabTheme.muted; font.pixelSize: LabTheme.fontMicro
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: junctionPanel.moves.length > 1
            readonly property bool closed:
                junctionPanel.node !== null && root.junctionClosed(junctionPanel.node.id)
            width: junctionCol.width; height: LabTheme.px(21); radius: LabTheme.radius
            color: closed ? LabTheme.alarm : LabTheme.panel
            border.color: closed ? LabTheme.alarm : LabTheme.secondary
            border.width: LabTheme.px(1.5)
            Text {
                anchors.centerIn: parent
                width: junctionCol.width - LabTheme.spaceL; horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: LabLang.t(parent.closed ? "card.junction.open"
                                              : "card.junction.close") + "  (X)"
                color: LabTheme.inkOn(parent.color)
                font.pixelSize: LabTheme.fontMicro; font.family: LabTheme.monoFont
            }
            MouseArea { anchors.fill: parent; onClicked: root.toggleJunctionClosed() }
        }
        Text {
            width: junctionCol.width
            wrapMode: Text.WordWrap
            text: LabLang.t("card.hint.node")
            color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
      }
    }

    // --- banner ------------------------------------------------------------
    // Two faults with different weight: a plan every turn leads off is a note,
    // gridlock is a fault - so only the second one blinks.
    LabBanner {
        id: banner
        readonly property bool allDead:
            root.net.stats.lanes > 0 && root.net.stats.connectors === 0
        readonly property bool jammed: {
            root.flowRev
            return root.running && root.simState.cars.length > 4
                   && Traffic.stoppedShare(root.simState) > 0.65
        }
        active: allDead || jammed
        alarm: jammed
        blink: jammed
        guard: palette                // never grows in under the plan's tools
        topMargin: LabTheme.px(14)
        text: LabLang.t(jammed ? "banner.jammed" : "banner.allDeadEnds")
    }

    // The clock, on screen. A traffic sim whose whole reading is "how much
    // has queued up by now" had nothing saying how long it had been running,
    // and no way to stop it at the moment worth looking at.
    TransportChip {
        clock: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // under the banner's slot, not in it: gridlock outranks the clock
        anchors.topMargin: LabTheme.px(56)
    }

    // --- hint bar ----------------------------------------------------------
    HintBar {
        rightGuard: monitor
        text: {
            // the hand outranks everything: while an instrument is out, a hint
            // about drawing describes something you are not doing
            if (!hands.empty) return LabLang.t(hands.held.hint)
            if (root.lastRefusal === "short") return LabLang.t("hint.tooShort")
            if (root.eraser) return LabLang.t("hint.erasing")
            if (root.drawFrom) return LabLang.t("hint.drawing")
            if (root.activeNode !== -1) return LabLang.t("hint.selectedNode")
            if (root.selectedRoad !== -1) return LabLang.t("hint.selected")
            if (root.running) return LabLang.t("hint.running")
            return LabLang.t("hint.idle")
        }
    }

    // --- monitor -----------------------------------------------------------
    // One quantity at a time: every series shares one autoscaled axis, so
    // mixing cars-per-minute with speeds would flatten one of them onto the
    // baseline.
    WatchMonitor {
        id: monitor
        anchors.bottom: parent.bottom; anchors.right: parent.right
        anchors.margins: LabTheme.px(10)
        idPrefix: "road"
        quantities: [
            { key: "flow", label: "quantity.flow", unit: "/min" },
            { key: "load", label: "quantity.load", unit: "" },
            { key: "speed", label: "quantity.speed", unit: "u/s" }]
        plotWidth: LabTheme.px(340)
        plotHeight: LabTheme.px(142)
        windowSeconds: 40
        placeholder: LabLang.t("plot.empty")
        valueOf: (id) => root.watchValueOf(id)
        labelOf: (id) => root.roadLabel(id)
        revision: root.graphRev
    }

    // --- keys --------------------------------------------------------------
    // The reserved half of the map (presets, view, record, help) is LabKeys';
    // what is declared here is what this lab adds - and declaring a key here
    // is also what documents it in LabHelp.
    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        hands: hands
        recorder: recorder
        keys: [
            { key: "S", label: "key.simulate", action: () => root.toggleSim() },
            { key: "C", label: "key.clear", action: () => root.clearPlan() },
            { key: "E", label: "key.eraser", action: () => root.eraser = !root.eraser },
            { key: "L", label: "key.lanes", action: () => root.showLanes = !root.showLanes },
            { key: "V", label: "key.values", action: () => root.showValues = !root.showValues },
            { key: "M", label: "key.plan", action: () => root.showPlan = !root.showPlan },
            { key: "W", label: "key.watch", action: () => {
                if (root.selectedRoad !== -1) root.toggleWatch(root.selectedRoad) } },
            // X closes or opens every movement through the selected junction at
            // once. NOT T: the canonical map reserves that for flows, and a lab
            // may add keys but never reassign them.
            { key: "X", label: "key.closeJunction", action: () => {
                if (root.activeNode !== -1) root.toggleJunctionClosed() } },
            { key: "#", label: "key.grid", action: () => grid.toggle() },
            { key: "G", label: "key.grid", hidden: true, action: () => grid.toggle() },
            { key: "Del", label: "key.delete", action: () => root.removeSelection() }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: 300
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) {
            eraser = false; clearSelection(); drawFrom = null; drawTo = null
        }
    }
    // the other half of the Space quasimode: without it the hand stays down
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
