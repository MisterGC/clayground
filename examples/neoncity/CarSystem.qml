// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Per-tile traffic + transmitters for the neoncity demo (Phase 5, part 2).
//
// Cars are drawn as ONE instanced draw call (InstanceList of emissive cubes)
// and driven along the deterministic right-hand lane routes from cargen.js.
// Each car also owns an invisible anchor Node carrying a Connector3D into the
// shared ConnectorLayer3D; the connector links the car to its current nearest
// transmitter, recomputed round-robin (~2x/s) rather than every frame.
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
    property real laneY: 1.8
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
    property var _entries: []       // InstanceListEntry, one per car
    property var _anchors: []       // Node, one per car (connector endpoint)
    property var _transmitters: []  // Transmitter nodes owned by this tile
    property int _nearestCursor: 0
    readonly property real _carLift: 1.4   // cars ride slightly above the lanes
    property bool _coreBuilt: false        // routes + cars built (needs cityData)
    property bool _txBuilt: false          // transmitters built + registered

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

    // ---- car visuals: single instanced draw call ----
    Model {
        id: carModel
        source: "#Cube"
        visible: carSys.showCars
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { id: carInstances; instances: carSys._entries }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#fff2cc"
        }
    }

    // cityData (from tile.build) and manager (from TileManager.onReady) arrive
    // in an unspecified order relative to this component's completion, so build
    // idempotently whenever the missing input shows up.
    Component.onCompleted: tryBuild()
    Component.onDestruction: releaseTransmitters()

    onCityDataChanged: tryBuild()
    onManagerChanged: tryBuild()
    onCarCountChanged: if (_coreBuilt) rebuildCars()

    function tryBuild() {
        if (cityData && !_coreBuilt) {
            _coreBuilt = true
            _routes = CarGen.buildRoutes(cityData, laneY)
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

    function rebuildCars() {
        // Tear down previous car objects.
        for (var i = 0; i < _anchors.length; ++i) _anchors[i].destroy()
        _entries = []
        _anchors = []

        var seed = cityData ? cityData.seed : 0
        _cars = CarGen.initCars(seed, _routes, carCount, baseSpeed)

        var entries = []
        var anchors = []
        for (i = 0; i < _cars.length; ++i) {
            var p = carPos(_cars[i])
            entries.push(entryComp.createObject(carSys, {
                position: p,
                scale: Qt.vector3d(0.035, 0.022, 0.05)  // small emissive box
            }))
            anchors.push(anchorComp.createObject(carSys, { position: p }))
        }
        _entries = entries
        _anchors = anchors
        _nearestCursor = 0
    }

    function carPos(car) {
        var r = _routes[car.route]
        return Qt.vector3d(r.sx + r.dx * car.t, laneY + _carLift, r.sz + r.dz * car.t)
    }

    function advance(dt) {
        var n = _cars.length
        if (n === 0 || _routes.length === 0) return

        for (var i = 0; i < n; ++i) {
            var car = _cars[i]
            var r = _routes[car.route]
            car.t += car.speed * dt
            var guard = 0
            while (car.t >= r.len && guard < 4) {
                var over = car.t - r.len
                var nx = CarGen.nextRoute(_routes, r.ex, r.ez, car.route)
                if (nx < 0) nx = (car.route + 7) % _routes.length // respawn onward
                car.route = nx
                r = _routes[nx]
                car.t = over % Math.max(1.0, r.len)
                guard++
            }
            var p = carPos(car)
            _entries[i].position = p
            _anchors[i].position = p
        }

        updateNearestBatch()
    }

    // Recompute the nearest transmitter for a slice of cars each frame so every
    // car refreshes about twice a second at 60 fps.
    function updateNearestBatch() {
        var tx = (manager && manager.transmitters) ? manager.transmitters : []
        var n = _cars.length
        if (n === 0) return
        if (tx.length === 0) {
            // No targets: clear so connectors hide.
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
            carSys.advance(dt)
        }
    }
}
