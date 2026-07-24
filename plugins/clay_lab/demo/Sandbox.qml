// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// Kernel smoke demo: a damped oscillator driven purely by SimClock time,
// exercising Parameter/Probe/ParamPanel/Plot2D without any physics deps.
Rectangle {
    id: sandbox
    anchors.fill: parent
    color: "#0a0f14"

    Parameter { id: pFreq; name: "frequency"; value: 0.5; from: 0.05; to: 3; unit: "Hz" }
    Parameter { id: pAmp; name: "amplitude"; value: 1; from: 0; to: 2 }
    Parameter { id: pDamp; name: "damping"; value: 0.08; from: 0; to: 1 }

    SimClock { id: clock; seed: 42; sampleInterval: 0.05 }

    property real envelope: pAmp.value * Math.exp(-pDamp.value * clock.time)
    property real oscY: envelope * Math.sin(2 * Math.PI * pFreq.value * clock.time)

    Probe { name: "y"; expr: () => sandbox.oscY }
    Probe { name: "envelope"; expr: () => sandbox.envelope }

    Rectangle {
        width: 26; height: 26; radius: 13
        color: "#00d9ff"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.4 - sandbox.oscY * parent.height * 0.18 - height / 2
    }

    ScenarioSet {
        id: scenarioSet
        Scenario { name: "restart"; description: "reset time and samples"; script: () => {} }
        Scenario {
            name: "hard-damped"; description: "strong damping preset"
            script: () => { Lab.set("damping", 0.6); Lab.set("frequency", 1.5) }
        }
    }
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { scenarioSet.apply(n) }
    function flagInfo() { return Lab.labInfo() }

    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    Plot2D {
        anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 10
        height: 150
        probes: ["y", "envelope"]
    }
}
