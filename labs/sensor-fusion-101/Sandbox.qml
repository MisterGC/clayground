// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Algorithm
import Clayground.Lab
import "../kits/sensor"
import "track.js" as Track

// Sensor Fusion 101 — a car on a loop track fuses noisy GPS, drifting
// odometry and landmark lidar into one estimate (2D Kalman filter).
// Keys: 1 open-sky · 2 tunnel · 3 lidar-out · T tour · R record.
Item {
    id: root
    anchors.fill: parent
    focus: true
    Component.onCompleted: { forceActiveFocus(); applyScenario("open-sky") }

    // --- parameters -----------------------------------------------------
    Parameter { id: pSpeed; name: "speed"; value: 6; from: 2; to: 15; unit: "m/s" }
    Parameter { id: pGpsSigma; name: "gpsSigma"; value: 3; from: 0.5; to: 10; unit: "m" }
    Parameter { id: pGpsRate; name: "gpsRate"; value: 1; from: 0.2; to: 5; unit: "Hz" }
    Parameter { id: pOdoDrift; name: "odoDrift"; value: 0.04; from: 0; to: 0.2 }
    Parameter { id: pLidarSigma; name: "lidarSigma"; value: 0.5; from: 0.1; to: 2; unit: "m" }
    Parameter { id: pLidarRange; name: "lidarRange"; value: 22; from: 5; to: 40; unit: "m" }
    Parameter { id: pSimSpeed; name: "simSpeed"; value: 0.5; from: 0.1; to: 2 }

    SimClock { id: clock; seed: 42; sampleInterval: 0.05; timeScale: pSimSpeed.value }

    // --- truth ----------------------------------------------------------
    readonly property var carPose: Track.poseAt(pSpeed.value * clock.time)
    function truePos() { return {x: carPose.x, y: carPose.y} }

    readonly property var buildingData: [
        {x: 30, y: 10, h: 7}, {x: 30, y: -12, h: 5}, {x: 0, y: 22, h: 9},
        {x: -30, y: 2, h: 6}, {x: -8, y: -22, h: 8}, {x: 27, y: 21, h: 4},
        {x: -27, y: 21, h: 7}, {x: -27, y: -20, h: 5}, {x: 13, y: -24, h: 6},
        {x: 0, y: 2, h: 10}
    ]

    property bool tunnelOn: false
    readonly property bool carInTunnel: carPose.y < -10 && Math.abs(carPose.x) < 11

    // --- estimation (order matters: predict before sensor corrections) --
    property real _lastT: -1
    Connections {
        target: clock
        function onWasReset() {
            root._lastT = -1
            const p = Track.poseAt(0)
            kf.reset(p.x, p.y)
        }
    }
    Connections {
        target: Lab
        function onSampled(t) {
            const dt = root._lastT < 0 ? 0 : t - root._lastT
            root._lastT = t
            if (dt > 0) kf.predict(dt)
        }
    }

    KalmanFilter2D { id: kf; processNoise: 1.2 }

    GpsSensor {
        id: gps; clock: clock; truePos: root.truePos
        sigmaM: pGpsSigma.value; rateHz: pGpsRate.value
        available: !(root.tunnelOn && root.carInTunnel)
        onFix: (x, y, t) => kf.correct(x, y, sigmaM)
    }
    OdometrySensor {
        id: odo; clock: clock; truePos: root.truePos
        driftRate: pOdoDrift.value
    }
    // the tunnel blocks GPS (radio) and confuses the lidar (bare walls) —
    // inside it the filter runs on prediction + odometry character alone
    LidarSensor {
        id: lidar; clock: clock; truePos: root.truePos
        landmarks: root.buildingData
        sigmaM: pLidarSigma.value; range: pLidarRange.value
        enabled: root._lidarOn && !(root.tunnelOn && root.carInTunnel)
        onFix: (x, y, t) => kf.correct(x, y, sigmaM)
    }
    property bool _lidarOn: true

    // --- probes ---------------------------------------------------------
    function _dist(x, y) { return Math.hypot(x - carPose.x, y - carPose.y) }
    Probe { name: "errFused"; unit: "m"; expr: () => root._dist(kf.estX, kf.estY) }
    Probe { name: "errOdo"; unit: "m"; expr: () => root._dist(odo.estX, odo.estY) }
    Probe {
        name: "errGps"; unit: "m"
        expr: () => gps.lastFix ? root._dist(gps.lastFix.x, gps.lastFix.y) : NaN
    }
    Probe { name: "uncertainty"; unit: "m"; expr: () => Math.hypot(kf.sigmaX, kf.sigmaY) }

    // --- scenarios ------------------------------------------------------
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "open-sky"; description: "all sensors healthy"
            script: () => { root.tunnelOn = false; root._lidarOn = true }
        }
        Scenario {
            name: "tunnel"; description: "GPS and lidar drop out inside the tunnel"
            script: () => { root.tunnelOn = true; root._lidarOn = true }
        }
        Scenario {
            name: "lidar-out"; description: "lidar failed, GPS-only fusion"
            script: () => { root.tunnelOn = false; root._lidarOn = false }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }
    function labInfo() {
        const info = Lab.labInfo()
        info.carInTunnel = carInTunnel
        info.gpsAvailable = gps.available
        info.lidarHits = lidar.hits.length
        return info
    }
    function flagInfo() { return labInfo() }

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_1) applyScenario("open-sky")
        else if (ev.key === Qt.Key_2) applyScenario("tunnel")
        else if (ev.key === Qt.Key_3) applyScenario("lidar-out")
        else if (ev.key === Qt.Key_T) tour.index < 0 ? tour.start() : tour.next()
        else if (ev.key === Qt.Key_R) recorder.recording = !recorder.recording
        else if (ev.key === Qt.Key_C) followCam = !followCam
    }
    property bool followCam: true

    DataRecorder { id: recorder; destination: "sensor-fusion-run.csv" }

    // --- 3D scene -------------------------------------------------------
    View3D {
        anchors.fill: parent
        environment: SceneEnvironment {
            clearColor: "#0d0d1a"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
        }
        id: view3d
        camera: root.followCam ? camFollow : camOverview

        PerspectiveCamera {
            id: camOverview
            position: Qt.vector3d(0, 52, 62)
            eulerRotation: Qt.vector3d(-42, 0, 0)
        }
        // close-up rig translating with the true car, fixed viewing angle
        Node {
            position: Qt.vector3d(root.carPose.x, 0, root.carPose.y)
            PerspectiveCamera {
                id: camFollow
                position: Qt.vector3d(0, 13, 17)
                eulerRotation: Qt.vector3d(-36, 0, 0)
            }
        }
        DirectionalLight {
            eulerRotation.x: -35
            castsShadow: true
            shadowFactor: 78
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            ambientColor: Qt.rgba(0.45, 0.45, 0.5, 1)
        }

        Box3D { width: 92; height: 0.5; depth: 62; y: -0.25; color: "#101722" }

        MultiLine3D { coords: [Track.ringCoords(0.06, 140)]; color: "#3a4356"; width: 3 }

        Repeater3D {
            model: root.buildingData
            Box3D {
                required property var modelData
                x: modelData.x; z: modelData.y
                width: 4; depth: 4; height: modelData.h; y: modelData.h / 2
                color: "#1d2739"
            }
        }

        Box3D {
            visible: root.tunnelOn
            x: 0; z: -14; y: 2
            width: 22; height: 4; depth: 7
            color: "#151a24"
        }

        // truth (gold), odometry belief (gray), fused estimate (cyan)
        Box3D {
            id: carTruth
            x: root.carPose.x; z: root.carPose.y; y: 0.6
            width: 2.2; depth: 1.2; height: 1.2
            color: "#ffd93d"
            eulerRotation.y: -root.carPose.heading * 180 / Math.PI
        }
        Box3D {
            id: carOdo
            x: odo.estX; z: odo.estY; y: 0.6
            width: 2.2; depth: 1.2; height: 1.2
            color: "#4a4f58"; opacity: 0.55
        }
        Box3D {
            id: carFused
            x: kf.estX; z: kf.estY; y: 0.6
            width: 2.2; depth: 1.2; height: 1.2
            color: "#00d9ff"; opacity: 0.6
        }

        // callout labels tracking the three cars, live values inline
        Label3D {
            view: view3d; anchorNode: carTruth
            labelOffset: Qt.vector3d(0, 4.5, 0)
            text: "TRUTH"
            labelStyle.borderColor: "#ffd93d"
            showLeader: true
            leaderStyle.color: "#ffffff"; leaderStyle.width: 1.5
        }
        Label3D {
            view: view3d; anchorNode: carOdo
            labelOffset: Qt.vector3d(-4, 7, 0)
            text: "ODOMETRY  drift " + root._dist(odo.estX, odo.estY).toFixed(1) + " m"
            labelStyle.borderColor: "#889099"
            showLeader: true
            leaderStyle.color: "#ffffff"; leaderStyle.width: 1.5
        }
        Label3D {
            view: view3d; anchorNode: carFused
            labelOffset: Qt.vector3d(4, 9, 0)
            text: "FUSED  ±" + Math.hypot(kf.sigmaX, kf.sigmaY).toFixed(1) + " m"
            labelStyle.borderColor: "#00d9ff"
            showLeader: true
            leaderStyle.color: "#ffffff"; leaderStyle.width: 1.5
        }
        Label3D {
            view: view3d
            visible: root.tunnelOn && root.carInTunnel
            anchorPosition: Qt.vector3d(0, 4, -14)
            labelOffset: Qt.vector3d(0, 5, 0)
            text: "⚠ GPS + LIDAR BLACKOUT"
            labelStyle.borderColor: "#ff3366"
        }

        // uncertainty disc (1-sigma ellipse footprint)
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(kf.estX, 0.1, kf.estY)
            scale: Qt.vector3d(kf.sigmaX * 2 / 100, 0.002, kf.sigmaY * 2 / 100)
            materials: PrincipledMaterial {
                baseColor: "#00d9ff"; opacity: 0.22; lighting: PrincipledMaterial.NoLighting
            }
        }

        // recent GPS fixes
        Repeater3D {
            model: gps.fixes
            Box3D {
                required property var modelData
                x: modelData.x; z: modelData.y; y: 0.3
                width: 0.5; height: 0.5; depth: 0.5
                color: "#ff3366"; opacity: 0.7
            }
        }

        // lidar beams to matched landmarks
        MultiLine3D {
            coords: lidar.hits.map(h => [
                Qt.vector3d(root.carPose.x, 1.4, root.carPose.y),
                Qt.vector3d(h.x, 1.4, h.y)])
            color: "#0f9d9a"; width: 0.12
        }
    }

    // --- lab UI ---------------------------------------------------------
    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    Plot2D {
        id: plot
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 10
        height: 150
        probes: ["errGps", "errOdo", "errFused"]
        seriesColors: ["#ff3366", "#889099", "#00d9ff"]
    }
    LidarMonitor {
        carPose: root.carPose
        lidar: lidar
        buildings: root.buildingData
        tunnelOn: root.tunnelOn
        anchors.right: parent.right; anchors.bottom: plot.top; anchors.margins: 10
    }
    Tour {
        id: tour
        scenarioSet: scenarioSet
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
        TourStep {
            title: "GPS is honest but noisy"; scenario: "open-sky"
            say: "Each pink cube is one GPS fix: unbiased, but scattered by meters. Crank gpsSigma and watch the scatter explode."
        }
        TourStep {
            title: "Odometry is smooth but drifts"
            say: "The gray car integrates wheel motion. No noise spikes — but its heading error accumulates and it slowly walks away from the gold truth."
        }
        TourStep {
            title: "Fusion weighs by uncertainty"
            say: "The cyan car is the Kalman estimate fusing GPS and lidar. The glowing disc is its 1-sigma uncertainty — small while lidar sees landmarks."
        }
        TourStep {
            title: "Losing a sensor"; scenario: "tunnel"
            say: "In the tunnel GPS vanishes. Watch the disc breathe: uncertainty grows on prediction alone, then snaps shut when fixes return."
        }
    }
    Text {
        x: 10; y: parent.height - 180
        text: "SENSOR FUSION 101 — 1 open-sky · 2 tunnel · 3 lidar-out · T tour · C camera · R record"
              + (recorder.recording ? "  ● REC (" + recorder.rows + ")" : "")
              + (root.tunnelOn && root.carInTunnel ? "  ⚠ GPS LOST" : "")
        color: recorder.recording ? "#ff3366" : "#889099"
        font.pixelSize: 12
    }
}
