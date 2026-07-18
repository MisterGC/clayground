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

    // ---- live readouts (polled by the HUD) ----
    property int currentTileX: 0
    property int currentTileZ: 0
    property int loadedCount: 0
    property int buildingCount: 0

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
            _tiles[kk] = inc.object
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
        var c = 0, b = 0
        for (var k in _tiles) { c++; b += _tiles[k].buildingCount }
        loadedCount = c
        buildingCount = b
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
