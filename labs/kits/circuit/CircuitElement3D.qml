// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

// One circuit part on the pegboard: body by type, two gold terminals at
// x = -/+ termOffset. Purely visual - the Sandbox owns state, hit testing
// and the solver; this node just renders what it is told.
Node {
    id: root

    property string type: "resistor"
    property real value: 470
    property bool switchOn: false    // switch lever state
    property real simI: 0            // amps through the part
    property real simV: 0            // volts across the part
    property bool lit: false         // led/bulb emitting
    property real simPower: 0        // watts dissipated
    property bool shorted: false     // battery over-current
    property bool hovered: false
    property int wiringTerminal: -1  // terminal glowing during wiring, -1 none

    readonly property real termOffset: 3.5

    // --- hover ring ---------------------------------------------------------
    Model {
        source: "#Cylinder"
        position: Qt.vector3d(0, -0.9, 0)
        scale: Qt.vector3d(0.11, 0.006, 0.09)
        visible: root.hovered
        materials: PrincipledMaterial {
            baseColor: "#00d9ff"; emissiveFactor: Qt.vector3d(0, 0.5, 0.6)
            lighting: PrincipledMaterial.NoLighting
        }
    }

    // --- terminals ----------------------------------------------------------
    Repeater3D {
        model: 2
        Model {
            source: "#Sphere"
            position: Qt.vector3d(index === 0 ? -root.termOffset : root.termOffset, 0.9, 0)
            scale: Qt.vector3d(0.02, 0.02, 0.02)
            materials: PrincipledMaterial {
                baseColor: root.wiringTerminal === index ? "#00d9ff" : "#ffd93d"
                emissiveFactor: root.wiringTerminal === index
                                ? Qt.vector3d(0, 0.9, 1.1) : Qt.vector3d(0.25, 0.2, 0)
                roughness: 0.35
            }
        }
    }
    // terminal posts down to the board
    Repeater3D {
        model: 2
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(index === 0 ? -root.termOffset : root.termOffset, 0.4, 0)
            scale: Qt.vector3d(0.008, 0.011, 0.008)
            materials: PrincipledMaterial { baseColor: "#8a7326"; roughness: 0.5 }
        }
    }

    // --- battery ------------------------------------------------------------
    Node {
        visible: root.type === "battery"
        Box3D {
            width: 5.2; height: 3.6; depth: 3.6
            position: Qt.vector3d(0, 1.8, 0)
            color: root.shorted ? "#a02020" : "#0f9d9a"
            SequentialAnimation on opacity {
                running: root.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 240 }
                NumberAnimation { to: 1.0; duration: 240 }
            }
        }
        Box3D {  // + cap
            width: 0.8; height: 1.0; depth: 1.6
            position: Qt.vector3d(-2.9, 2.0, 0); color: "#ffd93d"
        }
        Box3D {  // + glyph above the anode cap
            width: 1.3; height: 0.3; depth: 0.3
            position: Qt.vector3d(-2.4, 4.1, 0); color: "#ffd93d"
        }
        Box3D {
            width: 0.3; height: 0.3; depth: 1.3
            position: Qt.vector3d(-2.4, 4.1, 0); color: "#ffd93d"
        }
        Box3D {  // - glyph
            width: 1.3; height: 0.3; depth: 0.3
            position: Qt.vector3d(2.4, 4.1, 0); color: "#dfe7ee"
        }
    }

    // --- resistor -----------------------------------------------------------
    Node {
        id: _res
        visible: root.type === "resistor"
        Box3D {
            width: 4.4; height: 1.9; depth: 1.9
            position: Qt.vector3d(0, 1.0, 0); color: "#d9c9a0"
        }
        // color bands encode the value (100 220 470 1000)
        readonly property var bands: {
            if (root.value <= 100) return ["#7a4a21", "#1a1a1a", "#7a4a21"]
            if (root.value <= 220) return ["#c0392b", "#c0392b", "#7a4a21"]
            if (root.value <= 470) return ["#ffd93d", "#7d3c98", "#7a4a21"]
            return ["#7a4a21", "#1a1a1a", "#c0392b"]
        }
        Repeater3D {
            model: 3
            Box3D {
                width: 0.45; height: 1.95; depth: 1.95
                position: Qt.vector3d(-1.0 + index * 1.0, 1.0, 0)
                color: _res.bands[index]
            }
        }
        // lead wires to the terminals
        Repeater3D {
            model: 2
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -2.8 : 2.8, 1.0, 0)
                eulerRotation.z: 90
                scale: Qt.vector3d(0.003, 0.014, 0.003)
                materials: PrincipledMaterial { baseColor: "#9aa2ab"; roughness: 0.4 }
            }
        }
    }

    // --- LED (terminal 0 = anode, marked gold) ------------------------------
    Node {
        id: _led
        visible: root.type === "led"
        // brightness from current: 20 mA is a bright hobby LED
        readonly property real glow: Math.min(1.5, Math.max(0, root.simI / 0.02))
        Model {  // dome
            source: "#Sphere"
            position: Qt.vector3d(0, 2.4, 0)
            scale: Qt.vector3d(0.034, 0.034, 0.034)
            materials: PrincipledMaterial {
                baseColor: root.lit ? "#ff5a4a" : "#a03a30"
                emissiveFactor: Qt.vector3d(2.2, 0.55, 0.35).times(_led.glow)
                roughness: 0.25
            }
        }
        Model {  // socket
            source: "#Cylinder"
            position: Qt.vector3d(0, 0.7, 0)
            scale: Qt.vector3d(0.026, 0.014, 0.026)
            materials: PrincipledMaterial { baseColor: "#3c4650"; roughness: 0.6 }
        }
        Box3D {  // anode marker: gold foot toward terminal 0
            width: 1.6; height: 0.3; depth: 0.7
            position: Qt.vector3d(-1.4, 0.5, 0); color: "#ffd93d"
        }
        PointLight {
            visible: root.lit
            position: Qt.vector3d(0, 3.2, 0)
            color: "#ff6a55"
            brightness: 1.6 * _led.glow
            quadraticFade: 0.02
        }
    }

    // --- bulb ---------------------------------------------------------------
    Node {
        id: _bulb
        visible: root.type === "bulb"
        // 0.8 W lights it fully (4.5 V school bulb)
        readonly property real glow: Math.min(1.4, root.simPower / 0.8)
        Model {  // glass
            source: "#Sphere"
            position: Qt.vector3d(0, 3.0, 0)
            scale: Qt.vector3d(0.042, 0.042, 0.042)
            opacity: 0.42
            materials: PrincipledMaterial {
                baseColor: "#cfe4ee"; roughness: 0.05
                alphaMode: PrincipledMaterial.Blend
            }
        }
        Model {  // filament
            source: "#Sphere"
            position: Qt.vector3d(0, 3.0, 0)
            scale: Qt.vector3d(0.017, 0.017, 0.017)
            materials: PrincipledMaterial {
                baseColor: root.lit ? "#ffe9a8" : "#5a5148"
                emissiveFactor: Qt.vector3d(2.4, 1.9, 0.9).times(_bulb.glow)
                lighting: PrincipledMaterial.NoLighting
            }
        }
        Model {  // socket
            source: "#Cylinder"
            position: Qt.vector3d(0, 0.8, 0)
            scale: Qt.vector3d(0.022, 0.016, 0.022)
            materials: PrincipledMaterial { baseColor: "#8a95a1"; roughness: 0.35; metalness: 0.6 }
        }
        PointLight {
            visible: root.lit
            position: Qt.vector3d(0, 3.8, 0)
            color: "#ffd98c"
            brightness: 2.2 * _bulb.glow
            quadraticFade: 0.015
        }
    }

    // --- switch -------------------------------------------------------------
    Node {
        visible: root.type === "switch"
        Box3D {
            width: 4.6; height: 1.3; depth: 3.0
            position: Qt.vector3d(0, 0.7, 0)
            color: "#2b3642"
        }
        Node {  // lever pivots at the left contact
            position: Qt.vector3d(-1.6, 1.6, 0)
            Box3D {
                width: 3.4; height: 0.5; depth: 1.1
                position: Qt.vector3d(1.6, 0, 0)
                color: root.switchOn ? "#3fbf6f" : "#c74a52"
            }
            eulerRotation.z: root.switchOn ? 0 : 28
            Behavior on eulerRotation.z { NumberAnimation { duration: 120 } }
        }
        Repeater3D {  // contact studs
            model: 2
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -1.6 : 1.6, 1.65, 0)
                scale: Qt.vector3d(0.009, 0.005, 0.009)
                materials: PrincipledMaterial { baseColor: "#ffd93d"; roughness: 0.3 }
            }
        }
    }

    // --- meters (ammeter teal ring, voltmeter pink ring) ---------------------
    Node {
        id: _meter
        visible: root.type === "ammeter" || root.type === "voltmeter"
        readonly property color ring: root.type === "ammeter" ? "#0f9d9a" : "#ff3366"
        Model {  // face
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.2, 0)
            scale: Qt.vector3d(0.05, 0.014, 0.05)
            materials: PrincipledMaterial { baseColor: "#e8eef2"; roughness: 0.55 }
        }
        Model {  // ring
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.05, 0)
            scale: Qt.vector3d(0.058, 0.012, 0.058)
            materials: PrincipledMaterial { baseColor: _meter.ring; roughness: 0.5 }
        }
    }
}
