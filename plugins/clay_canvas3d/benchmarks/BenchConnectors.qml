// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Benchmark: N Connector3D lines whose endpoints move every frame, drawn as a
// single ConnectorLayer3D batch. Exercises the per-frame endpoint-patch path
// (one table patch + one upload, no geometry rebuild).

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent
    width: parent ? parent.width : 1280
    height: parent ? parent.height : 720

    // --- fixed scenario parameters ---
    readonly property int seed: 1337
    readonly property var steps: [100, 500, 1000, 5000, 10000]
    readonly property real warmupMs: 2000
    readonly property real stepDurationMs: 8000
    readonly property real minFps: 5

    // --- driver state ---
    property int stepIndex: -1
    property int currentN: 0
    property real phase: 0
    property real stepStartMs: 0
    property bool measureMarked: false
    property bool benchDone: false
    property var sats: []
    property var hubList: [hub0, hub1, hub2]

    environment: SceneEnvironment {
        clearColor: "#101018"
        backgroundMode: SceneEnvironment.Color
    }

    // Fixed camera - keep identical across runs.
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 300, 1500)
        eulerRotation.x: -12
        clipFar: 40000
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
    }

    Node { id: hub0; position: Qt.vector3d(-500, 100, 0) }
    Node { id: hub1; position: Qt.vector3d(500, 100, 0) }
    Node { id: hub2; position: Qt.vector3d(0, 150, -400) }

    ConnectorLayer3D {
        id: links
        viewportSize: Qt.vector2d(view3D.width, view3D.height)
        widthUnits: LineBatch3D.Pixel
        width: 1.5
        color: "#00d9ff"
    }

    Repeater3D {
        id: rep
        model: 0
        delegate: Node {
            id: sat
            required property int index
            Connector3D {
                layer: links
                from: sat
                to: view3D.hubList[sat.index % view3D.hubList.length]
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
        // Written out-of-tree; copy to results/ after the run.
        outputPath: "file:///tmp/clay_bench/connectors-2026-07-18.csv"
        intervalMs: 250
        extra: ({
            "connector_count": function() { return view3D.currentN }
        })
        running: false
    }

    Component.onCompleted: bench.running = true

    function makeRng(s) {
        var state = s >>> 0
        return function() {
            state = (state * 1664525 + 1013904223) >>> 0
            return state / 4294967296
        }
    }

    function rebuildSats(n) {
        var arr = new Array(n)
        var rng = makeRng(view3D.seed)
        var hubCount = hubList.length
        for (var i = 0; i < n; ++i) {
            arr[i] = {
                hub: i % hubCount,
                angle: rng() * 6.2831853,
                radius: 120 + rng() * 320,
                speed: 0.4 + rng() * 1.6,
                yoff: (rng() * 2 - 1) * 180
            }
        }
        sats = arr
        rep.model = n
    }

    function orbit(i, ph) {
        var s = sats[i]
        var c = hubList[s.hub].position
        var a = s.angle + ph * s.speed
        return Qt.vector3d(c.x + Math.cos(a) * s.radius,
                           c.y + Math.sin(a * 0.7) * s.radius * 0.5 + s.yoff,
                           c.z + Math.sin(a) * s.radius)
    }

    function startStep(i) {
        stepIndex = i
        currentN = steps[i]
        measureMarked = false
        rebuildSats(currentN)
        bench.annotate("step_start", currentN)
        stepStartMs = Date.now()
        console.log("BENCH STEP connectors N=" + currentN)
    }

    function finish() {
        if (benchDone)
            return
        benchDone = true
        bench.running = false
        driveTimer.stop()
        frameDriver.running = false
        console.log("BENCH DONE connectors")
    }

    function flagInfo() {
        return { scenario: "connectors", step: stepIndex, connectorCount: currentN,
                 fps: (renderStats ? renderStats.fps : -1), done: benchDone }
    }

    // Move every satellite each frame - the moving-connector workload.
    FrameAnimation {
        id: frameDriver
        running: true
        onTriggered: {
            view3D.phase += 0.03
            var n = rep.count
            for (var i = 0; i < n; ++i) {
                var s = rep.objectAt(i)
                if (s)
                    s.position = view3D.orbit(i, view3D.phase)
            }
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
            if (view3D.measureMarked && view3D.renderStats
                    && view3D.renderStats.fps > 0
                    && view3D.renderStats.fps < view3D.minFps) {
                bench.annotate("early_stop", "fps<" + view3D.minFps + "@N=" + view3D.currentN)
                console.log("BENCH EARLY-STOP connectors at N=" + view3D.currentN
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
