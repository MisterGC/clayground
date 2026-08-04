// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Areas benchmark: Poly3D against the ribbon-strip fill it replaces.
//
// Before Poly3D existed, an area was faked by covering it with a fan of flat
// LineBatch3D ribbons plus a hand-tuned per-strip depth ramp to stop the
// coplanar strips z-fighting. #183 claims Poly3D is measurably cheaper. This
// runs both at the same area counts, over the same polygons, from the same
// camera, so the claim is a number rather than an assertion.
//
// Steps alternate strips/poly at each count so drift in machine state hits
// both modes rather than whichever ran last. Auto-runs, logs via BenchLogger,
// prints "BENCH DONE" when finished.
//
// RUN THIS IN THE DOJO, not clayrender. clayrender drives its own fixed frame
// cadence, so fps and frame_ms come out pinned around 52 ms for every mode and
// every count - the renderer's number, not the scene's. Only build_ms is
// meaningful there. The dojo's loop is vsync-driven and gives a real steady
// state, which is how the other benchmarks in this directory were measured:
//
//   ./build/bin/claydojo --sbx plugins/clay_canvas3d/benchmarks/BenchAreas.qml
//
// then copy /tmp/clay_bench/areas.csv into results/.

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 720

    // --- fixed scenario parameters (keep identical across compared runs) ---
    readonly property int seed: 1337
    readonly property var counts: [10, 25, 50, 100, 200]
    readonly property var modes: ["strips", "poly"]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real extent: 900
    readonly property int ringPoints: 12
    // Strips per area. 20 is what the out-of-tree lab's lake used; the fill
    // gets visibly banded below roughly a dozen.
    readonly property int stripsPerArea: 20

    // --- driver state ---
    property int stepIndex: -1
    property int currentN: 0
    property string currentMode: ""
    property real lastBuildMs: 0
    property real stepStartMs: 0
    property bool measureMarked: false
    property bool benchDone: false
    property int stripCount: 0

    // Every (mode, count) pair, count-major so the two modes sit next to each
    // other in the log and can be read off without sorting.
    readonly property var steps: {
        var out = []
        for (var c = 0; c < counts.length; ++c)
            for (var m = 0; m < modes.length; ++m)
                out.push({ mode: modes[m], n: counts[c] })
        return out
    }

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - MUST stay identical across compared runs. Looking down at
    // the ground plane, which is where an area primitive actually gets used.
    //
    // The rig turns slowly because the scene is otherwise static within a step:
    // a View3D with nothing moving renders once and idles, and fps/frame_ms
    // then measure the driver timer rather than the cost of drawing N areas.
    // Rotating the camera - not the geometry - forces a real steady state
    // without rebuilding anything, and costs both modes the same.
    Node {
        id: camRig
        NumberAnimation on eulerRotation.y {
            from: 0
            to: 360
            duration: 24000
            loops: Animation.Infinite
            running: true
        }
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 1100, 900)
            eulerRotation.x: -50
        }
    }

    DirectionalLight {
        eulerRotation.x: -50
        eulerRotation.y: -60
    }

    // Poly3D mode: one Model per area, created and destroyed per step.
    Node { id: polyRoot }

    // Strip mode: every area's strips in one batch, which is the fairest
    // version of the workaround - a LineBatch3D per area would be worse.
    LineBatch3D {
        id: strips
        viewportSize: Qt.vector2d(view3D.width, view3D.height)
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat
        lines: []
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
        outputPath: "file:///tmp/clay_bench/areas.csv"
        intervalMs: 250
        extra: ({
            "mode": function() { return view3D.currentMode },
            "area_count": function() { return view3D.currentN },
            "strip_count": function() { return view3D.stripCount },
            "build_ms": function() { return view3D.lastBuildMs.toFixed(1) }
        })
        running: false
    }

    Component.onCompleted: bench.running = true

    // Deterministic LCG so re-runs are byte-comparable.
    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    // A convex blob: sorted angles with jittered radii. Convex matters - the
    // strip fill needs exactly two scanline intersections to stay simple, and
    // making the workaround harder than it was would rig the comparison.
    function makeRing(rng, radius) {
        var pts = []
        for (var i = 0; i < view3D.ringPoints; ++i) {
            var a = (i / view3D.ringPoints) * Math.PI * 2
            var r = radius * (0.65 + rng() * 0.35)
            pts.push(Qt.vector2d(Math.cos(a) * r, Math.sin(a) * r))
        }
        return pts
    }

    // Where a horizontal line at z crosses the ring. Convex, so 0 or 2 hits.
    function spanAt(ring, z) {
        var xs = []
        for (var i = 0; i < ring.length; ++i) {
            var a = ring[i]
            var b = ring[(i + 1) % ring.length]
            if ((a.y <= z && b.y > z) || (b.y <= z && a.y > z)) {
                var t = (z - a.y) / (b.y - a.y)
                xs.push(a.x + t * (b.x - a.x))
            }
        }
        if (xs.length < 2)
            return null
        return xs[0] < xs[1] ? [xs[0], xs[1]] : [xs[1], xs[0]]
    }

    property var polyComponent: null

    function buildPolys(n) {
        var t0 = Date.now()
        var rng = makeRng(view3D.seed)
        if (!polyComponent)
            polyComponent = Qt.createComponent("PolyBenchArea.qml")
        for (var i = 0; i < n; ++i) {
            var cx = (rng() * 2 - 1) * view3D.extent
            var cz = (rng() * 2 - 1) * view3D.extent
            var ring = makeRing(rng, 60 + rng() * 60)
            polyComponent.createObject(polyRoot, {
                x: cx, z: cz,
                ring: ring,
                fill: Qt.hsla(rng(), 0.5, 0.55, 1.0)
            })
        }
        view3D.stripCount = 0
        view3D.lastBuildMs = Date.now() - t0
    }

    function buildStrips(n) {
        var t0 = Date.now()
        var rng = makeRng(view3D.seed)   // same seed: identical polygons
        var out = []
        for (var i = 0; i < n; ++i) {
            var cx = (rng() * 2 - 1) * view3D.extent
            var cz = (rng() * 2 - 1) * view3D.extent
            var ring = makeRing(rng, 60 + rng() * 60)
            var col = Qt.hsla(rng(), 0.5, 0.55, 1.0)

            var zMin = ring[0].y, zMax = ring[0].y
            for (var p = 1; p < ring.length; ++p) {
                if (ring[p].y < zMin) zMin = ring[p].y
                if (ring[p].y > zMax) zMax = ring[p].y
            }
            var stepZ = (zMax - zMin) / view3D.stripsPerArea
            for (var s = 0; s < view3D.stripsPerArea; ++s) {
                var z = zMin + (s + 0.5) * stepZ
                var span = spanAt(ring, z)
                if (!span)
                    continue
                // The depth ramp: each strip sits a hair above the last so the
                // coplanar ribbons stop fighting. This is the hand-tuning the
                // workaround needed and Poly3D removes.
                var y = 0.02 + s * 0.01
                out.push({
                    points: [Qt.vector3d(cx + span[0], y, cz + z),
                             Qt.vector3d(cx + span[1], y, cz + z)],
                    color: col,
                    width: stepZ * 1.05,   // slight overlap, or the fill bands
                    styleId: 0
                })
            }
        }
        strips.lines = out
        view3D.stripCount = out.length
        view3D.lastBuildMs = Date.now() - t0
    }

    function clearAll() {
        strips.lines = []
        view3D.stripCount = 0
        for (var i = polyRoot.children.length - 1; i >= 0; --i)
            polyRoot.children[i].destroy()
    }

    function startStep(i) {
        stepIndex = i
        currentMode = steps[i].mode
        currentN = steps[i].n
        measureMarked = false
        clearAll()
        if (currentMode === "poly")
            buildPolys(currentN)
        else
            buildStrips(currentN)
        bench.annotate("step_start", currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP areas mode=" + currentMode + " N=" + currentN
                    + " strips=" + stripCount + " build_ms=" + lastBuildMs)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        console.log("BENCH DONE areas")
    }

    function flagInfo() {
        return { scenario: "areas", step: stepIndex, mode: currentMode,
                 areaCount: currentN, stripCount: stripCount,
                 buildMs: lastBuildMs, done: benchDone }
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
