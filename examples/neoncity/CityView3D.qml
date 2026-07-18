// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Synthwave city viewport: a dusk gradient backdrop behind a transparent
// View3D, toon-lit streamed tiles, depth fog to melt distant tiles into the
// horizon, a fly camera and an overview toggle, plus the perf/info HUD.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import "lanegen.js" as LaneGen

Item {
    id: root
    anchors.fill: parent
    focus: true

    // ---- settable from the Sandbox ----
    property int globalSeed: 42
    property real tileSize: 200
    property int streamRadius: 2
    property bool perfHud: false

    // ---- overlay toggles ----
    property bool showLanes: true
    property bool showCars: true
    property bool showConnections: true

    // ---- traffic ----
    // Target total car count; split across the (2r+1)^2 streamed tiles.
    property int carCount: 200
    readonly property int _tilesWide: 2 * streamRadius + 1
    readonly property int carsPerTile: Math.max(0, Math.round(carCount / (_tilesWide * _tilesWide)))

    // ---- live readouts (mirrored from the streaming manager) ----
    readonly property int currentTileX: tileManager.currentTileX
    readonly property int currentTileZ: tileManager.currentTileZ
    readonly property int loadedCount: tileManager.loadedCount
    readonly property int buildingCount: tileManager.buildingCount
    readonly property int laneLineCount: tileManager.laneLineCount
    readonly property int lanePointCount: tileManager.lanePointCount

    // Render metrics (bound for trace-based benchmarking).
    readonly property real perfFps: view.renderStats.fps
    readonly property real perfFrameMs: view.renderStats.frameTime
    readonly property int perfDraws: view.renderStats.drawCallCount
    readonly property int perfVerts: view.renderStats.drawVertexCount

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    property bool overview: false
    property bool benchmark: false

    Component.onCompleted: forceActiveFocus()

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_P) { root.perfHud = !root.perfHud; e.accepted = true }
        else if (e.key === Qt.Key_O) { root.toggleOverview(); e.accepted = true }
        else if (e.key === Qt.Key_L) { root.showLanes = !root.showLanes; e.accepted = true }
        else if (e.key === Qt.Key_C) { root.showConnections = !root.showConnections; e.accepted = true }
        else if (e.key === Qt.Key_K) { root.showCars = !root.showCars; e.accepted = true }
        else if (e.key === Qt.Key_E) { root.exportLanes(); e.accepted = true }
    }

    // Places the fly camera at street level over a given tile (demo/verification aid).
    function jumpTo(tx, tz) {
        overview = false
        camera.position = Qt.vector3d(tx * tileSize + tileSize * 0.5,
                                      tileSize * 0.42,
                                      tz * tileSize + tileSize * 1.35)
        camera.eulerRotation = Qt.vector3d(-16, 0, 0)
    }

    // ---- lane-data export (contract for the deck.gl twin) ----
    property string lastExportInfo: ""

    BenchCsvWriter { id: laneWriter }

    function _round2(v) { return Math.round(v * 100) / 100 }

    // Exports every loaded tile's LOGICAL lane model (one polyline per lane
    // line, dash carried via styleId) to /tmp/neoncity-lane-export.json in the
    // frozen deck.gl-twin format. Streamed line-by-line so no giant string is
    // ever built.
    function exportLanes() {
        var tiles = tileManager.loadedTiles()
        var tileCoords = []
        var minX = 1e30, minZ = 1e30, maxX = -1e30, maxZ = -1e30
        var total = 0
        for (var i = 0; i < tiles.length; ++i) {
            var t = tiles[i]
            if (!t.laneModel) continue
            tileCoords.push([t.tileX, t.tileZ])
            var b = t.cityData.bounds
            if (b.xmin < minX) minX = b.xmin
            if (b.zmin < minZ) minZ = b.zmin
            if (b.xmax > maxX) maxX = b.xmax
            if (b.zmax > maxZ) maxZ = b.zmax
            total += t.laneModel.lineCount
        }
        if (tileCoords.length === 0) { lastExportInfo = "export: no tiles loaded"; return }

        var meta = {
            generator: "neoncity",
            globalSeed: root.globalSeed,
            tileSize: root.tileSize,
            tiles: tileCoords,
            center: [_round2((minX + maxX) / 2), _round2((minZ + maxZ) / 2)],
            extent: [_round2(minX), _round2(minZ), _round2(maxX), _round2(maxZ)],
            lineCount: total,
            widthUnits: "pixels"
        }

        var path = "/tmp/neoncity-lane-export.json"
        if (!laneWriter.open(path)) { lastExportInfo = "export: open failed"; return }
        laneWriter.writeLine("{")
        laneWriter.writeLine("\"meta\": " + JSON.stringify(meta) + ",")
        laneWriter.writeLine("\"styles\": " + JSON.stringify(LaneGen.styles()) + ",")
        laneWriter.writeLine("\"lines\": [")

        var first = true
        for (i = 0; i < tiles.length; ++i) {
            var lm = tiles[i].laneModel
            if (!lm) continue
            var lines = lm.lines
            for (var j = 0; j < lines.length; ++j) {
                var l = lines[j]
                var pts = []
                for (var k = 0; k < l.p.length; ++k)
                    pts.push([_round2(l.p[k][0]), _round2(l.p[k][1]), _round2(l.p[k][2])])
                var obj = { p: pts, c: l.c, w: l.w, s: l.s }
                var s = JSON.stringify(obj)
                laneWriter.writeLine(first ? s : ("," + s))
                first = false
            }
        }
        laneWriter.writeLine("]")
        laneWriter.writeLine("}")
        laneWriter.close()

        lastExportInfo = "export: " + total + " lines -> " + path
        console.log("neoncity:", lastExportInfo)
    }

    // Tight, pitched-down look at the central intersection of a tile - shows
    // the turn fans clearly (verification aid).
    function inspectIntersection(tx, tz) {
        overview = false
        camera.position = Qt.vector3d(tx * tileSize + tileSize * 0.5,
                                      tileSize * 0.85,
                                      tz * tileSize + tileSize * 0.95)
        camera.eulerRotation = Qt.vector3d(-52, 0, 0)
    }

    function toggleOverview() {
        overview = !overview
        if (overview) {
            camera.position = Qt.vector3d(tileManager.currentTileX * tileSize + tileSize * 0.5,
                                          tileSize * 6.5,
                                          tileManager.currentTileZ * tileSize + tileSize * 3.0)
            camera.eulerRotation = Qt.vector3d(-62, 0, 0)
        } else {
            camera.position = Qt.vector3d(tileManager.currentTileX * tileSize + tileSize * 0.5,
                                          tileSize * 0.42,
                                          tileManager.currentTileZ * tileSize + tileSize * 1.35)
            camera.eulerRotation = Qt.vector3d(-16, 0, 0)
        }
    }

    // ---- dusk gradient backdrop (behind the transparent View3D) ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#140a24" }
            GradientStop { position: 0.52; color: "#3d1a54" }
            GradientStop { position: 0.70; color: "#c02a6e" }
            GradientStop { position: 0.80; color: "#43122f" }
            GradientStop { position: 1.0; color: "#0a0a16" }
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: (m) => { root.forceActiveFocus(); m.accepted = false }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: camera

        environment: SceneEnvironment {
            backgroundMode: SceneEnvironment.Transparent
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            fog: Fog {
                enabled: true
                color: "#5a1e5c"
                density: 0.9
                depthEnabled: true
                depthNear: root.tileSize * 2.0
                depthFar: root.tileSize * 7.5
            }
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(root.tileSize * 0.5, root.tileSize * 0.42, root.tileSize * 1.35)
            eulerRotation.x: -16
            clipFar: 24000
            fieldOfView: 65
        }

        WasdController {
            controlledObject: camera
            mouseEnabled: true
            keysEnabled: true
            forwardSpeed: 3.0
            backSpeed: 3.0
            leftSpeed: 3.0
            rightSpeed: 3.0
        }

        // Toon key light (matches the Canvas3D demos).
        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -60
            color: Qt.rgba(1.0, 0.92, 0.98, 1.0)
            brightness: 0.85
            ambientColor: Qt.rgba(0.22, 0.20, 0.32, 1.0)
            castsShadow: true
            shadowFactor: 78
            shadowMapQuality: Light.ShadowMapQualityHigh
            csmNumSplits: 2
            pcfFactor: 2
            shadowBias: 12
        }

        // Cool fill from the pink horizon side.
        DirectionalLight {
            eulerRotation.x: -12
            eulerRotation.y: 130
            color: "#ff3366"
            brightness: 0.18
            castsShadow: false
        }

        // Continuous camera yaw used only for perf measurement: forces the
        // View3D to render every frame so renderStats reflect real cost.
        NumberAnimation {
            target: camera
            property: "eulerRotation.y"
            from: 0; to: 360
            duration: 9000
            loops: Animation.Infinite
            running: root.benchmark
        }

        // Shared batch: every car->transmitter link is one instance here, so
        // all connections across all tiles cost a single draw call.
        ConnectorLayer3D {
            id: connectorLayer
            color: "#00d9ff"
            width: 1.4
            widthUnits: LineBatch3D.Pixel
            viewportSize: Qt.vector2d(view.width, view.height)
            depthBias: 4
            visible: root.showCars && root.showConnections
        }

        TileManager {
            id: tileManager
            camera: camera
            tileSize: root.tileSize
            globalSeed: root.globalSeed
            streamRadius: root.streamRadius
            showLanes: root.showLanes
            showCars: root.showCars
            showConnections: root.showConnections
            carsPerTile: root.carsPerTile
            connectorLayer: connectorLayer
            viewportSize: Qt.vector2d(view.width, view.height)
        }
    }

    // ---- perf overlay ----
    PerfHud {
        view3D: view
        extended: false
        visible: root.perfHud
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

    // ---- info HUD ----
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: infoCol.implicitWidth + 24
        height: infoCol.implicitHeight + 18
        radius: 8
        color: Qt.rgba(0.05, 0.06, 0.10, 0.82)
        border.color: "#0f9d9a"
        border.width: 1

        Column {
            id: infoCol
            x: 12
            y: 9
            spacing: 3

            Text {
                text: "NEON CITY"
                color: "#00d9ff"
                font.family: root.monoFont
                font.pixelSize: 14
                font.bold: true
            }
            Text {
                text: "seed " + root.globalSeed + "   tile " +
                      tileManager.currentTileX + "," + tileManager.currentTileZ
                color: "#eaeaea"
                font.family: root.monoFont
                font.pixelSize: 12
            }
            Text {
                text: "tiles " + tileManager.loadedCount +
                      "   buildings " + tileManager.buildingCount
                color: "#ffd93d"
                font.family: root.monoFont
                font.pixelSize: 12
            }
            Text {
                text: "lanes " + (root.showLanes ? "on" : "off") +
                      "   lines " + tileManager.laneLineCount +
                      "   pts " + tileManager.lanePointCount
                color: "#00d9ff"
                font.family: root.monoFont
                font.pixelSize: 12
            }
            Text {
                text: "cars " + (root.showCars ? "on" : "off") +
                      " (" + root.carCount + ")   links " +
                      (root.showConnections ? "on" : "off") +
                      "   tx " + tileManager.transmitters.length
                color: "#ff3366"
                font.family: root.monoFont
                font.pixelSize: 12
            }

            // ---- clickable toggles + export ----
            Row {
                spacing: 6
                Repeater {
                    model: [
                        { label: "Lanes (L)", on: root.showLanes },
                        { label: "Cars (K)", on: root.showCars },
                        { label: "Links (C)", on: root.showConnections },
                        { label: "Export (E)", on: false }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: btnTxt.implicitWidth + 14
                        height: btnTxt.implicitHeight + 8
                        radius: 5
                        color: modelData.on ? "#0f9d9a" : Qt.rgba(0.12, 0.13, 0.18, 0.9)
                        border.color: "#0f9d9a"
                        border.width: 1
                        Text {
                            id: btnTxt
                            anchors.centerIn: parent
                            text: modelData.label
                            color: modelData.on ? "#04121a" : "#c8c8d4"
                            font.family: root.monoFont
                            font.pixelSize: 11
                            font.bold: modelData.on
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (index === 0) root.showLanes = !root.showLanes
                                else if (index === 1) root.showCars = !root.showCars
                                else if (index === 2) root.showConnections = !root.showConnections
                                else root.exportLanes()
                                root.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ---- car-count slider (0 / 100 / 200 / 500 / 1000 / 2000) ----
            Row {
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "cars"
                    color: "#8a8a9a"
                    font.family: root.monoFont
                    font.pixelSize: 11
                }
                Slider {
                    id: carSlider
                    width: 150
                    from: 0
                    to: 5
                    stepSize: 1
                    snapMode: Slider.SnapAlways
                    readonly property var stops: [0, 100, 200, 500, 1000, 2000]
                    value: 2   // default -> 200
                    onMoved: { root.carCount = stops[value]; root.forceActiveFocus() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: carSlider.stops[carSlider.value]
                    color: "#ffd93d"
                    font.family: root.monoFont
                    font.pixelSize: 11
                }
            }

            Text {
                text: root.lastExportInfo !== "" ? root.lastExportInfo
                      : "WASD+drag fly   O overview   P perf"
                color: "#8a8a9a"
                font.family: root.monoFont
                font.pixelSize: 11
            }
        }
    }
}
