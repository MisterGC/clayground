// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Per-tile traffic + transmitters for the neoncity demo (Phase 5, part 2).
//
// CARS AS A LOW-POLY INSTANCED SILHOUETTE
// ---------------------------------------
// Every car is a body + a rear-set cabin + a cyan front window + 4 wheels. To
// keep the whole fleet cheap this is FOUR instanced Models (defined inline
// below), one per part, each drawn in a single call regardless of car count:
//   * body   - 1 instance per car, per-car palette colour
//   * cabin  - 1 instance per car, darkened palette colour
//   * window - 1 instance per car, cyan glass (uniform via material)
//   * wheels - 4 instances per car in ONE Model, dark (uniform via material)
// => 4 draw calls for ALL cars of this tile. (CityTile instantiates one
// CarSystem per streamed tile, so the fleet replicates per tile exactly like
// the lane overlay and building instances; the model itself never exceeds 4
// Models no matter how many cars ride it.)
//
// Cars follow the deterministic right-hand lane routes from cargen.js and steer
// smoothly through intersections along a quadratic-Bezier turn curve, their
// heading (per-instance yaw) always tracking the direction of travel so the car
// is long-axis-forward at every moment. Each car also owns an invisible anchor
// Node carrying a Connector3D linking it to its nearest transmitter.
//
// Streaming: cars/transmitters live on the tile, so they spawn and despawn with
// it. Transmitters register into the manager's global registry so cars in any
// tile can pick the nearest one across the whole loaded neighbourhood.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import "cargen.js" as CarGen

