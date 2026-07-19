// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Instance-table benchmark: N boxes orbiting a centre, animated every frame,
// with a toggle between a declarative InstanceList (one InstanceListEntry
// QObject per box, position + eulerRotation written per frame) and the
// C++-backed DynamicInstances3D (per-frame poses packed into one reused
// Float32Array, a single updatePoses() upload per table). Same motion, same
// camera for both backends so fps / frame_ms are directly comparable.
//
// Auto-runs every (backend, N) step, logs a CSV into benchmarks/results/ via
// BenchLogger and prints "BENCH DONE instances" when finished.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 720

    // --- fixed scenario parameters (identical across backends) ---
    readonly property int seed: 1337
    readonly property var steps: [1000, 5000, 20000]
    readonly property var backends: ["instancelist", "dynamic"]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real extent: 400
    readonly property real heightExtent: 120
    readonly property real minFps: 5

    // --- driver state ---
    property var plan: []          // flattened [{backend, n}, ...]
    property int planIndex: -1
    property string backend: ""
    property int currentN: 0
    property real phase: 0
    property real stepStartMs: 0
    property bool measureMarked: false
    property bool benchDone: false

    // --- per-box static layout (radius, base angle, y, scale, color) ---
    property var _radius: []
    property var _angle0: []
    property var _y: []
    // reused pose buffer for the dynamic backend
    property var _poseBuf: null
    // InstanceListEntry objects for the declarative backend
    property var _entries: []

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - identical for both backends.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 380, 780)
        eulerRotation.x: -24
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
    }

    Component { id: entryComp; InstanceListEntry {} }

    // Declarative backend: one InstanceListEntry per box.
    Model {
        id: listModel
        source: "#Cube"
        visible: view3D.backend === "instancelist"
        castsShadows: false
        receivesShadows: false
        instancing: InstanceList { id: listInst; instances: view3D._entries }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
        }
    }

    // C++-backed backend: one DynamicInstances3D table.
    Model {
        id: dynModel
        source: "#Cube"
        visible: view3D.backend === "dynamic"
        castsShadows: false
        receivesShadows: false
        instancing: DynamicInstances3D { id: dynInst }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
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
        // Written out-of-tree (writing into the watched sandbox dir triggers a
        // reload that truncates the file); copy to results/ after the run.
        outputPath: "file:///tmp/clay_bench/instances-2026-07-19.csv"
        intervalMs: 250
        extra: ({
            "backend": function() { return view3D.backend },
            "instance_count": function() { return view3D.currentN },
            "pack_ms": function() { return dynInst.packMsLast.toFixed(3) }
        })
        running: false
    }

    Component.onCompleted: {
        var p = []
        for (var b = 0; b < backends.length; ++b)
            for (var s = 0; s < steps.length; ++s)
                p.push({ backend: backends[b], n: steps[s] })
        plan = p
        bench.running = true
    }

    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    // Build the fixed per-box layout for currentN boxes (deterministic).
    function _buildLayout() {
        var rng = makeRng(seed)
        var radius = new Array(currentN)
        var angle0 = new Array(currentN)
        var ys = new Array(currentN)
        for (var i = 0; i < currentN; ++i) {
            radius[i] = 40 + rng() * extent
            angle0[i] = rng() * Math.PI * 2
            ys[i] = (rng() * 2 - 1) * heightExtent
        }
        _radius = radius; _angle0 = angle0; _y = ys
    }

    // Tear down the previous step's per-backend resources.
    function _teardown() {
        for (var i = 0; i < _entries.length; ++i) _entries[i].destroy()
        _entries = []
        _poseBuf = null
    }

    function _setupBackend() {
        var scale = Qt.vector3d(0.08, 0.08, 0.20)
        if (backend === "instancelist") {
            var arr = new Array(currentN)
            for (var i = 0; i < currentN; ++i)
                arr[i] = entryComp.createObject(view3D, { scale: scale })
            _entries = arr
        } else {
            var scales = [], colors = []
            var white = Qt.rgba(1, 1, 1, 1)
            for (var j = 0; j < currentN; ++j) { scales.push(scale); colors.push(white) }
            dynInst.setBulk(scales, colors)
            dynInst.setExtents(Qt.vector3d(-extent - 40, -heightExtent - 20, -extent - 40),
                               Qt.vector3d(extent + 40, heightExtent + 20, extent + 40))
            _poseBuf = new Float32Array(currentN * 4)
        }
    }

    // One animation frame: every box advances along its orbit.
    function animate() {
        var ph = phase
        if (backend === "instancelist") {
            for (var i = 0; i < _entries.length; ++i) {
                var a = _angle0[i] + ph
                var r = _radius[i]
                var e = _entries[i]
                e.position = Qt.vector3d(Math.cos(a) * r, _y[i], Math.sin(a) * r)
                e.eulerRotation = Qt.vector3d(0, (a + Math.PI * 0.5) * 180 / Math.PI, 0)
            }
        } else if (_poseBuf) {
            var buf = _poseBuf
            for (var k = 0; k < currentN; ++k) {
                var ang = _angle0[k] + ph
                var rad = _radius[k]
                var o = k * 4
                buf[o]     = Math.cos(ang) * rad
                buf[o + 1] = _y[k]
                buf[o + 2] = Math.sin(ang) * rad
                buf[o + 3] = ang + Math.PI * 0.5
            }
            dynInst.updatePoses(0, buf.buffer)
        }
    }

    function startStep(i) {
        _teardown()
        planIndex = i
        backend = plan[i].backend
        currentN = plan[i].n
        phase = 0
        measureMarked = false
        _buildLayout()
        _setupBackend()
        bench.annotate("step_start", backend + "@" + currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP instances backend=" + backend + " N=" + currentN)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        frameDriver.running = false
        console.log("BENCH DONE instances")
    }

    function flagInfo() {
        return { scenario: "instances", step: planIndex, backend: backend,
                 instanceCount: currentN, packMs: dynInst.packMsLast,
                 fps: (renderStats ? renderStats.fps : -1), done: benchDone }
    }

    FrameAnimation {
        id: frameDriver
        running: true
        onTriggered: {
            view3D.phase += 0.02
            view3D.animate()
        }
    }

    Timer {
        id: driveTimer
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (view3D.planIndex < 0) {
                view3D.startStep(0)
                return
            }
            var el = Date.now() - view3D.stepStartMs
            if (!view3D.measureMarked && el >= view3D.warmupMs) {
                bench.annotate("measure_start", view3D.backend + "@" + view3D.currentN)
                view3D.measureMarked = true
            }
            if (view3D.measureMarked && view3D.renderStats
                    && view3D.renderStats.fps > 0
                    && view3D.renderStats.fps < view3D.minFps) {
                bench.annotate("early_stop", "fps<" + view3D.minFps)
                console.log("BENCH EARLY-STOP instances at " + view3D.backend
                            + " N=" + view3D.currentN + " fps=" + view3D.renderStats.fps)
                // Skip to the next step rather than ending the whole run.
                view3D._advanceOrFinish()
                return
            }
            if (el >= view3D.stepDurationMs)
                view3D._advanceOrFinish()
        }
    }

    function _advanceOrFinish() {
        if (planIndex + 1 < plan.length)
            startStep(planIndex + 1)
        else
            finish()
    }
}
