// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Algorithm
import Clayground.Lab
import "../kits/sensor"
import "track.js" as Track
import "../kits/sensor/gnss.js" as Gnss
import "../kits/sensor/strings.js" as KitStrings
import "strings.js" as Strings

// Sensor Fusion 101 — a car on a loop track fuses noisy GPS, drifting
// odometry and landmark lidar against a map into one estimate (2D Kalman
// filter). Keys: 1-3 presets · T flow · C camera · M lidar panel · # grid ·
// F frame the car · 0 frame the city · ⇧R record · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true
    Component.onCompleted: {
        LabLang.register(KitStrings.dict)   // sensor vocabulary first...
        LabLang.register(Strings.dict)      // ...lab copy may override it
        forceActiveFocus()
        applyScenario("open-sky")
    }

    // view-only toggles (LabKeys drives them, viewState carries them)
    property bool followCam: true
    property bool showMonitor: true
    property bool showGrid: true

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

    // --- the sky ---------------------------------------------------------
    // Satellites drift on a dome around the city (schematic: tens of units, not
    // 20 200 km - real geometry varies mildly, this varies visibly). Time-driven
    // only, so the constellation never touches the seeded RNG stream.
    readonly property int satCount: 6
    readonly property real satRadius: 62
    property var satellites: []
    // line-of-sight blockers: exactly the boxes you can see standing there
    readonly property var losBlockers: {
        const out = []
        for (const b of buildingData)
            out.push({ minx: b.x - 2, maxx: b.x + 2, miny: 0, maxy: b.h,
                       minz: b.y - 2, maxz: b.y + 2 })
        if (tunnelOn)
            out.push({ minx: -11, maxx: 11, miny: 0, maxy: 2.7,
                       minz: -17.5, maxz: -10.5 })
        return out
    }

    property bool tunnelOn: false
    readonly property bool carInTunnel: carPose.y < -10 && Math.abs(carPose.x) < 11

    property Connections _skyConn: Connections {
        target: Lab
        function onSampled(t) { root.satellites = Gnss.constellation(t, root.satCount, root.satRadius) }
    }

    // --- fusion bookkeeping ----------------------------------------------
    // The scalar Kalman gain, K = P / (P + R): how far the estimate is pulled
    // toward a measurement. Recorded per sensor at the moment it is applied,
    // so the overlay shows the real arithmetic rather than a cartoon of it.
    property real sigmaPredicted: 5
    property var lastUpdate: ({ gps: { sigma: 0, gain: 0, t: -99 },
                                lidar: { sigma: 0, gain: 0, t: -99 } })
    property int fusionRev: 0
    function applyMeasurement(sensor, x, y, sigma) {
        const pBefore = Math.hypot(kf.sigmaX, kf.sigmaY) / Math.SQRT2
        sigmaPredicted = pBefore
        const gain = (pBefore * pBefore) / (pBefore * pBefore + sigma * sigma)
        kf.correct(x, y, sigma)
        lastUpdate[sensor] = { sigma: sigma, gain: gain,
                               t: clock ? clock.time : 0 }
        fusionRev++
    }

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
        satellites: root.satellites
        blockers: root.losBlockers
        // the KF is told what the fix is actually worth: per-range noise
        // multiplied by the geometry that produced it
        onFix: (x, y, t) => root.applyMeasurement("gps", x, y, Math.max(0.3, posSigma))
    }
    OdometrySensor {
        id: odo; clock: clock; truePos: root.truePos
        driftRate: pOdoDrift.value
    }
    // The tunnel needs no special case here: its walls are in `blockers`, so
    // from inside it every mapped landmark is occluded and the fix dies of its
    // own accord. `enabled` is reserved for a genuine sensor failure (key 3).
    LidarSensor {
        id: lidar; clock: clock; truePos: root.truePos
        landmarks: root.buildingData          // the map it matches against
        blockers: root.losBlockers            // same boxes, same order
        trueHeading: root.carPose.heading
        assumedHeadingError: odo.headingErr   // its heading comes from odometry
        sigmaM: pLidarSigma.value; range: pLidarRange.value
        enabled: root._lidarOn
        onFix: (x, y, t) => root.applyMeasurement("lidar", x, y, Math.max(0.05, posSigma))
    }
    property bool _lidarOn: true

    // --- probes ---------------------------------------------------------
    // mix a colour toward the ground, k = 1 keeps it, k = 0 dissolves it
    function fadeToGround(c, k) {
        const g = LabTheme.sheet
        const ch = v => {
            const h = Math.round(255 * Math.max(0, Math.min(1, v))).toString(16)
            return h.length < 2 ? "0" + h : h
        }
        return "#" + ch(g.r + (c.r - g.r) * k)
                   + ch(g.g + (c.g - g.g) * k)
                   + ch(g.b + (c.b - g.b) * k)
    }

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
    // --- flow actions ------------------------------------------------------
    // Same convention as electronics-101, entirely different verbs: this lab
    // has no parts to place, it has knobs, scenarios and a camera.
    function flowActions() {
        return {
            "scenario":  (n) => applyScenario(n),
            "setParam":  (name, v) => Lab.set(name, v),
            "simSpeed":  (v) => Lab.set("simSpeed", v),
            "followCam": (on) => { followCam = on },
            "monitor":   (on) => { showMonitor = on },
            "record":    (on) => { recorder.recording = on }
        }
    }
    function flows() { return [fusionFlow.flowId] }
    function startFlow(id) {
        if (id === fusionFlow.flowId) { fusionFlow.start(); return true }
        return false
    }

    function labInfo() {
        const info = Lab.labInfo()
        info.flow = { id: fusionFlow.running ? fusionFlow.flowId : "",
                      step: fusionFlow.index }
        info.carInTunnel = carInTunnel
        info.gpsAvailable = gps.available
        info.lidarAvailable = lidar.available
        info.lidarUsed = lidar.usedCount
        return info
    }
    function flagInfo() { return labInfo() }

    // the two framings LabKeys binds to 0 and F
    function frameAll() {
        followCam = false
        orbit.frame([Qt.vector3d(-30, 0, -22), Qt.vector3d(30, 0, 22)], 1.35)
    }
    function frameSelection() {
        followCam = false
        orbit.frame([Qt.vector3d(carPose.x - 12, 0, carPose.y - 12),
                     Qt.vector3d(carPose.x + 12, 0, carPose.y + 12)], 1.2)
    }

    // View-state for the dojo reload convention.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            followCam: followCam,
            cam: orbit.state(),
            tunnelOn: tunnelOn,
            lidarOn: _lidarOn,
            showMonitor: showMonitor,
            showGrid: showGrid,
            lang: LabLang.lang
        })
    }
    // Ordering matters for a bit-identical restore: (1) scenario apply resets
    // clock + RNG, (2) set the toggles the sensors read, (3) Lab.applyViewState
    // re-steps the world-less clock, replaying sensors + Kalman deterministically,
    // (4) restore the view-only state (no effect on the sim).
    function applyViewState(s) {
        if (s.scenario) applyScenario(s.scenario)
        if (s.tunnelOn !== undefined) tunnelOn = s.tunnelOn
        if (s.lidarOn !== undefined) _lidarOn = s.lidarOn
        Lab.applyViewState(s)
        if (s.cam) orbit.applyState(s.cam)
        if (s.followCam !== undefined) followCam = s.followCam
        if (s.showMonitor !== undefined) showMonitor = s.showMonitor
        if (s.showGrid !== undefined) showGrid = s.showGrid
        if (s.lang) LabLang.lang = s.lang
    }

    DataRecorder { id: recorder; destination: "sensor-fusion-run.csv" }

    // --- 3D scene -------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent

        // Ground, light rig and environment in one block. The city stands on
        // the shared lab stage: an endless sheet of squared paper whose raster
        // is drawn in the fragment shader, so the scale reference holds at any
        // zoom and there is no board edge to run out of. `#` still turns the
        // rules off. No snap cue - the raster here is a ruler, not a pegboard,
        // and nothing in this lab places anything on it.
        LabStage3D {
            id: stage
            cellSize: 4
            majorEvery: 5                 // a heavier rule every 20 m, as before
            workExtent: Qt.vector2d(88, 56)
            shadowMapFar: 300             // covers the city at maxDistance 220
            cueSize: 0
            minorWidth: root.showGrid ? 1.0 : 0
            majorWidth: root.showGrid ? 1.6 : 0
        }
        environment: stage.environment

        camera: root.followCam ? camFollow : orbit.camera

        // free look: drag to orbit, wheel to zoom, 0 to reframe. On a leash -
        // it always looks at the city and never sinks through the ground.
        OrbitCamera3D {
            id: orbit
            pivot: Qt.vector3d(0, 0, -2)
            yaw: 0; pitch: 42; distance: 78
            minPitch: 8; maxPitch: 84
            minDistance: 14; maxDistance: 220
            minHeight: 6
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
        // the street: a marking on the ground, so it lies FLAT - a billboard
        // ribbon splays on curves and breaks the road into wedges. Opaque with
        // a depth bias so it sits on the ground plane instead of fighting it.
        LineBatch3D {
            id: roadLine
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            opaque: true
            depthBias: 2
            lines: [{ points: Track.ringCoords(0.03, 480),
                      color: LabTheme.muted, width: 3.4, styleId: 0 }]
        }

        Repeater3D {
            model: root.buildingData
            Box3D {
                required property var modelData
                x: modelData.x; z: modelData.y
                width: 4; depth: 4; height: modelData.h; y: 0
                color: LabTheme.inkFaint
                useToonShading: true
                edgeColorFactor: 0.55
            }
        }

        // Which buildings are MAP entries, marked on the ground. Without this
        // the scene says "buildings"; with it, it says "surveyed landmarks" -
        // and a ring brightens exactly while the lidar is using that entry, so
        // the map stops being an invisible assumption.
        LineBatch3D {
            id: landmarkRings
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            depthBias: 3
            lines: {
                const used = {}, hidden = {}
                for (const h of lidar.hits) used[h.x + ":" + h.y] = true
                for (const h of lidar.hidden) hidden[h.x + ":" + h.y] = true
                const out = []
                const segments = 28
                for (const b of root.buildingData) {
                    const key = b.x + ":" + b.y
                    const isUsed = used[key] === true
                    const isHidden = hidden[key] === true
                    const r = isUsed ? 3.5 : 3.1
                    const pts = []
                    for (let i = 0; i <= segments; ++i) {
                        const a = i / segments * 2 * Math.PI
                        pts.push(Qt.vector3d(b.x + r * Math.cos(a), 0.035,
                                             b.y + r * Math.sin(a)))
                    }
                    out.push({ points: pts,
                               color: isUsed
                                      ? LabTheme.teal
                                      : root.fadeToGround(LabTheme.teal,
                                                          isHidden ? 0.5 : 0.3),
                               width: isUsed ? 0.30 : 0.13,
                               styleId: 0 })
                }
                return out
            }
        }

        // The tunnel is a structure, not a floating slab: two walls standing on
        // the ground carry a roof over the road. The footprint matches the
        // blackout test (|x| < 11, z < -10) and the lidar occluder exactly, so
        // what you see is what blocks the sensors.
        Node {
            visible: root.tunnelOn
            Box3D {   // north wall
                x: 0; z: -17.2; y: 0
                width: 22; height: 2.2; depth: 0.6
                color: LabTheme.inkSolid
                useToonShading: true
            }
            Box3D {   // south wall
                x: 0; z: -10.8; y: 0
                width: 22; height: 2.2; depth: 0.6
                color: LabTheme.inkSolid
                useToonShading: true
            }
            Box3D {   // roof, resting on the walls
                x: 0; z: -14; y: 2.2
                width: 22; height: 0.5; depth: 7
                // a shade back toward the ground from the walls, either way round
                color: LabTheme.step(LabTheme.inkSolid, 0.86)
                useToonShading: true
            }
        }

        // truth (gold), odometry belief (gray), fused estimate (cyan)
        Box3D {
            id: carTruth
            x: root.carPose.x; z: root.carPose.y; y: 0.11
            width: 2.2; depth: 1.2; height: 1.2
            color: LabTheme.highlight
            useToonShading: true
            eulerRotation.y: -root.carPose.heading * 180 / Math.PI
        }
        // Estimate markers: pads, not cars. Three boxes of the same size at the
        // same height fought for depth whenever an estimate was right - which
        // is exactly when the lab is working. Each pad owns its own thin slice
        // of height, so nothing is ever coplanar.
        Model {
            id: carOdo
            source: "#Cube"
            position: Qt.vector3d(odo.estX, 0.06, odo.estY)
            scale: Qt.vector3d(0.032, 0.0006, 0.020)
            eulerRotation.y: -root.carPose.heading * 180 / Math.PI
            materials: PrincipledMaterial {
                baseColor: LabTheme.plum; lighting: PrincipledMaterial.NoLighting
            }
            // presentation only: the sim data is untouched, the marker just
            // stops teleporting between sample ticks
            Behavior on position { PropertyAnimation { duration: 90 } }
        }
        Model {
            id: carFused
            source: "#Cube"
            position: Qt.vector3d(kf.estX, 0.09, kf.estY)
            scale: Qt.vector3d(0.028, 0.0006, 0.017)
            eulerRotation.y: -root.carPose.heading * 180 / Math.PI
            materials: PrincipledMaterial {
                baseColor: LabTheme.secondary; lighting: PrincipledMaterial.NoLighting
            }
            // fast enough that a correction still reads as a snap, slow enough
            // to kill the per-frame shimmer
            Behavior on position { PropertyAnimation { duration: 90 } }
        }

        // No tracking callouts any more: pills pinned to moving estimates
        // jitter, overlap each other and cover the road. The legend below
        // carries the same numbers where they can actually be read.
        Label3D {
            view: view3d
            visible: root.tunnelOn && root.carInTunnel
            anchorPosition: Qt.vector3d(0, 4, -14)
            labelOffset: Qt.vector3d(0, 5, 0)
            text: LabLang.t("banner.blackout")
            labelStyle.borderColor: LabTheme.alarm
            labelStyle.background: LabTheme.panel
            labelStyle.textColor: LabTheme.ink
            labelStyle.borderWidth: 2
            labelStyle.halo: false
        }

        // uncertainty disc (1-sigma ellipse footprint)
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(kf.estX, 0.04, kf.estY)
            scale: Qt.vector3d(kf.sigmaX * 2 / 100, 0.0002, kf.sigmaY * 2 / 100)
            Behavior on scale { PropertyAnimation { duration: 120 } }
            materials: PrincipledMaterial {
                baseColor: LabTheme.secondary; opacity: 0.20
                lighting: PrincipledMaterial.NoLighting
            }
        }

        // The sky, drawn: a marker per satellite and a line to the receiver.
        // A solid line is a satellite the fix is actually using; a faint one is
        // blocked by the building or the tunnel you can see in the way.
        Repeater3D {
            model: root.satellites
            Satellite3D {
                required property var modelData
                position: Qt.vector3d(modelData.x, modelData.y, modelData.z)
                size: 2.6
                linked: gps.sky[modelData.id] !== undefined
                        && gps.sky[modelData.id].visible
                target: Qt.vector3d(root.carPose.x, 0.6, root.carPose.y)
                pulse: gps.fixPulse
            }
        }
        LineBatch3D {
            id: signalLines
            widthUnits: LineBatch3D.World
            lines: {
                const out = []
                const rx = Qt.vector3d(root.carPose.x, 0.6, root.carPose.y)
                for (const s of gps.sky) {
                    const seen = s.visible
                    out.push({ points: [Qt.vector3d(s.sat.x, s.sat.y, s.sat.z), rx],
                               color: seen ? LabTheme.rose : LabTheme.muted,
                               width: seen ? 0.10 : 0.05,
                               styleId: 0 })
                }
                return out
            }
            // a fix brightens the links instead of fattening them: constant
            // weight reads as "a signal", a swelling ribbon reads as "a beam"
            opacity: 0.45 + 0.3 * gps.fixPulse
        }

        // GPS fixes as crosshairs on the ground: a survey mark is what a fix
        // is - a claim about a spot on the map - and it never blocks the view
        // of the car the way a stack of cubes did. Oldest fades, newest snaps.
        LineBatch3D {
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            depthBias: 3
            lines: {
                const out = []
                const n = gps.fixes.length
                const y = 0.045
                for (let i = 0; i < n; ++i) {
                    const f = gps.fixes[i]
                    const newest = (i === n - 1)
                    const age = n > 1 ? i / (n - 1) : 1
                    const r = newest ? 1.2 + 0.9 * gps.fixPulse : 0.75
                    const w = newest ? 0.16 + 0.22 * gps.fixPulse : 0.09
                    const c = root.fadeToGround(LabTheme.rose, 0.25 + 0.75 * age)
                    out.push({ points: [Qt.vector3d(f.x - r, y, f.y),
                                        Qt.vector3d(f.x + r, y, f.y)],
                               color: c, width: w, styleId: 0 })
                    out.push({ points: [Qt.vector3d(f.x, y, f.y - r),
                                        Qt.vector3d(f.x, y, f.y + r)],
                               color: c, width: w, styleId: 0 })
                }
                return out
            }
        }

        // lidar beams to matched landmarks
        MultiLine3D {
            coords: lidar.hits.map(h => [
                Qt.vector3d(root.carPose.x, 1.4, root.carPose.y),
                Qt.vector3d(h.x, 1.4, h.y)])
            color: LabTheme.teal; width: 0.12
        }
    }

    // --- lab UI ---------------------------------------------------------
    // HUD slots, as every lab uses them: presets top-left, language top-right
    // with the parameters under it, plot along the bottom, monitor bottom-right.
    // Language and palette, the two switches that change nothing about the
    // experiment and everything about who can read it.
    Row {
        id: topSwitches
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
        spacing: 6
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }
    ParamPanel {
        id: params
        anchors.right: parent.right; anchors.top: topSwitches.bottom
        anchors.rightMargin: 10; anchors.topMargin: 10
    }
    Plot2D {
        id: plot
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 10
        // this lab's plot spans the full width, so it has to yield the
        // bottom-centre slot the hint bar owns in every lab
        anchors.bottomMargin: 38
        height: 150
        series: [
            { probe: "errGps", label: LabLang.t("quantity.errGps"), color: LabTheme.rose },
            { probe: "errOdo", label: LabLang.t("quantity.errOdo"), color: LabTheme.plum },
            { probe: "errFused", label: LabLang.t("quantity.errFused"), color: LabTheme.secondary }
        ]
        placeholder: LabLang.t("plot.empty")
    }
    // Free-look input. Declared before the panels so a drag on the legend or
    // the monitor belongs to that panel, not to the camera.
    MouseArea {
        anchors.fill: parent
        enabled: !root.followCam
        acceptedButtons: Qt.LeftButton
        property real lastX: 0
        property real lastY: 0
        onPressed: (m) => { lastX = m.x; lastY = m.y }
        onPositionChanged: (m) => {
            orbit.orbitBy((m.x - lastX) * 0.35, (m.y - lastY) * 0.25)
            lastX = m.x; lastY = m.y
        }
        onWheel: (w) => orbit.zoomBy(w.angleDelta.y > 0 ? 0.9 : 1.12)
    }

    // --- legend --------------------------------------------------------
    // The numbers live here, not on pills glued to moving objects: readable,
    // never overlapping, and the swatches are how you tell the scene apart.
    LabPanel {
        id: legendPanel
        x: 10; y: 10
        width: 258
        title: LabLang.t("legend.title")

        // sampled at 4 Hz: at the 20 Hz sim rate the last digit is a blur
        property real dOdo: 0
        property real dFused: 0
        property real dGps: 0
        property real dLidar: 0
        property real sigma: 0
        Timer {
            interval: 250; running: true; repeat: true
            onTriggered: {
                legendPanel.dOdo = root._dist(odo.estX, odo.estY)
                legendPanel.dFused = root._dist(kf.estX, kf.estY)
                legendPanel.dGps = gps.lastFix
                                   ? root._dist(gps.lastFix.x, gps.lastFix.y) : 0
                legendPanel.dLidar = lidar.lastFix
                                     ? root._dist(lidar.lastFix.x, lidar.lastFix.y) : 0
                legendPanel.sigma = Math.hypot(kf.sigmaX, kf.sigmaY)
            }
        }

        component Entry: Item {
            property color swatch: LabTheme.ink
            property string label: ""
            property string value: ""
            width: legendPanel.body.width
            height: 17
            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: parent.swatch
            }
            Text {
                x: 18
                width: parent.width - 18 - _val.width - 6
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                text: parent.label
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Text {
                id: _val
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: parent.value
                color: LabTheme.ink; font.pixelSize: 11; font.bold: true
                font.family: LabTheme.monoFont
            }
        }
        Entry {
            swatch: LabTheme.highlight; label: LabLang.t("sensor.truth")
            value: LabLang.t("sensor.reference")
        }
        Entry {
            swatch: LabTheme.secondary; label: LabLang.t("sensor.fused")
            value: LabLang.num(legendPanel.dFused, 1) + " m  \u00b1"
                   + LabLang.num(legendPanel.sigma, 1)
        }
        Entry {
            swatch: LabTheme.plum; label: LabLang.t("sensor.odometry")
            value: LabLang.num(legendPanel.dOdo, 1) + " m " + LabLang.t("sensor.drift")
        }
        Entry {
            swatch: LabTheme.rose; label: LabLang.t("sensor.gpsFix")
            value: gps.available ? LabLang.num(legendPanel.dGps, 1) + " m"
                                 : LabLang.t("sensor.noFix")
        }
        Entry {
            swatch: LabTheme.teal; label: LabLang.t("sensor.lidarFix")
            value: lidar.available ? LabLang.num(legendPanel.dLidar, 1) + " m"
                                   : LabLang.t("sensor.noFix")
        }
        Text {
            width: legendPanel.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("legend.caption")
            color: LabTheme.inkFaint; font.pixelSize: 11
            font.family: LabTheme.handFont
        }
        Item { width: 1; height: 4 }
        // the causal chain, in one line: what the receiver can see, the
        // geometry that gives, and what the fix is therefore worth
        Text {
            width: legendPanel.body.width
            text: LabLang.tf("legend.gpsChain", gps.visibleCount, root.satCount,
                             LabLang.num(gps.hdop, 1), LabLang.num(gps.posSigma, 1))
            color: gps.available ? LabTheme.ink : LabTheme.alarm
            font.pixelSize: 11; font.bold: true
            font.family: LabTheme.monoFont
        }
        Text {
            width: legendPanel.body.width
            wrapMode: Text.WordWrap
            text: gps.available
                  ? LabLang.tf("legend.gpsWhy", LabLang.num(gps.sigmaM, 1))
                  : LabLang.tf("legend.gpsNone", gps.minSats)
            color: LabTheme.inkFaint; font.pixelSize: 11
            font.family: LabTheme.handFont
        }
        // the same chain for the lidar, so the two are comparable at a
        // glance: what it can see, the geometry, what the fix is worth
        Text {
            width: legendPanel.body.width
            text: lidar.available
                  ? LabLang.tf("legend.lidarChain", lidar.usedCount,
                               LabLang.num(lidar.dop, 1),
                               LabLang.num(lidar.posSigma, 2))
                  : LabLang.t("sensor.lidar") + ": " + LabLang.t("sensor.noFix")
            color: lidar.available ? LabTheme.ink : LabTheme.alarm
            font.pixelSize: 11; font.bold: true
            font.family: LabTheme.monoFont
        }
        Text {
            width: legendPanel.body.width
            wrapMode: Text.WordWrap
            text: lidar.available
                  ? LabLang.t("legend.lidarWhy")
                  : (lidar.enabled ? LabLang.tf("legend.lidarNone", lidar.minLandmarks)
                                   : LabLang.t("legend.lidarOff"))
            color: LabTheme.inkFaint; font.pixelSize: 11
            font.family: LabTheme.handFont
        }
    }

    // --- fusion overlay --------------------------------------------------
    // The lab's whole argument in one panel: what each sensor claims, how much
    // the filter believes it, and what comes out. Live, and honest - the gains
    // are the ones actually applied, K = P / (P + R).
    LabPanel {
        id: fusionPanel
        x: 10; y: legendPanel.y + legendPanel.height + 10
        width: 258
        title: LabLang.t("fusion.title")
        spacing: 6

        // recency of each sensor, so a row can light up as its fix lands
        function freshness(key) {
            root.fusionRev
            const u = root.lastUpdate[key]
            if (!u || !clock) return 0
            return Math.max(0, 1 - (clock.time - u.t) / 0.6)
        }

        // prediction: where the motion model says we are, before any sensor
        Row {
            spacing: 6
            Rectangle {
                width: 10; height: 10; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: LabTheme.inkFaint
            }
            Text {
                text: LabLang.t("sensor.predict") + "  \u00b1"
                      + LabLang.num(root.sigmaPredicted, 1) + " m"
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
        }

        // one row per sensor: its claim, and the weight it earned
        component Sensor: Item {
            property string sensorKey: ""
            property color swatch: LabTheme.ink
            property string label: ""
            property bool live: true
            width: fusionPanel.body.width
            height: 30
            readonly property var upd: {
                root.fusionRev
                return root.lastUpdate[sensorKey]
            }
            readonly property real fresh: fusionPanel.freshness(sensorKey)

            Rectangle {
                width: 10; height: 10; radius: 5
                y: 2
                color: parent.live ? parent.swatch : LabTheme.muted
                opacity: 0.45 + 0.55 * parent.fresh
            }
            Text {
                x: 18; y: 0
                text: parent.label
                color: LabTheme.inkSoft; font.pixelSize: 11
                font.family: LabTheme.monoFont
            }
            Text {
                anchors.right: parent.right; y: 0
                text: parent.live && parent.upd
                      ? "\u00b1" + LabLang.num(parent.upd.sigma, 1) + " m"
                      : "\u2014"
                color: LabTheme.ink; font.pixelSize: 11; font.bold: true
                font.family: LabTheme.monoFont
            }
            // the gain bar: how far this measurement pulled the estimate
            Rectangle {
                x: 18; y: 17
                width: parent.width - 60; height: 6; radius: 3
                color: LabTheme.paperDeep
                Rectangle {
                    width: parent.width * (parent.parent.live && parent.parent.upd
                                           ? parent.parent.upd.gain : 0)
                    height: parent.height; radius: 3
                    color: parent.parent.swatch
                    Behavior on width { NumberAnimation { duration: 180 } }
                }
            }
            Text {
                anchors.right: parent.right; y: 15
                text: parent.live && parent.upd
                      ? "K " + LabLang.num(parent.upd.gain, 2) : ""
                color: LabTheme.inkFaint; font.pixelSize: 10
                font.family: LabTheme.monoFont
            }
        }

        Sensor {
            sensorKey: "gps"; swatch: LabTheme.rose; label: LabLang.t("sensor.gps")
            live: gps.available
        }
        Sensor {
            sensorKey: "lidar"; swatch: LabTheme.teal; label: LabLang.t("sensor.lidar")
            live: lidar.available
        }

        Rectangle { width: fusionPanel.body.width; height: 1; color: LabTheme.panelEdge }

        Row {
            spacing: 6
            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: LabTheme.secondary
            }
            Text {
                text: LabLang.t("sensor.fused") + "  \u00b1"
                      + LabLang.num(Math.hypot(kf.sigmaX, kf.sigmaY) / Math.SQRT2, 1) + " m"
                color: LabTheme.ink; font.pixelSize: 11; font.bold: true
                font.family: LabTheme.monoFont
            }
        }
        Text {
            width: fusionPanel.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("fusion.law")
            color: LabTheme.inkFaint; font.pixelSize: 11
            font.family: LabTheme.handFont
        }
    }

    LidarMonitor {
        id: monitor
        carPose: root.carPose
        lidar: lidar
        visible: root.showMonitor
        anchors.right: parent.right; anchors.bottom: plot.top; anchors.margins: 10
    }

    // --- presets, orientation, the offer to be taught ---------------------
    // Presets are the best teaching material this lab has, so they are
    // clickable and each carries the one line saying why it exists.
    LabPanel {
        id: presets
        anchors.left: parent.left
        anchors.top: fusionPanel.bottom
        anchors.leftMargin: 10; anchors.topMargin: 10
        width: 258
        title: LabLang.t("lab.title")

        ScenarioBar { lab: root; width: presets.body.width }
        FlowChip { flow: fusionFlow }
    }

    Compass {
        id: compass
        anchors.left: parent.left
        anchors.top: presets.bottom
        anchors.leftMargin: 10; anchors.topMargin: 10
        yaw: orbit.yaw
        aspect: 1.4
    }

    HintBar {
        flow: fusionFlow
        rightGuard: monitor
        text: {
            if (root.tunnelOn && root.carInTunnel) return LabLang.t("hint.tunnel")
            if (!root._lidarOn) return LabLang.t("hint.lidarOut")
            if (!root.followCam) return LabLang.t("hint.free")
            return LabLang.t("hint.idle")
        }
    }

    // A flow for a lab that runs on its own: no parts to place, so the steps
    // set scenarios and knobs, and one of them simply WATCHES until the sim
    // reaches the moment worth explaining. Narration lives in strings.js under
    // flow.<flowId>.<stepKey>, which is what makes it translatable.
    Flow {
        id: fusionFlow
        lab: root
        flowId: "fusion-basics"
        titleKey: "flow.fusion-basics.title"

        FlowStep {
            key: "gps"
            demo: [["scenario", "open-sky"], ["setParam", "gpsSigma", 3], ["followCam", true]]
        }
        FlowStep {
            key: "noisier"
            demo: [["setParam", "gpsSigma", 9]]
        }
        FlowStep {
            key: "odo"
            demo: [["setParam", "gpsSigma", 3]]
        }
        FlowStep { key: "lidar-map"; demo: [["monitor", true]] }
        FlowStep {
            key: "lidar-geometry"
            watch: ({ "until": () => lidar.usedCount <= 2 })
        }
        FlowStep { key: "fusion" }
        FlowStep {
            key: "tunnel"
            demo: [["scenario", "tunnel"], ["simSpeed", 1.0]]
            watch: ({ "until": () => root.carInTunnel })
        }
        FlowStep {
            key: "recover"
            watch: ({ "until": () => !root.carInTunnel })
        }
    }
    Narrator {
        flow: fusionFlow
        anchors.horizontalCenter: parent.horizontalCenter
        // above the error plot, not on top of it: this lab's bottom slot is
        // already taken (exactly the HUD-slot rule from the harvest note)
        anchors.bottom: plot.top
        anchors.bottomMargin: 10
        width: Math.min(680, root.width - 40)
    }

    // --- keys -------------------------------------------------------------
    // The reserved half of the map (presets, flow, view, record, help) is
    // LabKeys'; what is declared here is what this lab adds - and declaring a
    // key here is also what documents it in LabHelp.
    LabKeys {
        id: keymap
        lab: root
        camera: orbit
        flow: fusionFlow
        recorder: recorder
        keys: [
            { key: "C", label: "key.camera", action: () => root.followCam = !root.followCam },
            { key: "M", label: "key.monitor", action: () => root.showMonitor = !root.showMonitor },
            { key: "#", label: "key.grid", action: () => root.showGrid = !root.showGrid },
            { key: "G", label: "key.grid", hidden: true, action: () => root.showGrid = !root.showGrid }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: 320
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        if (ev.key === Qt.Key_Escape) root.followCam = true
    }

    // recording indicator: the one piece of the old status line worth keeping
    Text {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.bottom: plot.top; anchors.bottomMargin: 8
        visible: recorder.recording
        text: "\u25cf REC (" + recorder.rows + ")"
        color: LabTheme.alarm
        font.family: LabTheme.monoFont
        font.pixelSize: 12
    }
}
