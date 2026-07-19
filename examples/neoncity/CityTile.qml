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
    property real carSpeedFactor: 0.4   // global traffic-speed multiplier
    property var connectorLayer: null   // shared ConnectorLayer3D (scene root)
    property var manager: null          // TileManager (transmitter registry)

    // Exposed so the selection / lidar path can query this tile's traffic.
    readonly property alias carSystem: carSystem

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

    // Elevation of the flat matte asphalt band and of everything that rides on
    // the road surface. Defined here so the lane paint and the cars both key off
    // the SAME road height (see laneOverlayY / CarSystem.roadY below).
    readonly property real asphaltY: 0.6

    // Lane paint sits a hair above the asphalt so it reads as painted ON the road
    // (not floating): a 0.1u physical gap the overlay's depthBias closes visually.
    readonly property real laneOverlayY: asphaltY + 0.1

    // ---- palette (bright daylight archviz) ----
    // White / very pale blue-grey building bodies with occasional pale pastel.
    readonly property var bodyColors: ["#eef2f6", "#dde6ee", "#e7ecf1", "#d6e2df", "#e8e2ee"]
    // Soft, NON-emissive pastel facade accents (pale teal / green / blue / sand).
    readonly property var accentColors: ["#9fc6c2", "#b7d3ac", "#c3d2df", "#e0d6a8"]
    readonly property color groundColor: "#c6cad0"
    readonly property color parkColor: "#bcd9ad"

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
            property color accentColor: "#9fc6c2"
            property var entries: []
            source: "#Cube"
            castsShadows: true
            receivesShadows: true
            instancing: InstanceList { instances: entries }
            // Lit (not emissive) so the roof accents read as pastel facade
            // detail in daylight rather than glowing neon caps.
            materials: PrincipledMaterial {
                baseColor: accentColor
                roughness: 0.85
                metalness: 0.0
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
                             colors: [{ color: "#e3e8ee", weight: 0.7 }, { color: "#d2dae2", weight: 0.3 }] } },
                    { box: { pos: Qt.vector3d(2, ny - 5, 2), width: cols - 4, height: 3, depth: cols - 4,
                             colors: [{ color: "#8fc3bd", weight: 1.0 }] } },
                    { box: { pos: Qt.vector3d(cols / 2 - 1, ny - 2, cols / 2 - 1), width: 2, height: 2, depth: 2,
                             colors: [{ color: "#e0917f", weight: 1.0 }] } }
                ])
                model.commit()
            }
        }
    }

    // Mid-grey matte asphalt: one instanced draw call per tile, all roads as
    // flat quads. High roughness, no emissive. Reads clearly as a road surface
    // in daylight - a touch darker than the light-grey ground so the white and
    // yellow painted markings pop on top.
    Component {
        id: asphaltComp
        Model {
            property var entries: []
            source: "#Rectangle"
            castsShadows: false
            receivesShadows: true
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial {
                baseColor: "#6a6d73"
                roughness: 1.0
                metalness: 0.0
            }
        }
    }

    // ---- roadside foliage: trees (trunk + canopy) as two instanced Models ----
    // A dark trunk cylinder and a teal canopy cone, one instanced draw call each
    // for the whole tile. They also serve as lidar obstacles (see citygen data).
    Component {
        id: treeTrunkComp
        Model {
            property var entries: []
            source: "#Cylinder"
            castsShadows: true
            receivesShadows: true
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial { baseColor: "#6b5a45"; roughness: 1.0 }
        }
    }
    Component {
        id: treeCanopyComp
        Model {
            property var entries: []
            source: "#Cone"
            castsShadows: true
            receivesShadows: true
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial { baseColor: "#4f9e57"; roughness: 0.9 }
        }
    }

    // ---- lamp posts: thin dark pole + small gold emissive head ----
    Component {
        id: lampPoleComp
        Model {
            property var entries: []
            source: "#Cylinder"
            castsShadows: false
            receivesShadows: false
            instancing: InstanceList { instances: entries }
            materials: PrincipledMaterial { baseColor: "#5a5e66"; roughness: 0.7; metalness: 0.3 }
        }
    }
    Component {
        id: lampHeadComp
        Model {
            property var entries: []
            source: "#Cube"
            castsShadows: false
            receivesShadows: false
            instancing: InstanceList { instances: entries }
            // Lit muted lamp housing (daylight): not a glowing neon head.
            materials: PrincipledMaterial {
                baseColor: "#4a4d54"
                roughness: 0.6
                metalness: 0.2
            }
        }
    }

    // ---- per-tile ground plate ----
    // pickable so the click-to-inspect ray lands a world point on the ground
    // (the nearest-car search then keys off that hit position).
    Model {
        source: "#Rectangle"
        pickable: true
        eulerRotation.x: -90
        position: Qt.vector3d(tile.tileX * tile.tileSize + tile.tileSize / 2, 0,
                              tile.tileZ * tile.tileSize + tile.tileSize / 2)
        scale: Qt.vector3d(tile.tileSize / 100, tile.tileSize / 100, 1)
        receivesShadows: true
        materials: PrincipledMaterial { baseColor: tile.groundColor; roughness: 1.0 }
    }

    // ---- subtle curb / edge glow ----
    // A thin, dim strip along the road outer edges. Shown only when the lane
    // overlay is OFF, so it never competes with the overlay's crisp curb lines.
    LineBatch3D {
        id: roads
        widthUnits: LineBatch3D.Pixel
        viewportSize: tile.viewportSize
        depthBias: 3
        visible: !tile.showLanes
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
        roadY: tile.asphaltY
        carCount: tile.carsPerTile
        carSpeedFactor: tile.carSpeedFactor
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
        buildFoliage(data)
        buildLanes(data)
    }

    // Trees + lamp posts, each part a single instanced draw call for the tile.
    function buildFoliage(data) {
        var trunkE = [], canopyE = [], poleE = [], headE = []
        for (var i = 0; i < data.trees.length; ++i) {
            var t = data.trees[i]
            trunkE.push(entryComp.createObject(tile, {
                position: Qt.vector3d(t.x, t.trunkH / 2, t.z),
                scale: Qt.vector3d(t.trunkR / 50, t.trunkH / 100, t.trunkR / 50)
            }))
            // #Cone origin sits at its BASE (local y 0..100), unlike the
            // center-origin #Cube/#Cylinder, so the canopy base rides exactly on
            // the trunk top (trunkH) - no half-canopy gap above the trunk.
            canopyE.push(entryComp.createObject(tile, {
                position: Qt.vector3d(t.x, t.trunkH, t.z),
                scale: Qt.vector3d(t.canopyR / 50, t.canopyH / 100, t.canopyR / 50)
            }))
        }
        for (i = 0; i < data.lamps.length; ++i) {
            var lp = data.lamps[i]
            poleE.push(entryComp.createObject(tile, {
                position: Qt.vector3d(lp.x, lp.h / 2, lp.z),
                scale: Qt.vector3d(0.3 / 50, lp.h / 100, 0.3 / 50)
            }))
            headE.push(entryComp.createObject(tile, {
                position: Qt.vector3d(lp.x, lp.h + 0.4, lp.z),
                scale: Qt.vector3d(1.1 / 100, 1.1 / 100, 1.1 / 100)
            }))
        }
        if (trunkE.length > 0) treeTrunkComp.createObject(tile, { entries: trunkE })
        if (canopyE.length > 0) treeCanopyComp.createObject(tile, { entries: canopyE })
        if (poleE.length > 0) lampPoleComp.createObject(tile, { entries: poleE })
        if (headE.length > 0) lampHeadComp.createObject(tile, { entries: headE })
    }

    function buildLanes(data) {
        var lm = LaneGen.generateLaneModel(data, tile.laneOverlayY)
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

        // ---- flat matte asphalt bands (one instanced draw call) ----
        var asphalt = []
        for (var i = 0; i < n; ++i) {
            var cl = rs[i].centerline
            var horiz = rs[i].axis === "h"
            var a0 = cl[0], a1 = cl[cl.length - 1]
            var cx = (a0.x + a1.x) * 0.5, cz = (a0.z + a1.z) * 0.5
            var len = (horiz ? Math.abs(a1.x - a0.x) : Math.abs(a1.z - a0.z)) + rs[i].width
            var sx = (horiz ? len : rs[i].width) / 100
            var sz = (horiz ? rs[i].width : len) / 100
            asphalt.push(entryComp.createObject(tile, {
                position: Qt.vector3d(cx, tile.asphaltY, cz),
                scale: Qt.vector3d(sx, sz, 1),
                eulerRotation: Qt.vector3d(-90, 0, 0)
            }))
        }
        asphaltComp.createObject(tile, { entries: asphalt })

        // ---- subtle curb / edge glow (two dim lines per road at +-half) ----
        var totalPts = n * 4 // two 2-point edges per road
        var positions = new Float32Array(totalPts * 3)
        var starts = new Uint32Array(2 * n + 1)
        var colors = new Uint8Array(2 * n * 4)
        var widths = new Float32Array(2 * n)

        var glowY = 0.8
        var p = 0, li = 0
        for (i = 0; i < n; ++i) {
            var r = rs[i]
            var h = r.width * 0.5
            var pe = r.axis === "h" ? { x: 0, z: 1 } : { x: -1, z: 0 }
            var c0 = r.centerline[0], c1 = r.centerline[r.centerline.length - 1]
            for (var s = -1; s <= 1; s += 2) {
                starts[li] = p
                positions[p * 3 + 0] = c0.x + pe.x * s * h; positions[p * 3 + 1] = glowY
                positions[p * 3 + 2] = c0.z + pe.z * s * h; p++
                positions[p * 3 + 0] = c1.x + pe.x * s * h; positions[p * 3 + 1] = glowY
                positions[p * 3 + 2] = c1.z + pe.z * s * h; p++
                // Dim teal curb strip - reads as a faint edge, not a lane line.
                colors[li * 4 + 0] = 20; colors[li * 4 + 1] = 90
                colors[li * 4 + 2] = 96; colors[li * 4 + 3] = 255
                widths[li] = 1.3
                li++
            }
        }
        starts[2 * n] = p

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
