// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Baseline benchmark: edit-storm on a large voxel map. A 128x64x128 terrain is
// pre-filled, then one set()+commit is issued per frame at random positions for
// ~8s - first on StaticVoxelMap (full greedy remesh on every edit), then on
// DynamicVoxelMap of the same size (full instance-table rebuild + O(n) recount).

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 720

    // --- fixed scenario parameters (keep identical for the optimized re-run) ---
    readonly property int seed: 1337
    readonly property int vcx: 128
    readonly property int vcy: 64
    readonly property int vcz: 128
    readonly property real warmupMs: 2000
    readonly property real phaseDurationMs: 8000
    readonly property var editColors: ["#ff3366", "#00d9ff", "#ffd93d", "#0f9d9a"]

    // --- driver state ---
    property string backend: "static"   // "static" -> "dynamic" -> "done"
    property bool phaseArmed: false
    property bool measureMarked: false
    property real phaseStartMs: 0
    property int solidCount: 0
    property real lastEditMs: 0
    property bool benchDone: false
    property var editRng: null

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - MUST stay identical for the optimized comparison run.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 500, 800)
        eulerRotation.x: -30
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
        castsShadow: false
    }

    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    // Deterministic terrain-ish heightmap pre-fill. Uses the BATCH fill path
    // (model.fillBox writes voxels directly, no per-voxel remesh) with a single
    // model.commit() at the end - exactly one full-volume build. This matters:
    // map.set() calls notifyDataChanged() per voxel, so pre-filling with set()
    // would trigger one full greedy remesh PER VOXEL and hang the loader.
    function genTerrain(map) {
        var t0 = Date.now()
        var count = 0
        for (var x = 0; x < view3D.vcx; x++) {
            for (var z = 0; z < view3D.vcz; z++) {
                var h = 2 + Math.floor(3 * (Math.sin(x * 0.08) * Math.cos(z * 0.08) + 1))
                var ci = (x + z) % view3D.editColors.length
                map.model.fillBox(x, 0, z, 1, h, 1,
                                  [{ "color": view3D.editColors[ci], "weight": 1.0 }], 0)
                count += h
            }
        }
        var t1 = Date.now()
        console.log("BENCH fill-done backend=" + view3D.backend + " solid=" + count
                    + " fill_ms=" + (t1 - t0) + " (committing one full build...)")
        map.model.commit()
        var t2 = Date.now()
        view3D.solidCount = count
        view3D.editRng = makeRng(view3D.seed ^ 0x9e3779b9)
        // commit_ms == cost of ONE full-volume build == the per-edit remesh cost
        // that the storm below pays on every single voxel change (static path).
        console.log("BENCH terrain backend=" + view3D.backend + " solid=" + count
                    + " fill_ms=" + (t1 - t0) + " commit_ms=" + (t2 - t1))
    }

    Loader3D {
        id: mapLoader
        asynchronous: false
        sourceComponent: view3D.backend === "static" ? staticComp
                       : view3D.backend === "dynamic" ? dynamicComp
                       : null
    }

    Component {
        id: staticComp
        Node {
            property var vmap: sm
            property bool ready: false
            StaticVoxelMap {
                id: sm
                voxelCountX: view3D.vcx
                voxelCountY: view3D.vcy
                voxelCountZ: view3D.vcz
                voxelSize: 4
                showEdges: false
                useToonShading: false
                Component.onCompleted: {
                    view3D.genTerrain(sm)
                    parent.ready = true
                }
            }
        }
    }

    Component {
        id: dynamicComp
        Node {
            property var vmap: dm
            property bool ready: false
            DynamicVoxelMap {
                id: dm
                voxelCountX: view3D.vcx
                voxelCountY: view3D.vcy
                voxelCountZ: view3D.vcz
                voxelSize: 4
                showEdges: false
                useToonShading: false
                Component.onCompleted: {
                    view3D.genTerrain(dm)
                    parent.ready = true
                }
            }
        }
    }

    PerfHud {
        view3D: view3D
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 12
    }

    BenchLogger {
        id: bench
        view3D: view3D
        // Written out-of-tree (see BenchLinesStatic); copy to results/ after run.
        outputPath: "file:///tmp/clay_bench/baseline-voxel-edit-2026-07-18.csv"
        intervalMs: 250
        extra: ({
            "backend": function() { return view3D.backend },
            "voxel_count": function() { return view3D.solidCount },
            "edit_ms": function() { return view3D.lastEditMs.toFixed(2) }
        })
        running: false
    }

    // Start logging only once outputPath binding has resolved.
    Component.onCompleted: bench.running = true

    // One random voxel edit per frame + commit == the edit-storm.
    FrameAnimation {
        id: frameDriver
        running: true
        onTriggered: {
            if (view3D.benchDone)
                return
            var item = mapLoader.item
            if (!item || !item.ready || !view3D.editRng)
                return
            var r = view3D.editRng
            var x = Math.floor(r() * view3D.vcx)
            var y = Math.floor(r() * view3D.vcy)
            var z = Math.floor(r() * view3D.vcz)
            var wasEmpty = (item.vmap.get(x, y, z).a === 0)
            // set() alone triggers the rebuild: a full greedy remesh (static,
            // synchronous) or a full instance-table rebuild + O(n) recount
            // (dynamic, on next render). No extra commit() - that would double it.
            var te0 = Date.now()
            item.vmap.set(x, y, z, view3D.editColors[Math.floor(r() * view3D.editColors.length)])
            view3D.lastEditMs = Date.now() - te0
            if (wasEmpty)
                view3D.solidCount++
        }
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        frameDriver.running = false
        console.log("BENCH DONE voxel-edit")
    }

    function flagInfo() {
        return { scenario: "voxel-edit", backend: backend, solidCount: solidCount,
                 fps: (renderStats ? renderStats.fps : -1), done: benchDone }
    }

    Timer {
        id: driveTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            var item = mapLoader.item
            if (!item || !item.ready)
                return
            if (!view3D.phaseArmed) {
                view3D.phaseArmed = true
                view3D.measureMarked = false
                view3D.phaseStartMs = Date.now()
                bench.annotate("backend_start", view3D.backend)
                console.log("BENCH PHASE voxel-edit backend=" + view3D.backend)
                return
            }
            var el = Date.now() - view3D.phaseStartMs
            if (!view3D.measureMarked && el >= view3D.warmupMs) {
                bench.annotate("measure_start", view3D.backend)
                view3D.measureMarked = true
            }
            if (el >= view3D.phaseDurationMs) {
                if (view3D.backend === "static") {
                    view3D.backend = "dynamic"
                    view3D.phaseArmed = false
                } else {
                    view3D.finish()
                }
            }
        }
    }
}
