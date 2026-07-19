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
    // Global traffic-speed multiplier (1.0 = raw baseSpeed). Default cruises the
    // fleet at a calmer ~0.4x so the city reads and cars are easy to inspect.
    property real carSpeedFactor: 0.4
    property bool showCars: true
    property var connectorLayer: null   // shared ConnectorLayer3D (scene root)
    property var manager: null          // transmitter registry + provider

    // ---- readouts ----
    readonly property int activeCars: _cars ? _cars.length : 0
    readonly property int transmitterCount: _transmitters ? _transmitters.length : 0
    // Cumulative count of overtaking lane changes started on this tile (diagnostic
    // readout so behaviour can be confirmed without eyeballing a single frame).
    property int laneChanges: 0

    // ---- state ----
    property var _routes: []
    property var _cars: []
    property var _inters: []        // cityData.intersections (junction graph)
    property var _phase: []         // per-junction light phase this frame
    property var _occ: []           // per-junction box occupancy axis this frame
    property var _lights: []        // signal-head visuals (one per junction leg)
    // Shared sim clock (scaled by carSpeedFactor so cars AND lights slow together
    // for inspection). Lights are derived from this so every car agrees on the
    // phase of each junction. Determinism of the live sim is not required.
    property real simClock: 0.0

    // ---- traffic-model tuning (world units, factor-1.0 time base) ----
    readonly property real _GREEN: 6.0      // green window per axis (sim seconds)
    readonly property real _CLEAR: 2.5      // all-red clearance so the box empties
    readonly property real _ACCEL: 22.0     // comfortable acceleration (u/s^2)
    readonly property real _DECEL_MAX: 44.0 // hardest braking (u/s^2)
    readonly property real _DECEL: 30.0     // planning decel for the safe-speed law
    readonly property real _LOOKAHEAD: 34.0 // how far ahead a leader is considered
    property real _laneHalf: 1.4            // in-lane lateral tolerance (set on build)
    property real _minGap: 3.0              // standstill bumper gap (set on build)
    property real _spawnGap: 8.0            // entry spacing on respawn (set on build)
    readonly property real _OT_TRIGGER: 9.0 // leader bumper gap that invites overtaking
    readonly property real _OT_SLOWER: 0.82 // leader must be this much slower than cruise
    readonly property real _OT_RETURN: 18.0 // clear gap needed to merge back to the kerb
    readonly property real _OT_MARGIN: 12.0 // keep clear of junctions when lane-changing
    readonly property real _OT_BACK: 8.0    // target-lane clearance needed behind
    readonly property real _OT_FRONT: 14.0  // ... and ahead
    readonly property real _OT_COOLDOWN: 3.0 // min dwell between lane changes (sim s)
    readonly property real _latRate: 2.6    // lateral merge easing rate
    // Per-frame pose buffers, one Float32Array per instance table: 4 floats
    // (x, y, z, yawRad) per entry, reused every frame (allocated in rebuildCars).
    property var _bodyBuf: null     // one body per car
    property var _cabinBuf: null    // one cabin per car
    property var _winBuf: null      // one window per car
    property var _wheelBuf: null    // four wheels per car
    property var _anchors: []       // Node, one per car (connector endpoint)
    property var _sampleCache: []   // per-frame position/heading samples (reused)
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
    Component { id: txComp; Transmitter {} }
    // A traffic-signal head: a small emissive quad on a thin dark post, colour
    // driven live from the junction phase (green = go, red = stop). Junctions are
    // few per tile so these are plain Models (no instancing needed).
    Component {
        id: lightComp
        Node {
            id: lh
            property color col: "#ff2a2a"
            readonly property real headY: 4.0
            Model {
                source: "#Cylinder"
                y: lh.headY * 0.5
                scale: Qt.vector3d(0.35 / 100, lh.headY / 100, 0.35 / 100)
                castsShadows: false
                receivesShadows: false
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: "#2a2d33"
                }
            }
            Model {
                source: "#Cube"
                y: lh.headY
                scale: Qt.vector3d(1.8 / 100, 1.8 / 100, 1.8 / 100)
                castsShadows: false
                receivesShadows: false
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: lh.col
                }
            }
        }
    }
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
    // Each part is a DynamicInstances3D table: per-car scale + colour are set
    // once in rebuildCars() (setBulk); the per-frame movement is packed into a
    // reused Float32Array and pushed with a single updatePoses() per table (see
    // _packAll), so the hot path costs no per-instance QObject writes.
    // Body: per-instance palette colour (material white, colour rides the table).
    Model {
        id: bodyModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: DynamicInstances3D { id: bodyInst }
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
        instancing: DynamicInstances3D { id: cabinInst }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
        }
    }
    // Front window: uniform cyan glass accent (instance colour white, tint from
    // the material so the look matches the pre-migration InstanceList table).
    Model {
        id: windowModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: DynamicInstances3D { id: winInst }
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
        instancing: DynamicInstances3D { id: wheelInst }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#111111"
        }
    }

    // cityData (from tile.build) and manager (from TileManager.onReady) arrive
    // in an unspecified order relative to this component's completion, so build
    // idempotently whenever the missing input shows up.
    Component.onCompleted: { _buildDarkPalette(); tryBuild() }
    Component.onDestruction: { releaseTransmitters(); _destroyLights() }

    function _destroyLights() {
        for (var i = 0; i < _lights.length; ++i) _lights[i].node.destroy()
        _lights = []
    }

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
            _inters = cityData.intersections || []
            _routes = CarGen.buildRoutes(cityData, roadY)
            buildLights()
            rebuildCars()
        }
        if (cityData && manager && !_txBuilt) {
            _txBuilt = true
            buildTransmitters()
        }
    }

    // Build one signal head per junction leg, placed just outside the box on the
    // right of each approach (right-hand traffic). Its colour is refreshed each
    // frame from the junction's current phase.
    function buildLights() {
        for (var i = 0; i < _lights.length; ++i) _lights[i].node.destroy()
        var arr = []
        for (i = 0; i < _inters.length; ++i) {
            var nd = _inters[i]
            for (var li = 0; li < nd.legs.length; ++li) {
                var leg = nd.legs[li]
                var d = leg.dir                       // points AWAY from the node
                var axis = Math.abs(d.x) > Math.abs(d.z) ? "h" : "v"
                var rvx = d.z, rvz = -d.x              // right of the APPROACHING travel (-d)
                var half = leg.width * 0.5
                var px = nd.x + d.x * (nd.radius + 0.6) + rvx * (half + 1.4)
                var pz = nd.z + d.z * (nd.radius + 0.6) + rvz * (half + 1.4)
                var node = lightComp.createObject(carSys, {
                    position: Qt.vector3d(px, roadY, pz),
                    visible: Qt.binding(function () { return carSys.showCars })
                })
                arr.push({ node: node, axis: axis, junc: i })
            }
        }
        _lights = arr
    }

    function _updateLights() {
        for (var i = 0; i < _lights.length; ++i) {
            var L = _lights[i]
            var ph = _phase[L.junc]
            if (!ph) continue
            var go = (!ph.allRed && ph.green === L.axis)
            L.node.col = go ? "#2bff6a" : "#ff2a2a"
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
        // Tear down previous anchors; the instance tables are refilled below.
        for (var i = 0; i < _anchors.length; ++i) _anchors[i].destroy()
        _anchors = []

        var seed = cityData ? cityData.seed : 0
        _cars = CarGen.initCars(seed, _routes, carCount, baseSpeed)

        // Size cars to fit the narrowest lane, robust to tileSize.
        var lw = CarGen.minLaneWidth(_routes)
        _carW = 0.60 * lw
        _carL = 2.30 * _carW
        _carH = 0.85 * _carW
        _refreshLayout()

        // Derive the car-following gaps from the car size / lane width.
        _minGap = _carL * 0.5 + 1.0        // standstill bumper gap
        _spawnGap = _carL * 2.2            // entry spacing when re-entering the tile
        _laneHalf = Math.max(1.4, 0.55 * lw) // "same lane" lateral tolerance

        var lay = _lay
        var bodyScale = Qt.vector3d(lay.bodyScale[0], lay.bodyScale[1], lay.bodyScale[2])
        var cabScale = Qt.vector3d(lay.cabScale[0], lay.cabScale[1], lay.cabScale[2])
        var winScale = Qt.vector3d(lay.winScale[0], lay.winScale[1], lay.winScale[2])
        var wheelScale = Qt.vector3d(lay.wheelScale[0], lay.wheelScale[1], lay.wheelScale[2])

        // Per-entry statics for each table: window/wheel instance colour is white
        // so their material tint (cyan glass / near-black) shows unchanged.
        var white = Qt.rgba(1, 1, 1, 1)
        var n = _cars.length
        var bodyScales = [], bodyColors = []
        var cabScales = [], cabColors = []
        var winScales = [], winColors = []
        var wheelScales = [], wheelColors = []
        var anchors = []
        for (i = 0; i < n; ++i) {
            var car = _cars[i]
            _seedYaw(car)
            var pc = Qt.color(_palette[car.paint % _palette.length])
            var dc = _paletteDark[car.paint % _paletteDark.length]
            bodyScales.push(bodyScale); bodyColors.push(pc)
            cabScales.push(cabScale); cabColors.push(dc)
            winScales.push(winScale); winColors.push(white)
            for (var w = 0; w < 4; ++w) { wheelScales.push(wheelScale); wheelColors.push(white) }
            anchors.push(anchorComp.createObject(carSys, {}))
        }
        _anchors = anchors

        bodyInst.setBulk(bodyScales, bodyColors)
        cabinInst.setBulk(cabScales, cabColors)
        winInst.setBulk(winScales, winColors)
        wheelInst.setBulk(wheelScales, wheelColors)

        // Reused per-frame pose buffers: 4 floats (x, y, z, yaw) per entry.
        _bodyBuf = new Float32Array(n * 4)
        _cabinBuf = new Float32Array(n * 4)
        _winBuf = new Float32Array(n * 4)
        _wheelBuf = new Float32Array(n * 4 * 4)
        _sampleCache = new Array(n)

        // Declare the tile's roaming volume so the tables skip the per-upload
        // bounds rescan (cars stay within the tile bounds, plus a car-length pad
        // for edge respawns).
        if (cityData && cityData.bounds) {
            var b = cityData.bounds
            var mn = Qt.vector3d(b.xmin - _carL, roadY - _carH, b.zmin - _carL)
            var mx = Qt.vector3d(b.xmax + _carL, roadY + _carH * 2, b.zmax + _carL)
            bodyInst.setExtents(mn, mx)
            cabinInst.setExtents(mn, mx)
            winInst.setExtents(mn, mx)
            wheelInst.setExtents(mn, mx)
        }

        _nearestCursor = 0
        _writeAll()
    }

    // Current XZ position + heading (radians) of a car, from its drive/turn state.
    // In drive mode the car may sit a lateral offset off the lane centre (a
    // mid-flight lane change); the offset rides along the right-of-travel vector.
    function _sample(car) {
        if (car.mode === 1 && car.curve) {
            var p = CarGen.bezPoint(car.curve, car.ct)
            var tg = CarGen.bezTangent(car.curve, car.ct)
            return { x: p.x, z: p.z, hx: tg.x, hz: tg.z }
        }
        var r = _routes[car.route]
        var cx = r.sx + r.dx * car.t, cz = r.sz + r.dz * car.t
        var lat = car.lat || 0
        if (lat !== 0) {
            var rx = -r.dz, rz = r.dx        // right of travel (right-hand traffic)
            cx += rx * lat; cz += rz * lat
        }
        return { x: cx, z: cz, hx: r.dx, hz: r.dz }
    }

    function _seedYaw(car) {
        var s = _sample(car)
        car.yaw = Math.atan2(s.hx, s.hz)
        car.yawInit = true
    }

    // Pack every car once and upload (used after a rebuild).
    function _writeAll() {
        if (!_bodyBuf) return
        for (var i = 0; i < _cars.length; ++i) _packCar(i, _sample(_cars[i]))
        _uploadPoses()
    }

    // One updatePoses() per instance table: the single upload that replaces the
    // per-instance property writes of the old InstanceList tables.
    function _uploadPoses() {
        bodyInst.updatePoses(0, _bodyBuf.buffer)
        cabinInst.updatePoses(0, _cabinBuf.buffer)
        winInst.updatePoses(0, _winBuf.buffer)
        wheelInst.updatePoses(0, _wheelBuf.buffer)
    }

    // Pack a single car's part poses (position + yaw) into all four table
    // buffers + move its anchor, given its current sample `s` (position +
    // heading). Kept allocation-light: it is the per-frame hot path for every
    // car part (7 entries/car). The C++ table rebuilds each entry's rotation
    // from yaw, so only the part centre + yaw are written here.
    function _packCar(i, s) {
        var bx = s.x, bz = s.z
        var lay = _lay
        var yaw = _cars[i].yaw
        var cy = Math.cos(yaw), sy = Math.sin(yaw)
        var baseY = roadY

        // Rotate a car-local offset (lx,ly,lz) into world and lift to baseY.
        // Ry maps local +Z -> (sin,cos), local +X -> (cos,-sin) - the same
        // mapping the C++ table applies from yaw, so parts stay aligned.
        function put(buf, idx, off) {
            var o = idx * 4
            buf[o]     = bx + off[0] * cy + off[2] * sy
            buf[o + 1] = baseY + off[1]
            buf[o + 2] = bz - off[0] * sy + off[2] * cy
            buf[o + 3] = yaw
        }

        put(_bodyBuf, i, lay.bodyOff)
        put(_cabinBuf, i, lay.cabOff)
        put(_winBuf, i, lay.winOff)
        var wb = i * 4
        put(_wheelBuf, wb + 0, lay.wheelOff[0])
        put(_wheelBuf, wb + 1, lay.wheelOff[1])
        put(_wheelBuf, wb + 2, lay.wheelOff[2])
        put(_wheelBuf, wb + 3, lay.wheelOff[3])

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

        // ---- control logic ------------------------------------------------
        PerfRegistry.begin("carSim")
        // Advance the shared clock scaled by carSpeedFactor, then refresh the
        // per-junction light phase + box occupancy this whole frame keys off.
        var sdt = dt * carSpeedFactor
        simClock += sdt
        _computePhases()
        _computeOccupancy()

        // Longitudinal control (car-following + lights) then mode advance.
        for (var i = 0; i < n; ++i) _control(_cars[i], i, sdt)

        // Heading smoothing; cache each car's fresh sample for the pack pass.
        var steer = 1.0 - Math.exp(-_yawRate * dt)
        for (i = 0; i < n; ++i) {
            var car = _cars[i]
            var s = _sample(car)
            var target = Math.atan2(s.hx, s.hz)
            if (!car.yawInit) { car.yaw = target; car.yawInit = true }
            car.yaw = _lerpAngle(car.yaw, target, steer)
            _sampleCache[i] = s
        }
        PerfRegistry.end("carSim")

        // ---- pose packing + upload ---------------------------------------
        // Every entry's rotation is rebuilt in C++ from the packed yaw, so a
        // reseed at a tile edge (discontinuous car.yaw) always lands correctly
        // without the last-written-yaw gate the InstanceList path needed.
        PerfRegistry.begin("carPack")
        for (i = 0; i < n; ++i) _packCar(i, _sampleCache[i])
        _uploadPoses()
        PerfRegistry.end("carPack")

        _updateLights()
        updateNearestBatch()
    }

    // Distance before a route's end at which we plan the upcoming turn.
    readonly property real _planDist: 9.0

    // ---- traffic model --------------------------------------------------------

    // Refresh the light phase of every junction from the shared clock.
    function _computePhases() {
        var ph = []
        for (var i = 0; i < _inters.length; ++i)
            ph[i] = CarGen.lightPhase(simClock, _inters[i].x, _inters[i].z, _GREEN, _CLEAR)
        _phase = ph
    }

    // Record which travel axis currently occupies each junction box, so a car may
    // only enter a box that has no conflicting (perpendicular-axis) car in it -
    // the belt-and-braces guarantee that two streams never share the box.
    function _computeOccupancy() {
        var occ = []
        for (var j = 0; j < _inters.length; ++j) occ[j] = null
        for (var i = 0; i < _cars.length; ++i) {
            var car = _cars[i]
            var s = _sample(car)
            var ax
            if (car.mode === 1) ax = Math.abs(s.hx) > Math.abs(s.hz) ? "h" : "v"
            else ax = _routes[car.route].axis
            for (j = 0; j < _inters.length; ++j) {
                var nd = _inters[j]
                var dx = s.x - nd.x, dz = s.z - nd.z
                if (dx * dx + dz * dz < nd.radius * nd.radius)
                    occ[j] = (occ[j] === null || occ[j] === ax) ? ax : "both"
            }
        }
        _occ = occ
    }

    // Safe speed that can still stop within `dist` behind an obstacle moving at
    // `vLead`, holding a standstill margin `minGap` (Krauss-style law).
    function _safeSpeed(dist, vLead, minGap) {
        var g = dist - minGap
        if (g <= 0) return 0
        return Math.sqrt(vLead * vLead + 2 * _DECEL * g)
    }

    // Accelerate / brake the current speed toward `target` within the comfort
    // limits (scaled time so the whole sim slows with carSpeedFactor).
    function _approach(cur, target, sdt) {
        if (target > cur) return Math.min(target, cur + _ACCEL * sdt)
        return Math.max(target, cur - _DECEL_MAX * sdt)
    }

    // Nearest car ahead of car `i` in its own lane: forward distance (centre to
    // centre) + that leader's along-heading speed. Purely geometric so it catches
    // leaders across a junction and inside the box, and ignores oncoming / cross
    // lanes (they fall outside the narrow in-lane corridor).
    function _leaderGap(car, i) {
        var si = _sample(car)
        var hx = si.hx, hz = si.hz
        var px = -hz, pz = hx               // left perpendicular (for lateral test)
        var bestF = Infinity, vLead = 0
        for (var j = 0; j < _cars.length; ++j) {
            if (j === i) continue
            var sj = _sample(_cars[j])
            var dx = sj.x - si.x, dz = sj.z - si.z
            var f = dx * hx + dz * hz
            if (f <= 0 || f >= bestF || f > _LOOKAHEAD) continue
            var latd = dx * px + dz * pz
            if (latd < 0) latd = -latd
            if (latd > _laneHalf) continue
            bestF = f
            var oh = _cars[j].mode === 1 ? _sample(_cars[j]) : { hx: sj.hx, hz: sj.hz }
            var dotH = oh.hx * hx + oh.hz * hz
            vLead = dotH > 0.3 ? Math.max(0, _cars[j].speed * dotH) : 0
        }
        return { gap: bestF, vLead: vLead }
    }

    // Does the light (and box occupancy) require this route's car to hold at its
    // end junction right now?
    function _mustStop(r) {
        if (!r.endIsJunction) return false
        var ph = _phase[r.endJunc]
        if (!ph) return false
        if (ph.allRed) return true
        if (ph.green !== r.axis) return true
        var occ = _occ[r.endJunc]
        if (occ && occ !== r.axis) return true   // conflicting stream still in box
        return false
    }

    // Per-car longitudinal control: compute a target speed from the leader and
    // any red-light stop bar, integrate the speed, advance the mode.
    function _control(car, i, sdt) {
        if (car.otCool > 0) car.otCool = Math.max(0, car.otCool - sdt)

        var lead = _leaderGap(car, i)
        var v = Math.min(car.cruise, _safeSpeed(lead.gap - _carL, lead.vLead, _minGap))

        if (car.mode === 0) {
            var r = _routes[car.route]
            car.holdBox = false
            if (r.endIsJunction) {
                var barPos = Math.max(0, r.len - r.endRadius)
                var hold = _mustStop(r)
                // Keep the box clear (anti-gridlock): even on green, do NOT roll
                // into the junction unless there is room on the FAR side to fully
                // clear it. If a slow/stopped leader sits inside or just past the
                // box, hold at the bar so the box stays free for cross traffic.
                // Box-blocking is what turns congestion into a permanent lock;
                // this rule removes it (a red light alone does not).
                if (!hold && car.t < barPos && lead.gap < _LOOKAHEAD && lead.vLead < 2.0) {
                    var pastBar = lead.gap - (barPos - car.t)   // clear road beyond the bar
                    if (pastBar < 2 * r.endRadius + _carL + _minGap) hold = true
                }
                car.holdBox = hold
                if (hold) {
                    // front of the car should halt just shy of the stop bar
                    var vBar = _safeSpeed(barPos - car.t - _carL * 0.5, 0, 0.4)
                    if (vBar < v) v = vBar
                }
            }
            car.speed = _approach(car.speed, v, sdt)
            car.t += car.speed * sdt
            if (car.lat !== 0) {
                var k = Math.exp(-_latRate * sdt)
                car.lat *= k
                if (Math.abs(car.lat) < 0.02) car.lat = 0
            }
            _driveLogic(car, i)
        } else {
            car.speed = _approach(car.speed, v, sdt)
            car.ct += (car.speed * sdt) / car.clen
            _turnLogic(car)
        }
    }

    // Plan / begin turns, respawn at tile edges, consider overtaking. The car has
    // ALREADY been advanced this frame; this only handles mode transitions.
    function _driveLogic(car, i) {
        var r = _routes[car.route]

        if (car.otCool === 0 && Math.abs(car.lat) < 0.05)
            _considerLaneChange(car, i, r)

        if (!car.plan && car.t >= r.len - _planDist) {
            var rand = _junctionRand(car)
            var pick = CarGen.chooseNext(_routes, r.ex, r.ez, car.route, rand)
            car.turns = (car.turns + 1) >>> 0
            car.plan = pick >= 0 ? CarGen.planTurn(_routes, car.route, pick) : { respawn: true }
        }

        // Tile-edge end: re-enter as a fresh car at an inbound edge lane rather
        // than teleporting onto an unrelated track mid-road.
        if (car.plan && car.plan.respawn) {
            if (car.t >= r.len) _respawn(car)
            return
        }

        // Begin the planned turn only once allowed to cross the stop bar. Until
        // then hold at the bar - never roll a red, and never enter a box we
        // cannot clear (car.holdBox, set in _control, folds in both cases).
        if (car.plan && car.t >= car.plan.startT) {
            if (car.holdBox) {
                var stopT = Math.max(0, r.len - r.endRadius)
                if (car.t > stopT) car.t = stopT
                return
            }
            _beginTurn(car)
        }
    }

    function _beginTurn(car) {
        var ov = car.t - car.plan.startT
        car.curve = { p0: car.plan.p0, ctrl: car.plan.ctrl, p2: car.plan.p2 }
        car.clen = car.plan.len
        car.cnext = car.plan.toIdx
        car.cjoin = car.plan.joinTexit
        car.ct = Math.min(0.999, ov / car.plan.len)
        car.mode = 1
        car.plan = null
        car.lat = 0
    }

    function _turnLogic(car) {
        if (car.ct < 1.0) return
        var over = (car.ct - 1.0) * car.clen
        var nx = car.cnext
        car.route = nx
        car.mode = 0
        car.curve = null
        car.lat = 0
        car.t = Math.min(_routes[nx].len, car.cjoin + over)
    }

    // Re-enter the tile on an inbound edge lane, placed a safe gap behind the
    // nearest car already on that lane (t may be slightly negative = still off the
    // edge, so it drives IN and queues naturally - never a mid-road pop-in).
    function _respawn(car) {
        var start = CarGen.hash2(car.hash, car.turns) % _routes.length
        var best = -1, bestClear = -1e30
        for (var k = 0; k < _routes.length; ++k) {
            var idx = (start + k) % _routes.length
            if (!_routes[idx].inbound) continue
            var clear = _entryClear(idx)
            if (clear > bestClear) { bestClear = clear; best = idx }
        }
        if (best < 0) best = start
        car.route = best
        car.mode = 0
        car.plan = null; car.curve = null; car.ct = 0
        car.lat = 0; car.otCool = 0
        car.t = Math.min(0, bestClear - _spawnGap)
        car.speed = Math.min(car.speed, car.cruise)
        _seedYaw(car)
    }

    // Smallest arc position of any car currently on route `idx` (large if empty).
    function _entryClear(idx) {
        var m = 1e9
        for (var i = 0; i < _cars.length; ++i)
            if (_cars[i].route === idx && _cars[i].t < m) m = _cars[i].t
        return m
    }

    // Consider an overtaking lane change on a 2-lane avenue: move to the inner
    // lane when blocked by a slower leader, or drift back to the kerb lane once
    // there is room. Only when clear of the junction zones at both ends.
    function _considerLaneChange(car, i, r) {
        if (r.nLanes < 2 || r.sibling < 0) return
        if (car.t < _OT_MARGIN) return
        if (car.t > r.len - _OT_MARGIN - r.endRadius) return
        var lead = _leaderGap(car, i)
        var blocked = lead.gap - _carL < _OT_TRIGGER && lead.vLead < car.cruise * _OT_SLOWER
        var inInner = r.laneIdx < r.nLanes - 1
        if (blocked && !inInner) {
            if (_laneChangeFree(car, i, r.sibling)) _startLaneChange(car, r, r.sibling)
        } else if (!blocked && inInner) {
            if (lead.gap - _carL > _OT_RETURN && _laneChangeFree(car, i, r.sibling))
                _startLaneChange(car, r, r.sibling)
        }
    }

    // Is the target lane clear around the car's along position?
    function _laneChangeFree(car, i, sib) {
        var sr = _routes[sib]
        var tx = sr.sx + sr.dx * car.t, tz = sr.sz + sr.dz * car.t
        var hx = sr.dx, hz = sr.dz, px = -hz, pz = hx
        for (var j = 0; j < _cars.length; ++j) {
            if (j === i) continue
            var sj = _sample(_cars[j])
            var dx = sj.x - tx, dz = sj.z - tz
            var latd = dx * px + dz * pz
            if (latd < 0) latd = -latd
            if (latd > _laneHalf) continue
            var f = dx * hx + dz * hz
            if (f > -_OT_BACK && f < _OT_FRONT) return false
        }
        return true
    }

    // Switch to the sibling lane, seeding a lateral offset so the car visibly
    // slides across instead of snapping. Along position (t) carries over 1:1.
    function _startLaneChange(car, r, sib) {
        var sr = _routes[sib]
        var rx = -r.dz, rz = r.dx                 // right of travel
        var vx = sr.sx - r.sx, vz = sr.sz - r.sz  // constant lane offset vector
        var shift = vx * rx + vz * rz             // signed offset along right
        car.route = sib
        car.lat = (car.lat || 0) - shift          // start where it was, ease to 0
        car.otCool = _OT_COOLDOWN
        laneChanges += 1
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

    // ---- selection + lidar query helpers -------------------------------------
    // Current world pose (position + smoothed heading) of car i.
    function carPose(i) {
        if (i < 0 || i >= _cars.length) return null
        var car = _cars[i]
        var s = _sample(car)
        return { x: s.x, y: roadY + _carH * 0.5, z: s.z, yaw: car.yaw,
                 w: _carW, h: _carH, l: _carL }
    }

    // World position of any car currently mid lane-change (a visible lateral
    // offset off its lane centre), or null. Diagnostic aid for verification.
    function activeLaneChangePos() {
        for (var i = 0; i < _cars.length; ++i) {
            var c = _cars[i]
            if (c.mode === 0 && Math.abs(c.lat || 0) > 0.4) {
                var s = _sample(c)
                return Qt.vector3d(s.x, roadY, s.z)
            }
        }
        return null
    }

    // Index of the car nearest to (wx,wz) within radius r (world units), or -1.
    // Returns { index, d2 } so callers can compare across tiles.
    function nearestCar(wx, wz, r) {
        var best = -1, bestD = r * r
        for (var i = 0; i < _cars.length; ++i) {
            var s = _sample(_cars[i])
            var dx = s.x - wx, dz = s.z - wz
            var d2 = dx * dx + dz * dz
            if (d2 < bestD) { bestD = d2; best = i }
        }
        return { index: best, d2: bestD }
    }

    // Oriented boxes for every car whose center lies within `range` of (wx,wz),
    // excluding car `exclude`. Each box: { cx,cy,cz, hx,hy,hz, yaw } in world.
    // Fed to the lidar as the moving obstacles it must scan.
    function carBoxesInRange(wx, wz, range, exclude) {
        var out = []
        var r2 = range * range
        var hx = _carW * 0.5, hy = _carH * 0.5, hz = _carL * 0.5
        var cy = roadY + hy
        for (var i = 0; i < _cars.length; ++i) {
            if (i === exclude) continue
            var s = _sample(_cars[i])
            var dx = s.x - wx, dz = s.z - wz
            if (dx * dx + dz * dz > r2) continue
            out.push({ cx: s.x, cy: cy, cz: s.z, hx: hx, hy: hy, hz: hz,
                       yaw: _cars[i].yaw })
        }
        return out
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
