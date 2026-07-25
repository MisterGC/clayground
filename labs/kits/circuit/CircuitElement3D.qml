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
    property bool shorted: false     // battery terminals effectively bridged
    property bool overloaded: false  // heavy but honest load
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
        readonly property real hw: root.type === "junction" ? 2.0 : 5.2
        readonly property real hd: root.type === "junction" ? 2.0 : 3.9
        opacity: root.selected ? 1.0 : 0.55
        Repeater3D {
            model: [{ along: true, s: -1 }, { along: true, s: 1 },
                    { along: false, s: -1 }, { along: false, s: 1 }]
            Marker {
                tint: frame.tone
                position: modelData.along ? Qt.vector3d(0, 0, modelData.s * frame.hd)
                                          : Qt.vector3d(modelData.s * frame.hw, 0, 0)
                scale: modelData.along
                    ? Qt.vector3d((frame.hw * 2) / 100, 0.0014, frame.bar / 100)
                    : Qt.vector3d(frame.bar / 100, 0.0014, (frame.hd * 2) / 100)
            }
        }
        Marker {  // nose mark: shows which way the part faces after a rotation
            visible: root.selected && root.type !== "junction"
            tint: LabTheme.accent
            position: Qt.vector3d(6.2, 0, 0)
            scale: Qt.vector3d(0.013, 0.0014, 0.013)
            eulerRotation.y: 45
        }
    }

    // --- junction: a solder dot where wires meet ----------------------------
    Model {
        visible: root.type === "junction"
        source: "#Sphere"
        position: Qt.vector3d(0, 0.5, 0)
        scale: Qt.vector3d(0.02, 0.013, 0.02)
        materials: Matte {
            baseColor: root.wiringTerminal >= 0 ? LabTheme.secondary : LabTheme.ink
            emissiveFactor: root.wiringTerminal >= 0
                            ? Qt.vector3d(0, 0.3, 0.6) : Qt.vector3d(0, 0, 0)
        }
    }

    // --- terminals ----------------------------------------------------------
    // Contact pads sunk into the board rather than balls on posts: the wires
    // lie flat on the paper, so they have to meet the terminals at board
    // level. A low dome still catches the light and reads as a solder blob.
    Repeater3D {
        model: 2
        Model {
            visible: root.type !== "junction"   // the dot is its own pad
            source: "#Sphere"
            position: Qt.vector3d(index === 0 ? -root.termOffset : root.termOffset, 0.62, 0)
            scale: Qt.vector3d(0.022, 0.012, 0.022)
            materials: Matte {
                baseColor: root.wiringTerminal === index ? LabTheme.secondary : LabTheme.highlight
                emissiveFactor: root.wiringTerminal === index
                                ? Qt.vector3d(0, 0.3, 0.6) : Qt.vector3d(0, 0, 0)
            }
        }
    }

    // --- battery ------------------------------------------------------------
    Node {
        visible: root.type === "battery"
        Part {
            width: 5.2; height: 3.6; depth: 3.6
            position: Qt.vector3d(0, 0, 0)
            color: root.shorted ? "#b04434"
                 : root.overloaded ? LabTheme.highlight : LabTheme.teal
            SequentialAnimation on opacity {
                running: root.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 240 }
                NumberAnimation { to: 1.0; duration: 240 }
            }
        }
        Part {  // + cap
            width: 0.8; height: 1.0; depth: 1.6
            position: Qt.vector3d(-2.9, 1.5, 0); color: LabTheme.highlight
        }
        // One printed label instead of three little 3D glyphs: it carries the
        // voltage and the polarity, and both point at the pad they belong to.
        Model {
            // sunk into the cell so only the printed face shows: a cube maps
            // the same texture onto its sides, which would read as a smear
            position: Qt.vector3d(0, 3.45, 0)
            source: "#Cube"
            scale: Qt.vector3d(0.046, 0.004, 0.03)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    flipU: true
                    flipV: true
                    sourceItem: Item {
                        width: 300; height: 190
                        Rectangle { anchors.fill: parent; color: LabTheme.panel }
                        Text {
                            x: 26; anchors.verticalCenter: parent.verticalCenter
                            text: "+"; color: LabTheme.clay
                            font.pixelSize: 58; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 30
                            anchors.verticalCenter: parent.verticalCenter
                            text: "–"; color: LabTheme.ink
                            font.pixelSize: 58; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.num(root.value, 1) + " V"
                            color: LabTheme.ink
                            font.pixelSize: 52; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- resistor -----------------------------------------------------------
    Node {
        id: _res
        visible: root.type === "resistor"
        Part {
            width: 4.4; height: 1.9; depth: 1.9
            position: Qt.vector3d(0, 0.05, 0); color: "#d9c9a0"
        }
        // The real resistor colour code, not a lookup of four presets: two
        // significant digits plus a decade multiplier, so the bands change
        // with the value the way a bought resistor's do.
        readonly property var codeColors: ["#1a1a1a", "#7a4a21", "#c0392b", "#d35400",
                                           "#f1c40f", "#27ae60", "#2b6cb0", "#7d3c98",
                                           "#7f8c8d", "#ecf0f1"]
        readonly property var bands: {
            // normalized by division, not by log10: log10(1000) lands just
            // under 3 in floating point and would mis-colour the decade
            let sig = Math.round(Math.max(10, root.value || 470))
            let exp = 0
            while (sig >= 100) { sig = Math.round(sig / 10); ++exp }
            return [codeColors[Math.floor(sig / 10)],
                    codeColors[sig % 10],
                    codeColors[Math.min(9, exp)]]
        }
        Repeater3D {
            model: 3
            Part {
                width: 0.45; height: 1.95; depth: 1.95
                position: Qt.vector3d(-1.0 + index * 1.0, 0.02, 0)
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
            position: Qt.vector3d(-1.4, 0.35, 0); color: LabTheme.highlight
        }
        PointLight {  // a pool of light on the paper, not room lighting
            visible: root.lit
            position: Qt.vector3d(0, 3.2, 0)
            color: "#e8785e"
            brightness: 1.5 * _led.glow
            constantFade: 1.0
            linearFade: 0.2
            quadraticFade: 0.9
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
        PointLight {  // bright bulbs must not wash the whole board yellow
            visible: root.lit
            position: Qt.vector3d(0, 3.8, 0)
            color: "#e8cf8a"
            brightness: 1.6 * _bulb.glow
            constantFade: 1.0
            linearFade: 0.25
            quadraticFade: 1.2
        }
    }

    // --- switch -------------------------------------------------------------
    Node {
        visible: root.type === "switch"
        Part {
            width: 4.6; height: 1.3; depth: 3.0
            position: Qt.vector3d(0, 0.05, 0)
            color: "#8a8378"
        }
        Node {  // lever pivots at the left contact
            position: Qt.vector3d(-1.6, 1.6, 0)
            Part {
                width: 3.4; height: 0.65; depth: 1.5
                position: Qt.vector3d(1.6, -0.32, 0)
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
        Model {  // printed state: a lever is hard to read from straight above
            // on top of the case (its top face is at y 1.35) and in front of
            // the lever, otherwise the print is swallowed by the body
            // a plane, not a box: #Cube maps the same texture onto every face,
            // so a raised plate would repeat the print down its sides
            position: Qt.vector3d(0, 1.37, 1.05)
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.026, 0.008, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    // a plane needs no flips - unlike a cube's up face, which
                    // maps U and V mirrored
                    sourceItem: Item {
                        width: 200; height: 92
                        Rectangle { anchors.fill: parent; color: LabTheme.panel }
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.t(root.switchOn ? "switch.on" : "switch.off")
                            color: root.switchOn ? LabTheme.forest : LabTheme.clay
                            font.pixelSize: 60; font.bold: true
                            font.letterSpacing: 4
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- meters: a real dial, printed onto the part -------------------------
    // The face is a Qt Quick item rendered to a texture, so the instrument
    // shows what it measures the way an instrument does: a scale, a range and
    // a needle that swings. It also makes an ammeter unmistakably an ammeter
    // from across the board, which a coloured ring never did.
    Node {
        id: _meter
        visible: root.type === "ammeter" || root.type === "voltmeter"
        readonly property bool isAmp: root.type === "ammeter"
        readonly property color ring: isAmp ? LabTheme.forest : LabTheme.plum
        readonly property real reading: Math.abs(isAmp ? root.simI : root.simV)
        // instruments have ranges: pick the smallest that still fits
        readonly property real fullScale: {
            const scales = isAmp ? [0.01, 0.1, 1, 10] : [1, 5, 12, 60]
            for (const s of scales) if (reading <= s) return s
            return scales[scales.length - 1]
        }
        readonly property string rangeLabel: isAmp
            ? (fullScale < 1 ? (fullScale * 1000) + " mA" : fullScale + " A")
            : fullScale + " V"

        Part {  // case (Box3D sits on its y: bottom-centre origin)
            width: 7.0; height: 1.4; depth: 5.6
            position: Qt.vector3d(0, 0, 0)
            color: _meter.ring
        }
        Model {  // dial plate on top: its up face carries the rendered face
            source: "#Cube"
            position: Qt.vector3d(0, 1.55, 0)
            scale: Qt.vector3d(0.062, 0.004, 0.048)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting   // keep the print crisp
                baseColorMap: Texture {
                    // the cube's up face maps U mirrored: flip both so the
                    // print reads the right way round
                    flipU: true
                    flipV: true
                    sourceItem: Item {
                        width: 260; height: 200
                        Rectangle {
                            anchors.fill: parent
                            color: LabTheme.panel
                        }
                        Text {  // what it measures
                            x: 14; y: 10
                            text: _meter.isAmp ? "A" : "V"
                            color: _meter.ring
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {  // the range this dial is showing
                            anchors.right: parent.right; anchors.rightMargin: 14
                            y: 22
                            text: "0 – " + _meter.rangeLabel
                            color: LabTheme.inkFaint
                            font.pixelSize: 22
                            font.family: LabTheme.monoFont
                        }
                        Item {  // needle pivot, bottom centre
                            x: 130; y: 176
                            Repeater {
                                model: 11
                                Item {
                                    transformOrigin: Item.TopLeft
                                    rotation: -75 + index * 15
                                    Rectangle {
                                        x: -2; y: -128
                                        width: 4; height: index % 5 === 0 ? 22 : 12
                                        color: index % 5 === 0 ? LabTheme.ink : LabTheme.inkFaint
                                    }
                                }
                            }
                            Item {
                                transformOrigin: Item.TopLeft
                                rotation: -75 + 150 * Math.max(0, Math.min(1,
                                              _meter.reading / _meter.fullScale))
                                Behavior on rotation { NumberAnimation { duration: 260 } }
                                Rectangle {
                                    x: -3; y: -122; width: 6; height: 122; radius: 3
                                    color: LabTheme.clay
                                }
                            }
                            Rectangle {
                                x: -11; y: -11; width: 22; height: 22; radius: 11
                                color: LabTheme.ink
                            }
                        }
                    }
                }
            }
        }
    }
}