Node {
    id: carSys

    // ---- inputs ----
    property var cityData: null
    // Road-surface height: cars ride with their wheels ON this plane (the tile's
    // matte asphalt), so nothing floats above the lanes.
    property real roadY: 0.6
    property int carCount: 8
    property real baseSpeed: 34.0
    property bool showCars: true
    property var connectorLayer: null   // shared ConnectorLayer3D (scene root)
    property var manager: null          // transmitter registry + provider

    // ---- readouts ----
    readonly property int activeCars: _cars ? _cars.length : 0
    readonly property int transmitterCount: _transmitters ? _transmitters.length : 0

    // ---- state ----
    property var _routes: []
    property var _cars: []
    property var _bodyE: []         // InstanceListEntry, one body per car
    property var _cabinE: []        // InstanceListEntry, one cabin per car
    property var _winE: []          // InstanceListEntry, one window per car
    property var _wheelE: []        // InstanceListEntry, four wheels per car
    property var _anchors: []       // Node, one per car (connector endpoint)
    property var _transmitters: []  // Transmitter nodes owned by this tile
    property int _nearestCursor: 0
    property bool _coreBuilt: false        // routes + cars built (needs cityData)
    property bool _txBuilt: false          // transmitters built + registered

    // ---- car dimensions (world units), derived from the lane geometry ----
    // width ~= 0.6 x narrowest lane so a car fits inside every lane it drives;
    // length ~= 2.3 x width, height ~= 0.85 x width. Set in rebuildCars().
    property real _carW: 1.4
    property real _carL: 3.2
    property real _carH: 1.2

    // ---- body palette (bright neon; index = car.paint) ----
    readonly property var _palette: ["#00d9ff", "#ff3366", "#ffd93d", "#0f9d9a",
                                     "#ff8c42", "#c74bff", "#4dff88", "#e6ecff"]
    property var _paletteDark: []          // darkened variants for the cabins

    // Yaw smoothing rate (higher = snappier heading tracking).
    readonly property real _yawRate: 9.0

    // ---- factories ----
    Component { id: entryComp; InstanceListEntry {} }
    Component { id: txComp; Transmitter {} }
    Component {
        id: anchorComp
        Node {
            id: an
            property var target: null
            property color connColor: "#00d9ff"
            Connector3D {
                layer: carSys.connectorLayer
                from: an
                to: an.target
                color: an.connColor
                width: 1.4
            }
        }
    }

    // ---- car visuals: four instanced Models = four draw calls total ----
    // Body: per-instance palette colour (material white, colour rides the table).
    Model {
        id: bodyModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { instances: carSys._bodyE }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
        }
    }
    // Cabin: darkened palette colour per instance.
    Model {
        id: cabinModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { instances: carSys._cabinE }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
        }
    }
    // Front window: uniform cyan glass accent.
    Model {
        id: windowModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { instances: carSys._winE }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#8ff6ff"
        }
    }
    // Wheels: four instances per car, one Model, uniform near-black.
    Model {
        id: wheelModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { instances: carSys._wheelE }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#111111"
        }
    }

    // cityData (from tile.build) and manager (from TileManager.onReady) arrive
    // in an unspecified order relative to this component's completion, so build
    // idempotently whenever the missing input shows up.
    Component.onCompleted: { _buildDarkPalette(); tryBuild() }
    Component.onDestruction: releaseTransmitters()

    onCityDataChanged: tryBuild()
    onManagerChanged: tryBuild()
    onCarCountChanged: if (_coreBuilt) rebuildCars()

    function _buildDarkPalette() {
        var out = []
        for (var i = 0; i < _palette.length; ++i) {
            var c = Qt.color(_palette[i])   // string -> color so r/g/b exist
            out.push(Qt.rgba(c.r * 0.45, c.g * 0.45, c.b * 0.55, 1.0))
        }
        _paletteDark = out
    }

    function tryBuild() {
        if (cityData && !_coreBuilt) {
            _coreBuilt = true
            _routes = CarGen.buildRoutes(cityData, roadY)
            rebuildCars()
        }
        if (cityData && manager && !_txBuilt) {
            _txBuilt = true
            buildTransmitters()
        }
    }

    function buildTransmitters() {
        var sites = CarGen.transmitterSites(cityData)
        var arr = []
        for (var i = 0; i < sites.length; ++i) {
            var s = sites[i]
            var mast = 44
            var node = txComp.createObject(carSys, {
                position: Qt.vector3d(s.x, s.top + mast, s.z),
                mastHeight: mast
            })
            arr.push(node)
            if (manager && manager.registerTransmitter) manager.registerTransmitter(node)
        }
        _transmitters = arr
    }

    function releaseTransmitters() {
        for (var i = 0; i < _transmitters.length; ++i) {
            if (manager && manager.unregisterTransmitter) manager.unregisterTransmitter(_transmitters[i])
        }
    }

    // ---- part local geometry (car-local: origin at wheel-contact, +Z fwd) ----
    // Returned scales are already /100 for the 100-unit "#Cube" primitive; the
    // offsets are the part centres in car-local space (rotated per frame).
    function _partLayout() {
        var W = _carW, L = _carL, H = _carH
        var wheelD = 0.36 * H, wheelR = 0.5 * wheelD
        var bodyH = 0.5 * H, bodyY = wheelR + 0.5 * bodyH
        var cabW = 0.80 * W, cabH = 0.42 * H, cabL = 0.44 * L
        var cabY = wheelR + bodyH + 0.5 * cabH, cabZ = -0.10 * L
        var winW = 0.66 * W, winH = 0.72 * cabH, winL = 0.06 * L
        var winY = cabY - 0.05 * H, winZ = cabZ + 0.5 * cabL    // cabin front face
        return {
            bodyOff: [0, bodyY, 0],
            bodyScale: [W / 100, bodyH / 100, L / 100],
            cabOff: [0, cabY, cabZ],
            cabScale: [cabW / 100, cabH / 100, cabL / 100],
            winOff: [0, winY, winZ],
            winScale: [winW / 100, winH / 100, winL / 100],
            wheelScale: [(0.20 * W) / 100, wheelD / 100, wheelD / 100],
            wheelR: wheelR,
            // four wheel centres (x, y, z) at the body corners.
            wheelOff: [
                [ 0.48 * W, wheelR,  0.32 * L],
                [-0.48 * W, wheelR,  0.32 * L],
                [ 0.48 * W, wheelR, -0.32 * L],
                [-0.48 * W, wheelR, -0.32 * L]
            ]
        }
    }

    function rebuildCars() {
        if (_paletteDark.length === 0) _buildDarkPalette()
        // Tear down previous car objects.
        for (var i = 0; i < _anchors.length; ++i) _anchors[i].destroy()
        for (i = 0; i < _bodyE.length; ++i) _bodyE[i].destroy()
        for (i = 0; i < _cabinE.length; ++i) _cabinE[i].destroy()
        for (i = 0; i < _winE.length; ++i) _winE[i].destroy()
        for (i = 0; i < _wheelE.length; ++i) _wheelE[i].destroy()
        _bodyE = []; _cabinE = []; _winE = []; _wheelE = []; _anchors = []

        var seed = cityData ? cityData.seed : 0
        _cars = CarGen.initCars(seed, _routes, carCount, baseSpeed)

        // Size cars to fit the narrowest lane, robust to tileSize.
        var lw = CarGen.minLaneWidth(_routes)
        _carW = 0.60 * lw
        _carL = 2.30 * _carW
        _carH = 0.85 * _carW
        _refreshLayout()

        var lay = _lay
        var bodyScale = Qt.vector3d(lay.bodyScale[0], lay.bodyScale[1], lay.bodyScale[2])
        var cabScale = Qt.vector3d(lay.cabScale[0], lay.cabScale[1], lay.cabScale[2])
        var winScale = Qt.vector3d(lay.winScale[0], lay.winScale[1], lay.winScale[2])
        var wheelScale = Qt.vector3d(lay.wheelScale[0], lay.wheelScale[1], lay.wheelScale[2])

        var bodyE = [], cabinE = [], winE = [], wheelE = [], anchors = []
        for (i = 0; i < _cars.length; ++i) {
            var car = _cars[i]
            _seedYaw(car)
            var pc = _palette[car.paint % _palette.length]
            var dc = _paletteDark[car.paint % _paletteDark.length]
            bodyE.push(entryComp.createObject(carSys, { scale: bodyScale, color: pc }))
            cabinE.push(entryComp.createObject(carSys, { scale: cabScale, color: dc }))
            winE.push(entryComp.createObject(carSys, { scale: winScale }))
            for (var w = 0; w < 4; ++w)
                wheelE.push(entryComp.createObject(carSys, { scale: wheelScale }))
            anchors.push(anchorComp.createObject(carSys, {}))
        }
        _bodyE = bodyE; _cabinE = cabinE; _winE = winE; _wheelE = wheelE
        _anchors = anchors
        _nearestCursor = 0
        _writeAll()
    }

    // Current XZ position + heading (radians) of a car, from its drive/turn state.
    function _sample(car) {
        if (car.mode === 1 && car.curve) {
            var p = CarGen.bezPoint(car.curve, car.ct)
            var tg = CarGen.bezTangent(car.curve, car.ct)
            return { x: p.x, z: p.z, hx: tg.x, hz: tg.z }
        }
        var r = _routes[car.route]
        return { x: r.sx + r.dx * car.t, z: r.sz + r.dz * car.t, hx: r.dx, hz: r.dz }
    }

    function _seedYaw(car) {
        var s = _sample(car)
        car.yaw = Math.atan2(s.hx, s.hz)
        car.yawInit = true
    }

    // Write the full instance table for every car once (used after a rebuild).
    function _writeAll() {
        for (var i = 0; i < _cars.length; ++i) _writeCar(i, true, _sample(_cars[i]))
    }

    // Push a single car's transform into all four part tables + its anchor,
    // given its current sample `s` (position + heading). `rot` forces the
    // rotation write; callers pass false to skip it when the heading did not
    // meaningfully change this frame. Kept allocation-light: it is the per-frame
    // hot path for every car part (7 instances/car).
    function _writeCar(i, rot, s) {
        var car = _cars[i]
        var bx = s.x, bz = s.z
        var lay = _lay
        var yaw = car.yaw
        var cy = Math.cos(yaw), sy = Math.sin(yaw)
        var baseY = roadY
        var yawDeg = yaw * 180.0 / Math.PI
        var rotV = rot ? Qt.vector3d(0, yawDeg, 0) : null

        // Rotate a car-local offset (lx,ly,lz) into world and lift to baseY.
        // Ry maps local +Z -> (sin,cos), local +X -> (cos,-sin).
        function place(entry, off) {
            var lx = off[0], ly = off[1], lz = off[2]
            entry.position = Qt.vector3d(bx + lx * cy + lz * sy,
                                         baseY + ly,
                                         bz - lx * sy + lz * cy)
            if (rotV) entry.eulerRotation = rotV
        }

        place(_bodyE[i], lay.bodyOff)
        place(_cabinE[i], lay.cabOff)
        place(_winE[i], lay.winOff)
        var base = i * 4
        place(_wheelE[base + 0], lay.wheelOff[0])
        place(_wheelE[base + 1], lay.wheelOff[1])
        place(_wheelE[base + 2], lay.wheelOff[2])
        place(_wheelE[base + 3], lay.wheelOff[3])

        // Anchor rides at the cabin roof so connectors spring from the car body.
        _anchors[i].position = Qt.vector3d(bx, baseY + _carH * 0.9, bz)
    }

    // Cached part layout (rebuilt whenever car size changes).
    property var _lay: _partLayout()
    function _refreshLayout() { _lay = _partLayout() }

    function _junctionRand(car) {
        return (CarGen.hash2(car.hash, car.turns) >>> 0) / 4294967296
    }

    function advance(dt) {
        var n = _cars.length
        if (n === 0 || _routes.length === 0) return
        if (!_lay) _refreshLayout()

        var steer = 1.0 - Math.exp(-_yawRate * dt)
        for (var i = 0; i < n; ++i) {
            var car = _cars[i]
            if (car.mode === 0) _advanceDrive(car)
            else _advanceTurn(car)

            // Smoothly steer the heading toward the current travel direction.
            var s = _sample(car)
            var target = Math.atan2(s.hx, s.hz)
            if (!car.yawInit) { car.yaw = target; car.yawInit = true }
            var prevYaw = car.yaw
            car.yaw = _lerpAngle(car.yaw, target, steer)
            var rot = Math.abs(_angDiff(car.yaw, prevYaw)) > 0.0008
            _writeCar(i, rot, s)
        }

        updateNearestBatch()
    }

    // Distance before a route's end at which we plan the upcoming turn.
    readonly property real _planDist: 9.0

    // Drive along the current route. As the car nears the route end it plans the
    // next manoeuvre (a turn onto the cross street, or a respawn at a tile edge);
    // it then begins the planned turn at the corner - which may be before OR a
    // little after the centreline end (the car crosses the junction to reach a
    // wide turn's entry). This keeps the heading tangent to the road at all times.
    function _advanceDrive(car) {
        var r = _routes[car.route]
        car.t += car.speed * frameDt

        if (!car.plan && car.t >= r.len - _planDist) {
            var rand = _junctionRand(car)
            var pick = CarGen.chooseNext(_routes, r.ex, r.ez, car.route, rand)
            car.turns = (car.turns + 1) >>> 0
            car.plan = pick >= 0 ? CarGen.planTurn(_routes, car.route, pick) : { respawn: true }
        }

        if (car.plan && car.plan.respawn) {
            if (car.t < r.len) return
            var over = car.t - r.len
            var nx = (car.route + 7) % _routes.length   // edge of tile: respawn onward
            car.route = nx
            car.mode = 0
            car.plan = null
            car.t = over % Math.max(1.0, _routes[nx].len)
            _seedYaw(car)
            return
        }

        if (car.plan && car.t >= car.plan.startT) {
            var ov = car.t - car.plan.startT
            car.curve = { p0: car.plan.p0, ctrl: car.plan.ctrl, p2: car.plan.p2 }
            car.clen = car.plan.len
            car.cnext = car.plan.toIdx
            car.cjoin = car.plan.joinTexit
            car.ct = Math.min(0.999, ov / car.plan.len)
            car.mode = 1
            car.plan = null
        }
    }

    // Advance along the active turn curve; hand back to straight driving at the
    // exit, resuming on the next route from the arc position where the turn left
    // it, carrying any leftover arc length forward.
    function _advanceTurn(car) {
        car.ct += (car.speed * frameDt) / car.clen
        if (car.ct < 1.0) return
        var over = (car.ct - 1.0) * car.clen
        var nx = car.cnext
        car.route = nx
        car.mode = 0
        car.curve = null
        car.t = Math.min(_routes[nx].len, car.cjoin + over)
    }

    // Shortest signed angular difference a-b in (-pi, pi].
    function _angDiff(a, b) {
        var d = a - b
        while (d > Math.PI) d -= 2 * Math.PI
        while (d < -Math.PI) d += 2 * Math.PI
        return d
    }
    function _lerpAngle(a, b, f) { return a + _angDiff(b, a) * f }

    // Per-frame delta time, set by the FrameAnimation before advance().
    property real frameDt: 0.0

    // Recompute the nearest transmitter for a slice of cars each frame so every
    // car refreshes about twice a second at 60 fps.
    function updateNearestBatch() {
        var tx = (manager && manager.transmitters) ? manager.transmitters : []
        var n = _cars.length
        if (n === 0) return
        if (tx.length === 0) {
            for (var c = 0; c < n; ++c) if (_anchors[c].target) _anchors[c].target = null
            return
        }
        var batch = Math.max(1, Math.ceil(n / 30))
        for (var k = 0; k < batch; ++k) {
            var idx = (_nearestCursor + k) % n
            var pp = _anchors[idx].position
            var best = null, bestD = 1e30
            for (var j = 0; j < tx.length; ++j) {
                var sp = tx[j].scenePosition
                var dx = sp.x - pp.x, dz = sp.z - pp.z
                var d = dx * dx + dz * dz
                if (d < bestD) { bestD = d; best = tx[j] }
            }
            if (_anchors[idx].target !== best) _anchors[idx].target = best
        }
        _nearestCursor = (_nearestCursor + batch) % n
    }

    FrameAnimation {
        running: carSys.showCars && carSys._cars.length > 0
        onTriggered: {
            var dt = frameTime
            if (dt > 0.05) dt = 0.05   // clamp big hitches
            carSys.frameDt = dt
            carSys.advance(dt)
        }
    }
}
