// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Physics
import Clayground.World
import Clayground.Lab

// Physics Playground — the P1 reference lab: rigid-body boxes under
// tunable gravity/restitution/friction, energy and settling probes,
// three seeded scenarios. Keys: 1 tower · 2 rain · 3 drop · R record.
ClayWorld2d {
    id: theWorld

    anchors.fill: parent
    xWuMin: 0; xWuMax: 32
    yWuMin: 0; yWuMax: 18
    pixelPerUnit: height / theWorld.yWuMax
    gravity: Qt.point(0, pGravity.value)
    components: new Map()
    loadMapAsync: false
    focus: true

    // --- parameters -----------------------------------------------------
    Parameter { id: pGravity; name: "gravity"; value: 9.81; from: 0; to: 30; unit: "m/s²" }
    Parameter { id: pRestitution; name: "restitution"; value: 0.3; from: 0; to: 1 }
    Parameter { id: pFriction; name: "friction"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pCount; name: "boxCount"; value: 24; from: 4; to: 60; stepSize: 1 }

    SimClock { id: clock; seed: 42; world: theWorld }

    // --- static geometry ------------------------------------------------
    RectBoxBody { xWu: 0; yWu: 1; widthWu: 32; heightWu: 1; bodyType: Body.Static
                  color: "#1b2631"; friction: 1 }
    RectBoxBody { xWu: 0; yWu: 18; widthWu: 0.5; heightWu: 17; bodyType: Body.Static
                  color: "#1b2631" }
    RectBoxBody { xWu: 31.5; yWu: 18; widthWu: 0.5; heightWu: 17; bodyType: Body.Static
                  color: "#1b2631" }

    // --- boxes (spawned by scenarios only, all randomness via clock) ----
    property var boxes: []
    readonly property var _palette: ["#00d9ff", "#ff3366", "#ffd93d", "#0f9d9a"]

    Component {
        id: boxComp
        RectBoxBody {
            bodyType: Body.Dynamic
            widthWu: 0.8; heightWu: 0.8
            density: 1
            restitution: pRestitution.value
            friction: pFriction.value
            border.color: Qt.darker(color, 1.4); border.width: 2
        }
    }

    function clearBoxes() {
        for (const b of boxes) b.destroy()
        boxes = []
    }

    function spawnBox(x, y) {
        const b = boxComp.createObject(theWorld,
            {xWu: x, yWu: y, color: _palette[boxes.length % _palette.length]})
        boxes.push(b)
        return b
    }

    // --- probes ---------------------------------------------------------
    Probe {
        name: "kineticEnergy"; unit: "J"
        expr: () => {
            let e = 0
            for (const b of theWorld.boxes) {
                const m = b.density * b.widthWu * b.heightWu
                const v = b.linearVelocity
                e += 0.5 * m * (v.x * v.x + v.y * v.y)
            }
            return e
        }
    }
    Probe {
        name: "avgHeight"; unit: "wu"
        expr: () => {
            if (theWorld.boxes.length === 0) return 0
            let h = 0
            for (const b of theWorld.boxes) h += Math.max(0, b.yWu - 1)
            return h / theWorld.boxes.length
        }
    }
    Probe {
        name: "moving"
        expr: () => {
            let n = 0
            for (const b of theWorld.boxes) {
                const v = b.linearVelocity
                if (v.x * v.x + v.y * v.y > 0.0025) n++
            }
            return n
        }
    }

    // --- scenarios ------------------------------------------------------
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "tower"
            description: "two adjacent towers with seeded jitter, collapse study"
            script: () => {
                theWorld.clearBoxes()
                const n = Math.round(pCount.value)
                for (let i = 0; i < n; ++i) {
                    const col = i % 2
                    const row = Math.floor(i / 2)
                    theWorld.spawnBox(15.1 + col * 0.9 + clock.randomRange(-0.06, 0.06),
                                      2.1 + row * 0.85)
                }
            }
        }
        Scenario {
            name: "rain"
            description: "boxes rain down from seeded positions"
            script: () => {
                theWorld.clearBoxes()
                const n = Math.round(pCount.value)
                for (let i = 0; i < n; ++i)
                    theWorld.spawnBox(clock.randomRange(1.5, 29.5),
                                      12 + clock.randomRange(0, 5))
            }
        }
        Scenario {
            name: "drop"
            description: "single box drop, restitution study"
            script: () => {
                theWorld.clearBoxes()
                theWorld.spawnBox(15.6, 16)
            }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    function labInfo() {
        const info = Lab.labInfo()
        info.boxCount = boxes.length
        return info
    }
    function flagInfo() { return labInfo() }

    // View-state for the dojo reload convention. The clock is world-driven
    // (Box2D), so sim time cannot be re-stepped synchronously - on reload the
    // captured scenario simply restarts with the user's parameter values.
    function viewState() {
        return Object.assign(Lab.viewState(), { recording: recorder.recording })
    }
    function applyViewState(s) {
        if (s.scenario) applyScenario(s.scenario)
        recorder.recording = !!s.recording
        Lab.applyViewState(s)
    }

    Component.onCompleted: applyScenario("tower")

    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_1) applyScenario("tower")
        else if (ev.key === Qt.Key_2) applyScenario("rain")
        else if (ev.key === Qt.Key_3) applyScenario("drop")
        else if (ev.key === Qt.Key_R) recorder.recording = !recorder.recording
    }

    DataRecorder { id: recorder; destination: "physics-playground-run.csv" }

    // --- lab UI ---------------------------------------------------------
    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    Plot2D {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 10
        height: 150
        probes: ["kineticEnergy", "avgHeight"]
    }
    Text {
        x: 10; y: 6
        text: "PHYSICS PLAYGROUND — 1 tower · 2 rain · 3 drop · R record"
              + (recorder.recording ? "  ● REC (" + recorder.rows + ")" : "")
        color: recorder.recording ? "#ff3366" : "#889099"
        font.pixelSize: 12
    }
}
