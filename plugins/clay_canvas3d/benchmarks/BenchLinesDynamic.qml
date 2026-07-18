// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Baseline benchmark: MultiLine3D with N lines re-set every frame (the moving /
// connector case) - exercises the full CPU coords rebuild path each frame.

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
    readonly property var steps: [100, 500, 1000, 5000, 10000]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real extent: 500
    readonly property real heightExtent: 300
    readonly property real minFps: 5

    // --- driver state ---
    property int stepIndex: -1
    property int currentN: 0
    property real lastBuildMs: 0
    property real phase: 0
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
        color: "#ff3366"
        width: 2.0
        coords: []
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
        outputPath: "file:///tmp/clay_bench/baseline-lines-dynamic-2026-07-18.csv"
        intervalMs: 250
        extra: ({
            "line_count": function() { return view3D.currentN },
            "build_ms": function() { return view3D.lastBuildMs.toFixed(2) }
        })
        running: false
    }

    // Start logging only once outputPath binding has resolved.
    Component.onCompleted: bench.running = true

    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    // Rebuild all N lines every call, reseeding to the fixed base layout and
    // applying an animated offset - forces a complete coords array rebuild.
    function rebuild() {
        if (currentN <= 0)
            return
        var t0 = Date.now()
        var rng = makeRng(view3D.seed)
        var ph = view3D.phase
        var out = new Array(currentN)
        for (var i = 0; i < currentN; i++) {
            var segs = 3 + Math.floor(rng() * 4)
            var bx = (rng() * 2 - 1) * view3D.extent
            var by = rng() * view3D.heightExtent
            var bz = (rng() * 2 - 1) * view3D.extent
            var wob = 30 * Math.sin(ph + i * 0.13)
            var pts = [Qt.vector3d(bx, by + wob, bz)]
            for (var s = 0; s < segs; s++) {
                bx += (rng() * 2 - 1) * 40
                by += (rng() * 2 - 1) * 30
                bz += (rng() * 2 - 1) * 40
                pts.push(Qt.vector3d(bx, by + wob, bz))
            }
            out[i] = pts
        }
        lines.coords = out
        view3D.lastBuildMs = Date.now() - t0
    }

    function startStep(i) {
        stepIndex = i
        currentN = steps[i]
        measureMarked = false
        bench.annotate("step_start", currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP lines-dynamic N=" + currentN)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        frameDriver.running = false
        console.log("BENCH DONE lines-dynamic")
    }

    function flagInfo() {
        return { scenario: "lines-dynamic", step: stepIndex, lineCount: currentN,
                 buildMs: lastBuildMs, fps: (renderStats ? renderStats.fps : -1),
                 done: benchDone }
    }

    // Per-frame rebuild - the whole point of this scenario.
    FrameAnimation {
        id: frameDriver
        running: true
        onTriggered: {
            view3D.phase += 0.05
            view3D.rebuild()
        }
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
            // Early-out if the current step is already unusable.
            if (view3D.measureMarked && view3D.renderStats
                    && view3D.renderStats.fps > 0
                    && view3D.renderStats.fps < view3D.minFps) {
                bench.annotate("early_stop", "fps<" + view3D.minFps + "@N=" + view3D.currentN)
                console.log("BENCH EARLY-STOP lines-dynamic at N=" + view3D.currentN
                            + " fps=" + view3D.renderStats.fps)
                view3D.finish()
                return
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
