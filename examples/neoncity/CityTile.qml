// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// One city tile: turns the pure data from citygen.js into GPU-friendly visuals.
// Buildings are drawn as instanced #Cube models bucketed by color (one draw
// call per color/accent bucket), roads as glowing LineBatch3D polylines, and
// the occasional hero building as a StaticVoxelMap tower.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import "citygen.js" as CityGen
import "lanegen.js" as LaneGen

Node {
    id: tile

    // ---- inputs (set at incubation time) ----
    property int tileX: 0
    property int tileZ: 0
    property real tileSize: 200
    property int globalSeed: 42

    // ---- overlay controls (bound live from CityView3D) ----
    property vector2d viewportSize: Qt.vector2d(1920, 1080)
    property bool showLanes: true
    property bool showCars: true
    property bool showConnections: true
    property int carsPerTile: 8
    property var connectorLayer: null   // shared ConnectorLayer3D (scene root)
    property var manager: null          // TileManager (transmitter registry)

    // ---- readouts ----
    readonly property int buildingCount: _buildingCount
    property int _buildingCount: 0
    readonly property int laneLineCount: _laneLineCount
    readonly property int lanePointCount: _lanePointCount
    property int _laneLineCount: 0
    property int _lanePointCount: 0

    // Kept so LaneOverlay / cars / the exporter can read the tile without
    // regenerating: city graph + derived detailed lane model.
    property var cityData: null
    property var laneModel: null

    // Elevation of the lane overlay (world units), just above the road glow.
    readonly property real laneY: 1.8

    // ---- palette ----
    readonly property var bodyColors: ["#14142a", "#1b1b34", "#22203c", "#0f1a2a", "#271a34"]
    readonly property var accentColors: ["#00d9ff", "#0f9d9a", "#ff3366", "#ffd93d"]
    readonly property color groundColor: "#0a0a16"
    readonly property color parkColor: "#0f2e2c"

    // ---- reusable factories ----
    Component { id: entryComp; InstanceListEntry {} }

    Component {
        id: bodyBucketComp
        Model {
            property color bodyColor: "white"
            property var entries: []
            source: "#Cube"
            castsShadows: true
            receivesShadows: true
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial {
                baseColor: bodyColor
                roughness: 0.95
                metalness: 0.0
            }
        }
    }

    Component {
        id: accentBucketComp
        Model {
            property color accentColor: "#00d9ff"
            property var entries: []
            source: "#Cube"
            castsShadows: false
            receivesShadows: false
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: accentColor
            }
        }
    }

    Component {
        id: parkComp
        Model {
            property real w: 10
            property real d: 10
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(w / 100, d / 100, 1)
            y: 0.4
            receivesShadows: true
            materials: PrincipledMaterial { baseColor: tile.parkColor; roughness: 1.0 }
        }
    }

    Component {
        id: landmarkComp
        StaticVoxelMap {
            property real footprint: 40
            property real towerHeight: 240
            readonly property real vs: 4.0
            readonly property int cols: 10
            voxelCountX: cols
            voxelCountZ: cols
            voxelCountY: Math.max(20, Math.round(towerHeight / vs))
            voxelSize: vs
            showEdges: true
            edgeColorFactor: 0.6
            useToonShading: true
            Component.onCompleted: {
                var ny = voxelCountY
                fill([
                    { box: { pos: Qt.vector3d(1, 0, 1), width: cols - 2, height: ny - 5, depth: cols - 2,
                             colors: [{ color: "#1a1a30", weight: 0.7 }, { color: "#22203c", weight: 0.3 }] } },
                    { box: { pos: Qt.vector3d(2, ny - 5, 2), width: cols - 4, height: 3, depth: cols - 4,
                             colors: [{ color: "#00d9ff", weight: 1.0 }] } },
                    { box: { pos: Qt.vector3d(cols / 2 - 1, ny - 2, cols / 2 - 1), width: 2, height: 2, depth: 2,
                             colors: [{ color: "#ff3366", weight: 1.0 }] } }
                ])
                model.commit()
            }
        }
    }

    // ---- per-tile ground plate ----
    Model {
        source: "#Rectangle"
        eulerRotation.x: -90
        position: Qt.vector3d(tile.tileX * tile.tileSize + tile.tileSize / 2, 0,
                              tile.tileZ * tile.tileSize + tile.tileSize / 2)
        scale: Qt.vector3d(tile.tileSize / 100, tile.tileSize / 100, 1)
        receivesShadows: true
        materials: PrincipledMaterial { baseColor: tile.groundColor; roughness: 1.0 }
    }

    // ---- road glow ----
    LineBatch3D {
        id: roads
        widthUnits: LineBatch3D.World
        depthBias: 0
    }

    // ---- detailed lane model overlay (Phase 5 headline) ----
    LaneOverlay {
        id: laneOverlay
        laneModel: tile.laneModel
        viewportSize: tile.viewportSize
        visible: tile.showLanes
    }

    // ---- cars + transmitters + connectors ----
    CarSystem {
        id: carSystem
        cityData: tile.cityData
        laneY: tile.laneY
        carCount: tile.carsPerTile
        showCars: tile.showCars
        connectorLayer: tile.connectorLayer
        manager: tile.manager
    }

    Component.onCompleted: build()

    function build() {
        var data = CityGen.generateTile(tile.globalSeed, tile.tileX, tile.tileZ, tile.tileSize)
        tile.cityData = data
        tile._buildingCount = data.buildings.length

        buildBuildings(data)
        buildRoads(data)
        buildParks(data)
        buildLandmarks(data)
        buildLanes(data)
    }

    function buildLanes(data) {
        var lm = LaneGen.generateLaneModel(data, tile.laneY)
        tile.laneModel = lm
        tile._laneLineCount = lm.lineCount
        tile._lanePointCount = lm.pointCount
    }

    function buildBuildings(data) {
        var bodyBuckets = [[], [], [], [], []]
        var accentBuckets = [[], [], [], []]

        for (var i = 0; i < data.buildings.length; ++i) {
            var b = data.buildings[i]
            bodyBuckets[b.colorIndex].push(entryComp.createObject(tile, {
                position: Qt.vector3d(b.x, b.height / 2, b.z),
                scale: Qt.vector3d(b.w / 100, b.height / 100, b.d / 100)
            }))
            if (b.accent) {
                var capH = 5
                accentBuckets[b.accentIndex].push(entryComp.createObject(tile, {
                    position: Qt.vector3d(b.x, b.height + capH / 2, b.z),
                    scale: Qt.vector3d(b.w * 0.5 / 100, capH / 100, b.d * 0.5 / 100)
                }))
            }
        }

        for (i = 0; i < bodyBuckets.length; ++i)
            if (bodyBuckets[i].length > 0)
                bodyBucketComp.createObject(tile, { bodyColor: tile.bodyColors[i], entries: bodyBuckets[i] })

        for (i = 0; i < accentBuckets.length; ++i)
            if (accentBuckets[i].length > 0)
                accentBucketComp.createObject(tile, { accentColor: tile.accentColors[i], entries: accentBuckets[i] })
    }

    function buildRoads(data) {
        var rs = data.roads
        var n = rs.length
        if (n === 0) return

        var totalPts = 0
        for (var i = 0; i < n; ++i) totalPts += rs[i].centerline.length

        var positions = new Float32Array(totalPts * 3)
        var starts = new Uint32Array(n + 1)
        var colors = new Uint8Array(n * 4)
        var widths = new Float32Array(n)

        var glowY = 1.2
        var p = 0
        for (i = 0; i < n; ++i) {
            starts[i] = p
            var cl = rs[i].centerline
            for (var j = 0; j < cl.length; ++j) {
                positions[p * 3 + 0] = cl[j].x
                positions[p * 3 + 1] = glowY
                positions[p * 3 + 2] = cl[j].z
                p++
            }
            // Spines glow pink, feeders glow cyan.
            var spine = rs[i].kind === "spine"
            colors[i * 4 + 0] = spine ? 255 : 0
            colors[i * 4 + 1] = spine ? 51 : 217
            colors[i * 4 + 2] = spine ? 102 : 255
            colors[i * 4 + 3] = 255
            widths[i] = spine ? 3.5 : 2.2
        }
        starts[n] = p

        roads.setBulk(positions.buffer, starts.buffer, colors.buffer, widths.buffer)
    }

    function buildParks(data) {
        for (var i = 0; i < data.parks.length; ++i) {
            var pk = data.parks[i]
            parkComp.createObject(tile, { x: pk.x, z: pk.z, w: pk.w, d: pk.d })
        }
    }

    function buildLandmarks(data) {
        for (var i = 0; i < data.landmarks.length; ++i) {
            var lm = data.landmarks[i]
            var span = 10 * 4.0 // cols * voxelSize
            landmarkComp.createObject(tile, {
                x: lm.x - span / 2, y: 0, z: lm.z - span / 2,
                footprint: lm.footprint, towerHeight: lm.height
            })
        }
    }
}
