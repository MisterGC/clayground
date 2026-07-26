// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Baseline benchmark: DynamicVoxelMap 30x15x30 fully cleared + refilled every
// 30 ms for ~10s - the animated "wave" pattern from VoxelDemo. Every cycle does
// a full instance-table rebuild + O(n) recount on commit.

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
    readonly property int vcx: 30
    readonly property int vcy: 15
    readonly property int vcz: 30
    readonly property int cycleMs: 30
    readonly property real warmupMs: 2000
    readonly property real durationMs: 10000

    // --- driver state ---
    property real time: 0
    property real startMs: 0
    property bool measureMarked: false
    property bool benchDone: false

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - MUST stay identical for the optimized comparison run.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 120, 220)
        eulerRotation.x: -28
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
    }

    DynamicVoxelMap {
        id: waveMap
        voxelCountX: view3D.vcx
        voxelCountY: view3D.vcy
        voxelCountZ: view3D.vcz
        voxelSize: 5
        showEdges: false
        useToonShading: false
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
        outputPath: "file:///tmp/clay_bench/baseline-voxel-churn-2026-07-18.csv"
        intervalMs: 250
        extra: ({
            "backend": function() { return "dynamic" }
        })
        running: false
    }

    // Deterministic diagonal wave - identical to the VoxelDemo pattern.
    function updateWave() {
        for (var x = 0; x < view3D.vcx; x++)
            for (var y = 0; y < view3D.vcy; y++)
                for (var z = 0; z < view3D.vcz; z++)
                    waveMap.set(x, y, z, "#00000000")

        for (var ax = 0; ax < view3D.vcx; ax++) {
            for (var az = 0; az < view3D.vcz; az++) {
                var waveHeight = Math.floor(7 + 3 * Math.sin((ax + az) * 0.3 + view3D.time))
                for (var ay = 0; ay < waveHeight && ay < view3D.vcy; ay++) {
                    var depthRatio = ay / waveHeight
                    var lightness = 0.4 + (1.0 - depthRatio) * 0.3
                    waveMap.set(ax, ay, az, Qt.hsla(0.55, 0.8, lightness, 1.0))
                }
            }
        }
        waveMap.model.commit()
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        waveTimer.running = false
        console.log("BENCH DONE voxel-churn")
    }

    function flagInfo() {
        return { scenario: "voxel-churn", time: time,
                 fps: (renderStats ? renderStats.fps : -1), done: benchDone }
    }

    Component.onCompleted: {
        bench.running = true
        startMs = Date.now()
        updateWave()
    }

    Timer {
        id: waveTimer
        interval: view3D.cycleMs
        repeat: true
        running: true
        onTriggered: {
            view3D.time += 0.08
            view3D.updateWave()
        }
    }

    Timer {
        id: driveTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            var el = Date.now() - view3D.startMs
            if (!view3D.measureMarked && el >= view3D.warmupMs) {
                bench.annotate("measure_start", "dynamic")
                view3D.measureMarked = true
            }
            if (el >= view3D.durationMs + view3D.warmupMs)
                view3D.finish()
        }
    }
}
