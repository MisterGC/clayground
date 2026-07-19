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
import "lidar.js" as Lidar

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
    // Global traffic-speed multiplier (default calm cruise), tunable from the HUD.
    property real carSpeedFactor: 0.4

    // ---- lidar inspection ----
    property bool lidarOn: false
    property string lidarQuality: "med"      // low / med / high
    property var selection: null             // { carSystem, index } or null
    // profiling readouts (see stepLidar / benchLidar)
    property real lidarStepMs: 0
    property int lidarPoints: 0
    property int lidarRaysFrame: 0

    // scan state (plain vars, not reactive)
    property var _scanner: null
    property var _scene: null
    property var _staticBoxes: null
    property var _cfg: null
    property bool _rebuildStatic: false
    property int _msFrames: 0
    property double _msStart: 0

    onCarCountChanged: deselect()

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
        else if (e.key === Qt.Key_I) { root.toggleLidar(); e.accepted = true }
    }

    // ---- lidar inspection controller -----------------------------------------
    // Click selects the nearest car to the ground hit; a spinning scanner then
    // sweeps the neighbourhood each frame and the PiP shows the car-local cloud.

    function toggleLidar() {
        lidarOn = !lidarOn
        if (lidarOn && selection) _initScanner()
        forceActiveFocus()
    }

    function cycleQuality() {
        lidarQuality = lidarQuality === "low" ? "med"
                     : lidarQuality === "med" ? "high" : "low"
        forceActiveFocus()
    }
    onLidarQualityChanged: if (selection) _initScanner()

    // Click -> ground pick -> nearest car within radius (else deselect).
    function selectAt(px, py) {
        forceActiveFocus()
        var res = view.pick(px, py)
        if (!res || !res.objectHit) { deselect(); return }
        var p = res.scenePosition
        var sel = tileManager.pickNearestCar(p.x, p.z, 24.0)
        if (sel) setSelection(sel); else deselect()
    }

    function setSelection(sel) {
        selection = sel
        lidarPanel.carLabel = sel.index
        var pose = sel.carSystem.carPose(sel.index)
        if (pose) { lidarPanel.carW = pose.w; lidarPanel.carL = pose.l; lidarPanel.carH = pose.h }
        if (!lidarOn) lidarOn = true          // auto-open on selection
        _initScanner()
    }

    function deselect() {
        selection = null
        marker.visible = false
        _scanner = null; _scene = null
        if (typeof lidarPanel !== "undefined") lidarPanel.clearCloud()
    }

    function _initScanner() {
        if (!selection) return
        var cfg = Lidar.quality(lidarQuality)
        _cfg = cfg
        _scanner = Lidar.createScanner(cfg)
        var ib = Lidar.initBuffers(_scanner)
        lidarPanel.initCloud(ib.positions, ib.starts, ib.colors, ib.widths)
        _rebuildStatic = true
    }

    // One scan slice per frame: advance the sweep, repack the cloud, upload it.
    function stepLidar() {
        var sel = selection
        if (!sel || !_scanner) return
        var cs = sel.carSystem
        var pose = null
        try { pose = cs.carPose(sel.index) } catch (e) { pose = null }
        if (!pose) { deselect(); return }

        var ox = pose.x, oz = pose.z, yaw = pose.yaw
        var oy = pose.y + pose.h * 0.5        // scanner ~ car roof height

        marker.position = Qt.vector3d(ox, oy + 6.0, oz)
        marker.visible = true

        if (_rebuildStatic || !_scene) {
            var datas = tileManager.nearbyCityData(ox, oz, _cfg.range)
            _staticBoxes = []
            for (var i = 0; i < datas.length; ++i) Lidar.tileBoxes(datas[i], _staticBoxes)
            _scene = Lidar.buildStatic(_staticBoxes, ox, oz, _cfg.range)
            _rebuildStatic = false
        }
        var carBoxes = tileManager.carBoxesNear(ox, oz, _cfg.range, cs, sel.index)

        var revs = Lidar.advance(_scanner, _scene, carBoxes, ox, oy, oz, yaw, _cfg.azPerFrame)
        lidarPanel.patchCloud(_scanner.posBuf.buffer)

        // Once per revolution the car has moved: refresh the static candidate set.
        if (revs > 0) _rebuildStatic = true

        lidarPoints = _scanner.visible
        lidarRaysFrame = _scanner.raysThisAdvance
        _measureStep()
        lidarPanel.statsText = "pts " + count + "   rays/f " + lidarRaysFrame +
                               "   " + lidarStepMs.toFixed(2) + " ms   q:" + lidarQuality
    }

    // Averages the full step cost over 30 frames (Date.now resolution is coarse
    // for a single sub-ms slice; benchLidar() gives a precise breakdown).
    function _measureStep() {
        if (_msFrames === 0) _msStart = Date.now()
        _msFrames++
        if (_msFrames >= 30) {
            lidarStepMs = (Date.now() - _msStart) / 30
            _msFrames = 0
        }
    }

    // On-demand precise profiling: runs `iters` scan slices back to back and
    // logs total/per-slice ms plus a fill-only figure. Call from the inspector.
    function benchLidar(iters) {
        if (!selection || !_scanner) { console.log("neoncity/lidar: select a car first"); return }
        var sel = selection, cs = sel.carSystem
        var pose = cs.carPose(sel.index)
        var ox = pose.x, oz = pose.z, yaw = pose.yaw, oy = pose.y + pose.h * 0.5
        var datas = tileManager.nearbyCityData(ox, oz, _cfg.range)
        var boxes = []
        for (var i = 0; i < datas.length; ++i) Lidar.tileBoxes(datas[i], boxes)
        var scene = Lidar.buildStatic(boxes, ox, oz, _cfg.range)
        var carBoxes = tileManager.carBoxesNear(ox, oz, _cfg.range, cs, sel.index)
        var n = iters || 300

        var t0 = Date.now()
        var rays = 0
        for (i = 0; i < n; ++i) {
            Lidar.advance(_scanner, scene, carBoxes, ox, oy, oz, yaw, _cfg.azPerFrame)
            rays += _scanner.raysThisAdvance
        }
        var tAdv = Date.now() - t0

        // patch cost: rewrite the whole fixed instance table via the no-rebuild
        // fast path (what runs every real frame after advance()).
        var t1 = Date.now()
        for (i = 0; i < n; ++i) lidarPanel.patchCloud(_scanner.posBuf.buffer)
        var tPatch = Date.now() - t1

        var revRays = _cfg.channels * _cfg.azSteps
        console.log("neoncity/lidar bench q=" + lidarQuality +
                    " boxes=" + scene.boxes.length + " cars=" + carBoxes.length +
                    " | advance " + (tAdv / n).toFixed(3) + " ms/slice (" + (rays / n).toFixed(0) + " rays)" +
                    " | patch " + (tPatch / n).toFixed(3) + " ms/slice" +
                    " | pts/rev " + revRays + " visible " + _scanner.visible)
        return { advMsPerSlice: tAdv / n, patchMsPerSlice: tPatch / n, raysPerSlice: rays / n,
                 pointsPerRev: revRays, visible: _scanner.visible }
    }

    // Determinism proof: two fresh scanners fed the identical pose + obstacle
    // set over the identical number of slices must produce byte-identical clouds
    // (lidar.js is pure - no Math.random, no time). Returns {match, slots, diffs}.
    function lidarDeterminismCheck(slices) {
        if (!selection) return { match: false, note: "no selection" }
        var cs = selection.carSystem, pose = cs.carPose(selection.index)
        var ox = pose.x, oz = pose.z, yaw = pose.yaw, oy = pose.y + pose.h * 0.5
        var datas = tileManager.nearbyCityData(ox, oz, _cfg.range)
        var boxes = []
        for (var i = 0; i < datas.length; ++i) Lidar.tileBoxes(datas[i], boxes)
        var scA = Lidar.buildStatic(boxes, ox, oz, _cfg.range)
        var scB = Lidar.buildStatic(boxes, ox, oz, _cfg.range)
        var carBoxes = tileManager.carBoxesNear(ox, oz, _cfg.range, cs, selection.index)
        var a = Lidar.createScanner(_cfg), b = Lidar.createScanner(_cfg)
        var n = slices || 200
        for (i = 0; i < n; ++i) {
            Lidar.advance(a, scA, carBoxes, ox, oy, oz, yaw, _cfg.azPerFrame)
            Lidar.advance(b, scB, carBoxes, ox, oy, oz, yaw, _cfg.azPerFrame)
        }
        var pa = a.posBuf, pb = b.posBuf, diffs = 0
        for (i = 0; i < pa.length; ++i) if (pa[i] !== pb[i]) diffs++
        var r = { match: diffs === 0, slots: a.channels * a.azSteps, visible: a.visible, diffs: diffs }
        console.log("neoncity/lidar determinism: " + JSON.stringify(r))
        return r
    }

    FrameAnimation {
        id: lidarClock
        running: root.lidarOn && root.selection !== null
        onTriggered: root.stepLidar()
    }

    // Places the fly camera at street level over a given tile (demo/verification aid).
    function jumpTo(tx, tz) {
        overview = false
        camera.position = Qt.vector3d(tx * tileSize + tileSize * 0.5,
                                      tileSize * 0.42,
                                      tz * tileSize + tileSize * 1.35)
        camera.eulerRotation = Qt.vector3d(-16, 0, 0)
    }

    // Aim the camera top-down at a car currently mid lane-change (diagnostic).
    function focusOvertake(height) {
        var tiles = tileManager.loadedTiles()
        for (var i = 0; i < tiles.length; ++i) {
            var cs = tiles[i].carSystem
            if (!cs) continue
            var p = cs.activeLaneChangePos()
            if (p) { topDown(p.x, p.z, height === undefined ? 26 : height); return p.x.toFixed(1) + "," + p.z.toFixed(1) }
        }
        return "none"
    }

    // Cumulative overtaking lane changes across all loaded tiles (diagnostic).
    function totalLaneChanges() {
        var tiles = tileManager.loadedTiles()
        var n = 0
        for (var i = 0; i < tiles.length; ++i)
            if (tiles[i].carSystem) n += tiles[i].carSystem.laneChanges
        return n
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
            total += t.laneModel.lineCount + (t.laneMarkings ? t.laneMarkings.lineCount : 0)
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
        // Export both painted markings and the detailed lane model, in the same
        // frozen { p, c, w, s } line shape (styles table is shared).
        for (i = 0; i < tiles.length; ++i) {
            var models = [tiles[i].laneMarkings, tiles[i].laneModel]
            for (var mi = 0; mi < models.length; ++mi) {
                var lm = models[mi]
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
        }
        laneWriter.writeLine("]")
        laneWriter.writeLine("}")
        laneWriter.close()

        lastExportInfo = "export: " + total + " lines -> " + path
        console.log("neoncity:", lastExportInfo)
    }

    // Straight top-down look centred on world (cx,cz) at a given height - shows
    // block structure / lane paint plan-view (verification aid).
    function topDown(cx, cz, height) {
        overview = false
        camera.position = Qt.vector3d(cx, height, cz)
        camera.eulerRotation = Qt.vector3d(-90, 0, 0)
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

    // ---- bright daylight sky backdrop (behind the transparent View3D) ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#a9cdea" }
            GradientStop { position: 0.55; color: "#cfe0ee" }
            GradientStop { position: 0.82; color: "#e7eef4" }
            GradientStop { position: 1.0; color: "#eef2f5" }
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
                color: "#dce6ef"
                density: 0.55
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

        // Daylight sun: warm-white key with soft shadows and a bright ambient
        // fill so nothing is crushed to black (archviz daylight read).
        DirectionalLight {
            eulerRotation.x: -42
            eulerRotation.y: -55
            color: Qt.rgba(1.0, 0.97, 0.90, 1.0)
            brightness: 1.15
            ambientColor: Qt.rgba(0.52, 0.55, 0.60, 1.0)
            castsShadow: true
            shadowFactor: 55
            shadowMapQuality: Light.ShadowMapQualityHigh
            csmNumSplits: 2
            pcfFactor: 4
            shadowBias: 12
        }

        // Cool sky fill from the opposite side (soft blue bounce).
        DirectionalLight {
            eulerRotation.x: -18
            eulerRotation.y: 130
            color: "#9fc0e0"
            brightness: 0.35
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
            carSpeedFactor: root.carSpeedFactor
            connectorLayer: connectorLayer
            viewportSize: Qt.vector2d(view.width, view.height)
        }

        // ---- selected-car highlight: a gold beacon hovering over the car ----
        Model {
            id: marker
            visible: false
            source: "#Cone"
            eulerRotation.x: 180
            scale: Qt.vector3d(3.2 / 100, 5.0 / 100, 3.2 / 100)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffd93d"
            }
        }

        // Tap (click without drag) selects a car; drag still flies the camera
        // via the WasdController, since a TapHandler ignores drags.
        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.WithinBounds
            onTapped: (ep) => root.selectAt(ep.position.x, ep.position.y)
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

    // ---- lidar inspection PiP (bottom-right, ~35% width) ----
    LidarPanel {
        id: lidarPanel
        visible: root.lidarOn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: Math.round(parent.width * 0.35)
        height: Math.round(parent.height * 0.42)
        onCloseRequested: root.lidarOn = false
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

            // ---- car-speed factor (-/+) ----
            Row {
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "speed"
                    color: "#8a8a9a"
                    font.family: root.monoFont
                    font.pixelSize: 11
                }
                Repeater {
                    model: ["-", "+"]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 20; height: 18; radius: 4
                        color: Qt.rgba(0.12, 0.13, 0.18, 0.9)
                        border.color: "#0f9d9a"; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: "#c8c8d4"
                            font.family: root.monoFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var f = root.carSpeedFactor + (parent.index === 0 ? -0.1 : 0.1)
                                root.carSpeedFactor = Math.max(0.1, Math.min(2.0, Math.round(f * 10) / 10))
                                root.forceActiveFocus()
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.carSpeedFactor.toFixed(1) + "x"
                    color: "#ffd93d"
                    font.family: root.monoFont
                    font.pixelSize: 11
                }
            }

            // ---- lidar toggle + quality ----
            Row {
                spacing: 6
                Rectangle {
                    width: lidTxt.implicitWidth + 14
                    height: lidTxt.implicitHeight + 8
                    radius: 5
                    color: root.lidarOn ? "#0f9d9a" : Qt.rgba(0.12, 0.13, 0.18, 0.9)
                    border.color: "#0f9d9a"; border.width: 1
                    Text {
                        id: lidTxt
                        anchors.centerIn: parent
                        text: "Lidar (I)"
                        color: root.lidarOn ? "#04121a" : "#c8c8d4"
                        font.family: root.monoFont
                        font.pixelSize: 11
                        font.bold: root.lidarOn
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.toggleLidar() }
                }
                Rectangle {
                    width: qTxt.implicitWidth + 14
                    height: qTxt.implicitHeight + 8
                    radius: 5
                    color: Qt.rgba(0.12, 0.13, 0.18, 0.9)
                    border.color: "#00d9ff"; border.width: 1
                    Text {
                        id: qTxt
                        anchors.centerIn: parent
                        text: "q:" + root.lidarQuality
                        color: "#00d9ff"
                        font.family: root.monoFont
                        font.pixelSize: 11
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.cycleQuality() }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selection ? ("car #" + root.selection.index) : "click a car"
                    color: "#8a8a9a"
                    font.family: root.monoFont
                    font.pixelSize: 11
                }
            }

            Text {
                text: root.lastExportInfo !== "" ? root.lastExportInfo
                      : "WASD+drag fly   O overview   P perf   I lidar"
                color: "#8a8a9a"
                font.family: root.monoFont
                font.pixelSize: 11
            }
        }
    }
}
