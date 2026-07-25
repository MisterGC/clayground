// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

// One circuit part on the pegboard: body by type, two gold terminals at
// x = -/+ termOffset. Purely visual - the Sandbox owns state, hit testing
// and the solver; this node just renders what it is told.
//
// Shading is deliberately flat: toon-shaded boxes with ink edges and fully
// matte round parts, so shapes read by silhouette and value, never by
// glare. Only the emitters (LED dome, bulb filament) are allowed to be
// bright.
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
    property bool selected: false
    property int wiringTerminal: -1  // terminal glowing during wiring, -1 none

    readonly property real termOffset: 3.5

    // flat, glare-free body material for the round parts
    component Matte: PrincipledMaterial {
        roughness: 1.0
        metalness: 0.0
        specularAmount: 0.0
    }
    // toon-shaded box with darkened ink edges
    component Part: Box3D {
        useToonShading: true
        edgeColorFactor: 0.55
    }
    // constant-color marker (2D-style UI drawn inside the 3D scene)
    component Marker: Model {
        property color tint: LabTheme.secondary
        source: "#Cube"
        materials: PrincipledMaterial {
            baseColor: tint
            lighting: PrincipledMaterial.NoLighting
        }
    }

    // --- hover / selection frame --------------------------------------------
    // One shape, two strengths: hovering draws a thin quiet outline, selecting
    // draws the full one plus a nose mark. Same language as the terminals,
    // which light up on hover and go blue while wiring.
    Node {
        id: frame
        visible: root.selected || root.hovered
        y: 0.14
        // hover and selection speak the same blue as the terminals do; the
        // weight (and the nose mark) is what tells them apart
        readonly property color tone: LabTheme.secondary
        readonly property real bar: root.selected ? 0.38 : 0.22
        opacity: root.selected ? 1.0 : 0.55
        Repeater3D {
            model: [{ x: 0, z: -3.9, along: true },
                    { x: 0, z: 3.9, along: true },
                    { x: -5.2, z: 0, along: false },
                    { x: 5.2, z: 0, along: false }]
            Marker {
                tint: frame.tone
                position: Qt.vector3d(modelData.x, 0, modelData.z)
                scale: modelData.along
                    ? Qt.vector3d(0.104, 0.0014, frame.bar / 100)
                    : Qt.vector3d(frame.bar / 100, 0.0014, 0.082)
            }
        }
        Marker {  // nose mark: shows which way the part faces after a rotation
            visible: root.selected
            tint: LabTheme.accent
            position: Qt.vector3d(6.2, 0, 0)
            scale: Qt.vector3d(0.013, 0.0014, 0.013)
            eulerRotation.y: 45
        }
    }

    // --- terminals ----------------------------------------------------------
    Repeater3D {
        model: 2
        Model {
            source: "#Sphere"
            position: Qt.vector3d(index === 0 ? -root.termOffset : root.termOffset, 0.9, 0)
            scale: Qt.vector3d(0.02, 0.02, 0.02)
            materials: Matte {
                baseColor: root.wiringTerminal === index ? LabTheme.secondary : LabTheme.highlight
                emissiveFactor: root.wiringTerminal === index
                                ? Qt.vector3d(0, 0.3, 0.6) : Qt.vector3d(0, 0, 0)
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
            materials: Matte { baseColor: "#9a8a5a" }
        }
    }

    // --- battery ------------------------------------------------------------
    Node {
        visible: root.type === "battery"
        Part {
            width: 5.2; height: 3.6; depth: 3.6
            position: Qt.vector3d(0, 1.8, 0)
            color: root.shorted ? "#b04434" : LabTheme.teal
            SequentialAnimation on opacity {
                running: root.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 240 }
                NumberAnimation { to: 1.0; duration: 240 }
            }
        }
        Part {  // + cap
            width: 0.8; height: 1.0; depth: 1.6
            position: Qt.vector3d(-2.9, 2.0, 0); color: LabTheme.highlight
        }
        Part {  // + glyph above the anode cap
            width: 1.3; height: 0.3; depth: 0.3
            position: Qt.vector3d(-2.4, 4.1, 0); color: LabTheme.ink
        }
        Part {
            width: 0.3; height: 0.3; depth: 1.3
            position: Qt.vector3d(-2.4, 4.1, 0); color: LabTheme.ink
        }
        Part {  // - glyph
            width: 1.3; height: 0.3; depth: 0.3
            position: Qt.vector3d(2.4, 4.1, 0); color: LabTheme.panel
        }
    }

    // --- resistor -----------------------------------------------------------
    Node {
        id: _res
        visible: root.type === "resistor"
        Part {
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
            Part {
                width: 0.45; height: 1.95; depth: 1.95
                position: Qt.vector3d(-1.0 + index * 1.0, 1.0, 0)
                color: _res.bands[index]
                showEdges: false
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
                materials: Matte { baseColor: LabTheme.muted }
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
            materials: Matte {
                baseColor: root.lit ? "#e05a40" : "#9a5244"
                emissiveFactor: Qt.vector3d(2.2, 0.55, 0.35).times(_led.glow)
            }
        }
        Model {  // socket
            source: "#Cylinder"
            position: Qt.vector3d(0, 0.7, 0)
            scale: Qt.vector3d(0.026, 0.014, 0.026)
            materials: Matte { baseColor: "#6b655c" }
        }
        Part {  // anode marker: gold foot toward terminal 0
            width: 1.6; height: 0.3; depth: 0.7
            position: Qt.vector3d(-1.4, 0.5, 0); color: LabTheme.highlight
        }
        PointLight {
            visible: root.lit
            position: Qt.vector3d(0, 3.2, 0)
            color: "#e8785e"
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
            materials: Matte {
                baseColor: "#e7e4da"
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
            materials: Matte { baseColor: "#8a95a1" }
        }
        PointLight {
            visible: root.lit
            position: Qt.vector3d(0, 3.8, 0)
            color: "#e8cf8a"
            brightness: 2.2 * _bulb.glow
            quadraticFade: 0.015
        }
    }

    // --- switch -------------------------------------------------------------
    Node {
        visible: root.type === "switch"
        Part {
            width: 4.6; height: 1.3; depth: 3.0
            position: Qt.vector3d(0, 0.7, 0)
            color: "#8a8378"
        }
        Node {  // lever pivots at the left contact
            position: Qt.vector3d(-1.6, 1.6, 0)
            Part {
                width: 3.4; height: 0.65; depth: 1.5
                position: Qt.vector3d(1.6, 0, 0)
                color: root.switchOn ? LabTheme.forest : LabTheme.clay
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
                materials: Matte { baseColor: LabTheme.highlight }
            }
        }
    }

    // --- meters (ammeter forest ring, voltmeter plum ring) -------------------
    Node {
        id: _meter
        visible: root.type === "ammeter" || root.type === "voltmeter"
        readonly property color ring: root.type === "ammeter" ? LabTheme.forest : LabTheme.plum
        Model {  // face
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.2, 0)
            scale: Qt.vector3d(0.05, 0.014, 0.05)
            materials: Matte { baseColor: LabTheme.panel }
        }
        Model {  // ring
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.05, 0)
            scale: Qt.vector3d(0.058, 0.012, 0.058)
            materials: Matte { baseColor: _meter.ring }
        }
    }
}
