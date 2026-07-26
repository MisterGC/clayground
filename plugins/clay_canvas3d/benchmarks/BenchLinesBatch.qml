// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Overdraw benchmark: LineBatch3D fed through the styled bulk path (setBulk with
// per-line styleIds, mixed solid/dashed), N static styled polylines in one
// instanced draw call. Node yaw forces continuous re-rendering of the SAME
// batch so fps/frame_ms reflect the steady-state GPU cost (fragment overdraw),
// not a per-frame rebuild. Stepped scenario, auto-runs, logs via BenchLogger,
// prints "BENCH DONE lines-batch" when finished.
//
// The measurement currency here is fps / frame_ms at high N: the Dojo path is
// vsync-capped and reports gpu_ms/draw_calls as 0, so the overdraw win only
// surfaces once the GPU drops below vsync (the 100k/200k steps with fat lines).
//
// Runs in several configs across builds (see benchmarks/results/overdraw-*.csv):
//   baseline    - pre-change shaders (both caps on every segment)
//   steps12     - cap flags + tighter quads
//   opaque-off  - step 3 build, blended path (opaque=false)
//   opaque-on   - step 3 build, early-z path (opaque=true)
// benchOpaque distinguishes the two opaque runs; flip it for the opaque-on run.
// benchConfig selects the style-cost scenario: "mixed" (default, solid/dashed),
// "pattern-mix" (adds dot + chevron procedural patterns) and "flow-on" (animated
// flowing glow chevrons, flowTime advanced every frame).

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 720

    // --- fixed scenario parameters (keep identical across all configs) ---
    readonly property int seed: 1337
    readonly property var steps: [10000, 50000, 100000, 200000]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real extent: 500
    readonly property real heightExtent: 300

    // Flip to true for the opaque-on config run. Assigned to the batch only when
    // true, so the benchmark still loads against builds without the property.
    property bool benchOpaque: false

    // Style-cost config, selectable like benchOpaque:
    //   "mixed"       - solid/dashed mix (default, byte-comparable with earlier runs)
    //   "pattern-mix" - solid/dashed/dot/chevron mix (procedural pattern SDF cost)
    //   "flow-on"     - static + flowing glow chevrons, flowTime advanced every
    //                   frame (per-frame flow uniform + animated pattern phase)
    property string benchConfig: "mixed"

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

    // Fixed camera.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 600, 1200)
        eulerRotation.x: -22
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
    }

    LineBatch3D {
        id: batch
        widthUnits: LineBatch3D.Pixel
        viewportSize: Qt.vector2d(view3D.width, view3D.height)
        styles: [
            { dash: [0, 0], capRound: true, opacity: 1.0 },                 // 0: solid
            { dash: [10, 6], capRound: true, opacity: 1.0 },                 // 1: dashed
            { dash: [6, 12], pattern: "dot" },                               // 2: dots
            { dash: [12, 20], pattern: "chevron" },                          // 3: chevrons
            { dash: [12, 20], pattern: "chevron", flow: 60, glow: 0.4 }      // 4: flowing chevrons
        ]

        // flow-on config advances flowTime every frame so flowing styles animate;
        // off for every other config so the batch is never needlessly self-ticking.
        flowAutoPlay: view3D.benchConfig === "flow-on"

        // Static batch within a step, so the View3D would render once and idle.
        // A slow deterministic yaw forces continuous re-rendering of the SAME
        // instanced geometry (transform only, no rebuild), yielding a real
        // steady-state fps/frame_ms for drawing N styled lines.
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
        outputPath: "file:///tmp/clay_bench/overdraw-run.csv"
        intervalMs: 250
        extra: ({
            "line_count": function() { return view3D.currentN },
            "opaque": function() { return view3D.benchOpaque ? 1 : 0 },
            "config": function() { return view3D.benchConfig },
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

    // Build N styled polylines of 3-6 segments (4-7 points) into packed binary
    // buffers and feed them through the styled bulk path. Mixed solid/dashed via
    // per-line styleId; fat pixel widths to make fragment overdraw visible.
    function buildBatch(n) {
        var t0 = Date.now()
        var rng = makeRng(view3D.seed)

        var starts = new Uint32Array(n + 1)
        var colors = new Uint8Array(n * 4)
        var widths = new Float32Array(n)
        var styleIds = new Uint16Array(n)
        var posArr = []
        var ptCount = 0

        for (var i = 0; i < n; i++) {
            starts[i] = ptCount
            var segs = 3 + Math.floor(rng() * 4)   // 3..6 segments
            var px = (rng() * 2 - 1) * view3D.extent
            var py = rng() * view3D.heightExtent
            var pz = (rng() * 2 - 1) * view3D.extent
            posArr.push(px, py, pz); ptCount++
            for (var s = 0; s < segs; s++) {
                px += (rng() * 2 - 1) * 40
                py += (rng() * 2 - 1) * 30
                pz += (rng() * 2 - 1) * 40
                posArr.push(px, py, pz); ptCount++
            }
            colors[i * 4 + 0] = Math.floor(rng() * 255)
            colors[i * 4 + 1] = Math.floor(rng() * 255)
            colors[i * 4 + 2] = Math.floor(rng() * 255)
            colors[i * 4 + 3] = 255
            // Fat pixel widths on purpose: fragment overdraw is a GPU cost that
            // only surfaces (fps drops below vsync) when the batch is fragment-
            // bound rather than vsync/CPU-bound. Kept identical across configs.
            widths[i] = 40.0 + rng() * 80.0        // 40..120 px
            // One rng() draw per line regardless of config, so the "mixed" run
            // stays byte-comparable with earlier CSVs.
            var r = rng()
            if (view3D.benchConfig === "pattern-mix")
                styleIds[i] = Math.floor(r * 4)    // solid/dashed/dot/chevron
            else if (view3D.benchConfig === "flow-on")
                styleIds[i] = (r < 0.5) ? 4 : 3    // flowing + static chevrons
            else
                styleIds[i] = (r < 0.5) ? 0 : 1    // mixed solid/dashed
        }
        starts[n] = ptCount

        var positions = Float32Array.from(posArr)
        batch.setBulk(positions.buffer, starts.buffer, colors.buffer,
                      widths.buffer, styleIds.buffer)

        // Only assign when true, so this benchmark loads against builds that do
        // not yet have the opaque property (baseline / steps12 configs).
        if (view3D.benchOpaque)
            batch.opaque = true

        view3D.lastBuildMs = Date.now() - t0
    }

    function startStep(i) {
        stepIndex = i
        currentN = steps[i]
        measureMarked = false
        buildBatch(currentN)
        bench.annotate("step_start", currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP lines-batch N=" + currentN + " build_ms=" + lastBuildMs
                    + " opaque=" + benchOpaque + " config=" + benchConfig)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        console.log("BENCH DONE lines-batch")
    }

    function flagInfo() {
        return { scenario: "lines-batch", step: stepIndex, lineCount: currentN,
                 opaque: benchOpaque, config: benchConfig, buildMs: lastBuildMs,
                 done: benchDone }
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
