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
    property bool showLabels: false      // global label layer: street names (N)
    property real laneFlowTime: 0        // drives the lane-model chevron flow
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
    // regenerating: city graph + derived painted markings + detailed lane model.
    property var cityData: null
    property var laneMarkings: null
    property var laneModel: null

    // Street-name placement: one entry per named road { lineId, name, worldH },
    // where lineId indexes the invisible nameLines carrier below.
    property var streetNameModel: []

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

    // ---- painted road markings (real furniture, ALWAYS drawn) ----
    // White edge / lane lines, double-yellow avenue centres and stop bars. This
    // is road paint, not map data, so it is never gated by the lane toggle.
    LaneOverlay {
        id: markings
        laneModel: tile.laneMarkings
        viewportSize: tile.viewportSize
        visible: true
        // Road paint is world geometry: marking widths are emitted in world
        // units (proportional to lane width), unlike the pixel-width map layer.
        widthUnits: LineBatch3D.World
        // Lie flat on the ground so stripes never billboard-shear at oblique
        // views (subtle for thin paint, but keeps it perfectly on the road).
        orientation: LineBatch3D.Flat
    }

    // ---- detailed lane model overlay (toggleable teal map layer) ----
    // The cyan lane centerlines + junction connectors + arrowhead tips; governed
    // by the HUD "Lanes (L)" toggle. Pixel-width map layer. The direction glyphs
    // (styleId 2) are excluded here and drawn by directionGlyphs below in a
    // world-units batch so they keep world proportions at every zoom.
    LaneOverlay {
        id: laneOverlay
        laneModel: tile.laneModel
        viewportSize: tile.viewportSize
        visible: tile.showLanes
        flowTime: tile.laneFlowTime
        styleFilter: function(s) { return s !== 2 }
    }

    // ---- direction glyphs (filled triangles, styleId 2) ----
    // Same lane model, but ONLY the direction-glyph lines, rendered in a
    // WORLD-units batch: their width (TRI_WID) is a world measure, so the filled
    // triangle keeps its proportions when zooming in (a screen-px width pinned
    // the ribbon while the world period stretched, degenerating the glyph). Part
    // of the lane overlay layer, so it shares the "Lanes (L)" toggle and the flow
    // clock.
    LaneOverlay {
        id: directionGlyphs
        laneModel: tile.laneModel
        viewportSize: tile.viewportSize
        visible: tile.showLanes
        flowTime: tile.laneFlowTime
        widthUnits: LineBatch3D.World
        // Lie flat in the ground plane: a billboarded world-width ribbon tilts
        // its across axis out of the plane at top-down/oblique views, shearing
        // the filled triangles. Flat keeps them symmetric on the road.
        orientation: LineBatch3D.Flat
        styleFilter: function(s) { return s === 2 }
    }

    // ---- street-name centerlines (invisible carrier for the name labels) ----
    // PathLabel3D rides a LineBatch3D's geometry; this batch exists only to feed
    // pathLength()/positionAt() with one centerline per named road. It is never
    // drawn (visible:false) - the visible cyan lane centerlines belong to the
    // lane-model overlay above and would fight the name text if reused. The path
    // geometry is CPU-side, so pathLength() stays valid even undrawn.
    LineBatch3D {
        id: nameLines
        visible: false
        viewportSize: tile.viewportSize
        widthUnits: LineBatch3D.World
        styles: [{ dash: [0, 0], capRound: true, opacity: 0 }]
    }

    // ---- street names (real-map-style, flat on the road) ----
    // One name per road, painted along its centerline the way a map paints a
    // street name. Governed by the HUD "Names (N)" toggle and, being tile
    // content, streams in and out with the tile. Dark ink + light casing reads
    // on the mid-grey asphalt without shouting over the lane paint.
    Repeater3D {
        // Gated on the toggle: with names off (the default) no PathLabel3D exists
        // and no word textures rasterize as tiles stream, so the layer is free
        // until switched on. Toggling on builds the labels for loaded tiles.
        model: tile.showLabels ? tile.streetNameModel : []
        delegate: PathLabel3D {
            id: nameLabel
            required property var modelData
            lines: nameLines
            lineId: nameLabel.modelData.lineId
            text: nameLabel.modelData.name
            worldHeight: nameLabel.modelData.worldH
            groundOffset: tile.laneOverlayY + 0.25
            labelStyle.textColor: "#12141c"
            labelStyle.haloColor: "#f2f4f8"
        }
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
        buildStreetNames(data)
    }

    // Feeds the invisible nameLines carrier one straight centerline per named
    // road and builds the matching label model. Text height is proportional to
    // the carriageway width so avenues read larger than side streets.
    function buildStreetNames(data) {
        var roads = data.roads
        var lines = []
        var model = []
        for (var i = 0; i < roads.length; ++i) {
            var r = roads[i]
            if (!r.name) continue
            var cl = r.centerline
            lines.push({
                points: [Qt.vector3d(cl[0].x, tile.laneOverlayY, cl[0].z),
                         Qt.vector3d(cl[1].x, tile.laneOverlayY, cl[1].z)],
                color: "#ffffff", width: 1, styleId: 0
            })
            model.push({ lineId: lines.length - 1, name: r.name,
                         worldH: Math.max(5, r.width * 0.7) })
        }
        nameLines.lines = lines
        tile.streetNameModel = model
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
        tile.laneMarkings = LaneGen.generateMarkings(data, tile.laneOverlayY)
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

        // ---- flat matte asphalt: road bands + junction patches ----
        // All roads and crossings share ONE instanced draw call. Each road is a
        // band along its length; each junction adds a square patch so the corners
        // of a crossing are fully paved (no unpaved notches at the box).
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
        var inters = data.intersections
        for (i = 0; i < inters.length; ++i) {
            var side = inters[i].radius * 2.0
            asphalt.push(entryComp.createObject(tile, {
                position: Qt.vector3d(inters[i].x, tile.asphaltY - 0.01, inters[i].z),
                scale: Qt.vector3d(side / 100, side / 100, 1),
                eulerRotation: Qt.vector3d(-90, 0, 0)
            }))
        }
        asphaltComp.createObject(tile, { entries: asphalt })
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
