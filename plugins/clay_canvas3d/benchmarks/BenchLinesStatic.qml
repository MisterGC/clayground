// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Baseline benchmark: MultiLine3D with N static random polylines in one batch.
// Stepped scenario, auto-runs, logs via BenchLogger, prints "BENCH DONE" when finished.

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
    readonly property var steps: [1000, 5000, 10000, 25000, 50000, 100000]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real extent: 500
    readonly property real heightExtent: 300

    // --- driver state ---
    property int stepIndex: -1
    property int currentN: 0
    property real lastBuildMs: 0
    property real stepStartMs: 0
    property bool measureMarked: false
    property bool benchDone: false

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - MUST stay identical for the optimized comparison run.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 600, 1200)
        eulerRotation.x: -22
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
    }

    MultiLine3D {
        id: lines
        color: "#00d9ff"
        width: 2.0
        coords: []

        // The batch is static within a step, so the View3D would render once and
        // idle (fps -> 0, frame_ms frozen). A slow deterministic rotation forces
        // continuous re-rendering of the SAME geometry, yielding a real
        // steady-state fps/frame_ms for drawing N lines. Transform only - it does
        // not rebuild the line geometry.
        NumberAnimation on eulerRotation.y {
            from: 0
            to: 360
            duration: 12000
            loops: Animation.Infinite
            running: true
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
        // Written out-of-tree: writing into the watched sandbox dir would make
        // the dojo file-watcher reload the scene. Copy to results/ after the run.
        outputPath: "file:///tmp/clay_bench/baseline-lines-static-2026-07-18.csv"
        intervalMs: 250
        extra: ({
            "line_count": function() { return view3D.currentN },
            "build_ms": function() { return view3D.lastBuildMs.toFixed(1) }
        })
        running: false
    }

    // Start logging only once outputPath binding has resolved.
    Component.onCompleted: bench.running = true

    // Deterministic LCG so re-runs are byte-comparable.
    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    // Build N polylines of 3-6 segments (4-7 points) as a batched coords array.
    function buildLines(n) {
        var t0 = Date.now()
        var rng = makeRng(view3D.seed)
        var out = new Array(n)
        for (var i = 0; i < n; i++) {
            var segs = 3 + Math.floor(rng() * 4)   // 3..6 segments
            var px = (rng() * 2 - 1) * view3D.extent
            var py = rng() * view3D.heightExtent
            var pz = (rng() * 2 - 1) * view3D.extent
            var pts = [Qt.vector3d(px, py, pz)]
            for (var s = 0; s < segs; s++) {
                px += (rng() * 2 - 1) * 40
                py += (rng() * 2 - 1) * 30
                pz += (rng() * 2 - 1) * 40
                pts.push(Qt.vector3d(px, py, pz))
            }
            out[i] = pts
        }
        view3D.lastBuildMs = Date.now() - t0
        return out
    }

    function startStep(i) {
        stepIndex = i
        currentN = steps[i]
        measureMarked = false
        var data = buildLines(currentN)
        lines.coords = data
        bench.annotate("step_start", currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP lines-static N=" + currentN + " build_ms=" + lastBuildMs)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        console.log("BENCH DONE lines-static")
    }

    function flagInfo() {
        return { scenario: "lines-static", step: stepIndex,
                 lineCount: currentN, buildMs: lastBuildMs, done: benchDone }
    }

    Timer {
        id: driveTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (view3D.stepIndex < 0) {
                view3D.startStep(0)
                return
            }
            var el = Date.now() - view3D.stepStartMs
            if (!view3D.measureMarked && el >= view3D.warmupMs) {
                bench.annotate("measure_start", view3D.currentN)
                view3D.measureMarked = true
            }
            if (el >= view3D.stepDurationMs) {
                if (view3D.stepIndex + 1 < view3D.steps.length)
                    view3D.startStep(view3D.stepIndex + 1)
                else
                    view3D.finish()
            }
        }
    }
}
