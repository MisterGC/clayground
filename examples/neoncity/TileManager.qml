// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Streams CityTiles around the camera. Tiles within streamRadius (Chebyshev)
// are materialized asynchronously via incubation so appearing tiles never
// hitch the camera; tiles past unloadRadius are destroyed (hysteresis keeps
// the boundary from thrashing).

import QtQuick
import QtQuick3D

Node {
    id: mgr

    property var camera: null
    property real tileSize: 200
    property int globalSeed: 42
    property int streamRadius: 2                       // (2r+1)^2 neighborhood
    property int unloadRadius: streamRadius + 1        // hysteresis margin

    // ---- overlay controls (forwarded to every tile as live bindings) ----
    property bool showLanes: true
    property bool showCars: true
    property bool showConnections: true
    property bool showLabels: false      // global label layer: street names (HUD "N")
    property real laneFlowTime: 0        // shared chevron-flow clock (see CityView3D)
    property int carsPerTile: 8
    property real carSpeedFactor: 0.4
    property var connectorLayer: null
    property vector2d viewportSize: Qt.vector2d(1920, 1080)

    // ---- global transmitter registry (cars pick the nearest across tiles) ----
    property var transmitters: []
    function registerTransmitter(n) {
        var a = transmitters.slice()
        a.push(n)
        transmitters = a
    }
    function unregisterTransmitter(n) {
        var a = transmitters.slice()
        var i = a.indexOf(n)
        if (i >= 0) { a.splice(i, 1); transmitters = a }
    }

    // ---- live readouts (polled by the HUD) ----
    property int currentTileX: 0
    property int currentTileZ: 0
    property int loadedCount: 0
    property int buildingCount: 0
    property int laneLineCount: 0
    property int lanePointCount: 0

    // Snapshot of currently loaded tiles (for the exporter / car system).
    function loadedTiles() {
        var out = []
        for (var k in _tiles) out.push(_tiles[k])
        return out
    }

    // ---- selection + lidar aggregation across streamed tiles ----------------
    // Nearest car to a world point within `radius`, searched across every loaded
    // tile's traffic. Returns { carSystem, index } or null.
    function pickNearestCar(wx, wz, radius) {
        var best = null, bestD = radius * radius
        for (var k in _tiles) {
            var cs = _tiles[k].carSystem
            if (!cs) continue
            var r = cs.nearestCar(wx, wz, radius)
            if (r.index >= 0 && r.d2 < bestD) { bestD = r.d2; best = { carSystem: cs, index: r.index } }
        }
        return best
    }

    // City data of tiles whose footprint lies within `range` of (wx,wz) - the
    // lidar's static obstacle sources (buildings/trees/lamps/landmarks).
    function nearbyCityData(wx, wz, range) {
        var out = []
        var reach = range + 8
        for (var k in _tiles) {
            var d = _tiles[k].cityData
            if (!d) continue
            var b = d.bounds
            var nx = Math.max(b.xmin, Math.min(wx, b.xmax))
            var nz = Math.max(b.zmin, Math.min(wz, b.zmax))
            var dx = nx - wx, dz = nz - wz
            if (dx * dx + dz * dz <= reach * reach) out.push(d)
        }
        return out
    }

    // Oriented boxes of all cars within `range`, excluding the selected car.
    function carBoxesNear(wx, wz, range, exclCs, exclIdx) {
        var out = []
        for (var k in _tiles) {
            var cs = _tiles[k].carSystem
            if (!cs) continue
            var ex = (cs === exclCs) ? exclIdx : -1
            var arr = cs.carBoxesInRange(wx, wz, range, ex)
            for (var i = 0; i < arr.length; ++i) out.push(arr[i])
        }
        return out
    }

    // Regenerating on these changes keeps the demo honest when seed/size move.
    onGlobalSeedChanged: rebuild()
    onTileSizeChanged: rebuild()

    property var _tiles: ({})       // key -> CityTile object
    property var _incubators: ({})  // key -> incubator (in flight)

    Component { id: tileComp; CityTile {} }

    function key(x, z) { return x + "," + z }

    function rebuild() {
        for (var k in _tiles) { _tiles[k].destroy(); }
        for (var j in _incubators) { _incubators[j].forceCompletion(); if (_incubators[j].object) _incubators[j].object.destroy(); }
        _tiles = ({})
        _incubators = ({})
        loadedCount = 0
        buildingCount = 0
        update()
    }

    function ensureLoaded(x, z) {
        var kk = key(x, z)
        if (_tiles[kk] !== undefined || _incubators[kk] !== undefined) return

        var inc = tileComp.incubateObject(mgr, {
            tileX: x, tileZ: z, tileSize: mgr.tileSize, globalSeed: mgr.globalSeed
        }, Qt.Asynchronous)

        function onReady() {
            var t = inc.object
            t.manager = mgr
            t.connectorLayer = mgr.connectorLayer
            // Live bindings so runtime toggles / resizes reach every tile.
            t.showLanes = Qt.binding(function () { return mgr.showLanes })
            t.laneFlowTime = Qt.binding(function () { return mgr.laneFlowTime })
            t.showCars = Qt.binding(function () { return mgr.showCars })
            t.showConnections = Qt.binding(function () { return mgr.showConnections })
            t.showLabels = Qt.binding(function () { return mgr.showLabels })
            t.carsPerTile = Qt.binding(function () { return mgr.carsPerTile })
            t.carSpeedFactor = Qt.binding(function () { return mgr.carSpeedFactor })
            t.viewportSize = Qt.binding(function () { return mgr.viewportSize })
            _tiles[kk] = t
            delete _incubators[kk]
            console.log("neoncity: tile loaded", kk, "loaded=" + Object.keys(_tiles).length)
            recount()
        }

        if (inc.status === Component.Ready) {
            onReady()
        } else {
            _incubators[kk] = inc
            inc.onStatusChanged = function (status) { if (status === Component.Ready) onReady() }
        }
    }

    function unloadTile(kk) {
        if (_tiles[kk]) { _tiles[kk].destroy(); delete _tiles[kk] }
        console.log("neoncity: tile unloaded", kk)
    }

    function recount() {
        var c = 0, b = 0, ll = 0, lp = 0
        for (var k in _tiles) {
            c++
            b += _tiles[k].buildingCount
            ll += _tiles[k].laneLineCount
            lp += _tiles[k].lanePointCount
        }
        loadedCount = c
        buildingCount = b
        laneLineCount = ll
        lanePointCount = lp
    }

    function update() {
        if (!camera) return
        var cx = Math.floor(camera.position.x / tileSize)
        var cz = Math.floor(camera.position.z / tileSize)
        currentTileX = cx
        currentTileZ = cz

        var r = streamRadius
        for (var dz = -r; dz <= r; ++dz)
            for (var dx = -r; dx <= r; ++dx)
                ensureLoaded(cx + dx, cz + dz)

        var ur = unloadRadius
        for (var k in _tiles) {
            var parts = k.split(",")
            var tx = parseInt(parts[0]), tz = parseInt(parts[1])
            if (Math.abs(tx - cx) > ur || Math.abs(tz - cz) > ur) unloadTile(k)
        }
        recount()
    }

    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: mgr.update()
    }

    Component.onCompleted: update()
}
