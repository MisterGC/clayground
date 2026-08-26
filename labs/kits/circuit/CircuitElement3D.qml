// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

// One circuit part on the pegboard: body by type, gold terminals at
// x = -/+ termOffset (and, for a transistor, one more on the near side).
// Purely visual - the Sandbox owns state, hit testing and the solver; this
// node just renders what it is told.
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
    property string mode: ""         // transistor region: off / active / sat
    property string func: "and"      // gate function: and/or/xor/nand/nor/not
    property bool hovered: false
    /*! The cursor is over this part's actuator - its lever, its button, the
        bit you operate. Drawn distinctly from \l hovered, which only says the
        part is under the cursor: a learner asking "can I flip this?" is asking
        about the lever, not the case. */
    property bool actuatorHovered: false
    property bool selected: false
    property int wiringTerminal: -1  // terminal glowing during wiring, -1 none

    readonly property real termOffset: 3.5

    // --- terminals, as geometry ---------------------------------------------
    // Two is the rule, three the exception, and the exception has to be ONE
    // place or the pads, the hit test and the schematic drift apart. The
    // transistor's base sits on the part's near side rather than in line with
    // the other two, so all three pads stay far enough apart to be clicked -
    // and so the silhouette says at a glance which lump has three legs.
    //
    // The gate is the second exception and a different kind of part: a PACKAGE,
    // with two supply pins that are not optional. Its inputs face left and its
    // output right, the way it is read in a diagram, and VCC and GND come out
    // of the two long sides where a DIP's power pins are - so a learner wires
    // the rails across the package rather than through the signal path.
    readonly property int termCount: type === "gate" ? 5
                                   : (type === "transistor" ? 3 : 2)

    function termAt(i) {
        if (root.type === "junction") return Qt.vector3d(0, 0.62, 0)
        if (root.type === "gate") {
            if (i === 0) return Qt.vector3d(0, 0.62, -4.6)     // VCC
            if (i === 1) return Qt.vector3d(-6.0, 0.62, -2.6)  // A
            if (i === 2) return Qt.vector3d(-6.0, 0.62, 2.6)   // B
            if (i === 3) return Qt.vector3d(6.0, 0.62, 0)      // Y
            return Qt.vector3d(0, 0.62, 4.6)                   // GND
        }
        if (root.type === "transistor") {
            if (i === 0) return Qt.vector3d(-root.termOffset, 0.62, 0)   // collector
            if (i === 1) return Qt.vector3d(0, 0.62, root.termOffset)    // base
            return Qt.vector3d(root.termOffset, 0.62, 0)                 // emitter
        }
        return Qt.vector3d(i === 0 ? -root.termOffset : root.termOffset, 0.62, 0)
    }

    // how far the part's own footprint reaches, per axis - a transistor is as
    // deep as it is wide because of that third pad, and a gate is the biggest
    // thing on the board because five pads have to be far enough apart to be
    // clicked without magnifying the board
    readonly property real halfWidth: type === "junction" ? 2.3
                                    : (type === "gate" ? 7.0 : 4.6)
    readonly property real halfDepth: type === "junction" ? 2.3
                                    : (type === "gate" ? 5.6
                                    : (type === "transistor" ? 4.6 : 3.4))

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

    // --- what a ray can hit -------------------------------------------------
    // The one thing in this component View3D.pick can find, and the reason an
    // instrument can be pointed at a part at all: QQuick3DModel::pickable is
    // false by default, so before this every model here was invisible to a
    // ray, and the only surface in the whole lab that did set it -
    // LabStage3D's ground - came back as the answer to every click.
    //
    // One volume rather than a pickable flag on each body, for two measured
    // reasons. A ray hits a model whose parent Node is visible: false just the
    // same as a visible one, so pickable bodies would have given a flat
    // resistor the hit target of the bulb dome it is not showing. And a
    // Model with no material renders nothing at all while still being hit, so
    // this costs a bounds test and no draw call.
    //
    // The footprint is the body box the lab's own cursor test uses (+/-4.6 by
    // +/-3.4, a junction's 2.3), so pointing an instrument at a part and
    // hovering it agree about where the part is.
    Model {
        objectName: "pickVolume"
        source: "#Cube"
        pickable: true
        // #Cube is 100 units, and the box stands from the board up over the
        // tallest body here (the bulb's glass, whose top is at y 4.7). A gate
        // gets its own, lower box: it is by far the widest part and only 1.6
        // tall, and a chest-high block over a flat chip swallows the clicks
        // meant for the board cells behind it.
        readonly property real halfW: root.halfWidth
        readonly property real halfD: root.halfDepth
        readonly property real high: root.type === "junction" ? 1.2
                                   : (root.type === "gate" ? 2.2 : 5.4)
        position: Qt.vector3d(0, high * 0.5, 0)
        scale: Qt.vector3d(halfW * 2 / 100, high / 100, halfD * 2 / 100)
    }

    // --- hover / selection frame --------------------------------------------
    // The kernel's shared hover/select language, which this kit had reproduced
    // bar for bar and mark for mark before it existed. Speaking it from the
    // component rather than from a local copy is what keeps two labs looking
    // like one framework - and it is one fewer place for the weights to drift.
    SelectionFrame3D {
        selected: root.selected
        hovered: root.hovered
        halfWidth: root.type === "junction" ? 2.0
                 : (root.type === "gate" ? 7.6 : 5.2)
        halfDepth: root.type === "junction" ? 2.0
                 : (root.type === "gate" ? 6.2
                 : (root.type === "transistor" ? 5.2 : 3.9))
        // a solder dot has no front, so it gets no facing mark
        showNose: root.type !== "junction"
        // A part is placed slightly SUNK into the pegboard so its shadow hugs
        // it, and the frame's default lift is measured from the part - which
        // put the bars inside the board, where nothing could see them. Enough
        // to clear the surface and no more: the frame has to lie on the board,
        // not hover over it.
        height: 0.62
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
        model: root.termCount
        Model {
            visible: root.type !== "junction"   // the dot is its own pad
            source: "#Sphere"
            position: root.termAt(index)
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

    // --- diode (terminal 0 = anode, silver ring at the cathode) -------------
    // The LED's plain sibling, and drawn as the shop sells it: a small dark
    // glass body lying along the leads with ONE band, at the end the current
    // may not come out of. That band is the whole user interface of a diode,
    // so it is the one detail this body must get right.
    Node {
        visible: root.type === "diode"
        Model {  // glass body
            source: "#Cylinder"
            position: Qt.vector3d(0, 0.95, 0)
            eulerRotation.z: 90
            scale: Qt.vector3d(0.019, 0.034, 0.019)
            materials: Matte { baseColor: "#3a3630" }
        }
        Model {  // cathode band, towards terminal 1
            source: "#Cylinder"
            position: Qt.vector3d(1.25, 0.95, 0)
            eulerRotation.z: 90
            scale: Qt.vector3d(0.0205, 0.006, 0.0205)
            materials: Matte { baseColor: "#cfd3d6" }
        }
        Repeater3D {  // lead wires to the terminals
            model: 2
            Model {
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -2.5 : 2.5, 0.95, 0)
                eulerRotation.z: 90
                scale: Qt.vector3d(0.003, 0.017, 0.003)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }
    }

    // --- transistor (NPN, TO-92: collector, base, emitter) ------------------
    // A real small-signal transistor: a black epoxy blob with a flat face and
    // three legs, standing on a printed footprint that names the pads. The
    // footprint is the point - which leg is which is the one thing a learner
    // cannot deduce from looking at the part, and a kit that does not say it
    // teaches guessing.
    Node {
        id: _npn
        visible: root.type === "transistor"

        // The silkscreen: a printed square lying on the board under the part,
        // C / B / E next to the pads they belong to - the one thing about a
        // transistor a learner cannot deduce by looking at it. Inside the
        // stage's overlay budget, so it lies ON the paper rather than over it.
        //
        // The print is opaque edge to edge on purpose: a rounded or otherwise
        // transparent corner comes out BLACK here, because this material does
        // no alpha blending and there is nothing behind the plate to blend
        // with. Any shaping has to be painted, not cut.
        Model {
            position: Qt.vector3d(0, 0.52, 0)
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.098, 0.098, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    // an Item holding a filled Rectangle, never a Rectangle
                    // used directly as the source
                    sourceItem: Item {
                        width: 240; height: 240
                        // The working sheet's own colour, so only the printed
                        // marks show and the plate reads as ink ON the board
                        // rather than as a tile lying on it. `sheet` and not
                        // the 2D `paper`: this is a 3D surface, and the board
                        // roles are the ones that invert with the room - a
                        // paper-coloured plate came out LIGHTER than the board
                        // it was printed on as soon as the theme went dark.
                        Rectangle { anchors.fill: parent; color: LabTheme.sheet }
                        Rectangle {   // a painted rim, since a cut one goes black
                            anchors.fill: parent
                            anchors.margins: 4
                            color: "transparent"
                            // how far from the sheet, not which way: on a dark
                            // board there is no light left to take away
                            border.color: LabTheme.step(LabTheme.sheet, 1.3)
                            border.width: 3
                        }
                        // Laid out the way the pads are - C left, E right, B on
                        // the near side - but each letter is set BESIDE its pad
                        // rather than on it: a pad is a raised dome, and a
                        // letter directly under one is a letter nobody will
                        // ever see. Pin letters, not words: they read the same
                        // in every language, like the A and V on a meter.
                        Text {
                            x: 13; y: 58
                            text: "C"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 13
                            y: 58
                            text: "E"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            x: 152
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 7
                            text: "B"; color: LabTheme.inkSoft
                            font.pixelSize: 44; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }

        // What region it is working in, as a collar around the foot. A logic
        // gate is unreadable without it: five black blobs all look alike, and
        // "which of these is switched on" is the entire question being asked.
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, 0.60, -0.35)
            scale: Qt.vector3d(0.050, 0.004, 0.050)
            materials: Matte {
                baseColor: root.mode === "sat" ? LabTheme.forest
                         : root.mode === "active" ? LabTheme.highlight
                         : LabTheme.inkFaint
                emissiveFactor: root.mode === "sat" ? Qt.vector3d(0.06, 0.16, 0.08)
                              : root.mode === "active" ? Qt.vector3d(0.16, 0.12, 0.01)
                              : Qt.vector3d(0, 0, 0)
            }
        }

        Model {  // epoxy body
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.55, -0.35)
            scale: Qt.vector3d(0.042, 0.031, 0.042)
            materials: Matte { baseColor: "#2a2724" }
        }
        Model {  // the flat face, on the side the base pad is on
            source: "#Cube"
            position: Qt.vector3d(0, 1.55, 0.85)
            scale: Qt.vector3d(0.038, 0.031, 0.012)
            materials: Matte { baseColor: "#332f2b" }
        }
        Repeater3D {  // three legs, down to the three pads
            model: 3
            Model {
                readonly property var pad: root.termAt(index)
                source: "#Cylinder"
                // half way out from the body, lying flat just above the board
                position: Qt.vector3d(pad.x * 0.5, 0.55, pad.z * 0.5)
                // a #Cylinder stands along Y: tip it onto X for the two side
                // legs, onto Z for the base leg that reaches the near pad
                eulerRotation: index === 1 ? Qt.vector3d(90, 0, 0)
                                           : Qt.vector3d(0, 0, 90)
                scale: Qt.vector3d(0.0032, 0.035, 0.0032)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }
    }

    // --- logic gate (DIP package: VCC, A, B, Y, GND) ------------------------
    // A chip, not a lump: a flat black case on a printed footprint, five pins,
    // and its function printed across the top the way a part number is. The
    // print is the part - a gate has no colour bands, no silver ring and no
    // silhouette that says what it does, so a package that does not name
    // itself is five identical black rectangles on a board.
    //
    // It also carries its supply pins, which is the whole reason it is drawn
    // as a package: the schematic hides VCC and GND, the board may not.
    Node {
        id: _gate
        visible: root.type === "gate"

        // Epoxy, hardcoded like the transistor's: a physical part colour, not
        // a role in the theme. Everything PRINTED below takes its ink from
        // this fill or from a theme token, never from a pinned value.
        //
        // Darker than the transistor's blob on purpose. Both printed faces
        // here are unlit, so the case is drawn at its literal value against a
        // literal sheet - and the transistor's #2a2724 is the dark theme's
        // sheet to within a hair, which would have left the package invisible
        // on the very footprint that names its pins.
        readonly property color caseColor: "#1b1815"

        // How strongly the output is high. `lit` says which level it is,
        // simV says how much of a level there is - a rail that has sagged
        // reads dimmer. Floored well above zero so a gate whose output volts
        // nobody feeds still shows a lit indicator rather than a dead one.
        readonly property real glow: root.lit
            ? Math.max(0.35, Math.min(1.0, Math.abs(root.simV) / 5.0)) : 0.0

        // The silkscreen, and the reason the part is legible: five pins in a
        // ring around a black case cannot be told apart by looking, so the
        // board names every one of them. Same rules as the transistor's
        // footprint - opaque edge to edge (a cut corner comes out BLACK here,
        // this material does no alpha blending), painted rim rather than a
        // border on transparency, `sheet` rather than the 2D `paper` so the
        // plate stays darker than the board when the theme goes dark.
        //
        // Every name is set BESIDE its pad, never under it: a pad is a raised
        // dome and it would swallow the letter whole. The names are literals -
        // VCC, GND, A, B, Y are printed unchanged on every datasheet in every
        // language, exactly like the A and V on the meter faces.
        Model {
            position: Qt.vector3d(0, 0.52, 0)
            source: "#Rectangle"
            eulerRotation.x: -90
            // 14.0 by 11.2: the footprint above, so the pads land on the plate
            // where the plate says they do
            scale: Qt.vector3d(0.14, 0.112, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    // an Item holding a filled Rectangle, never a Rectangle
                    // used directly as the source
                    sourceItem: Item {
                        // 25 px per world unit; a plane needs no flips, so
                        // item x runs with world x and item y with world z
                        width: 350; height: 280
                        Rectangle { anchors.fill: parent; color: LabTheme.sheet }
                        Rectangle {   // a painted rim, since a cut one goes black
                            anchors.fill: parent
                            anchors.margins: 4
                            color: "transparent"
                            border.color: LabTheme.step(LabTheme.sheet, 1.3)
                            border.width: 3
                        }
                        // the two inputs and the output, each one letter set
                        // inboard of its own pad
                        Text {
                            x: 42 - width / 2; y: 42 - height / 2
                            text: "A"; color: LabTheme.inkSoft
                            font.pixelSize: 40; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            x: 42 - width / 2; y: 238 - height / 2
                            text: "B"; color: LabTheme.inkSoft
                            font.pixelSize: 40; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            x: 308 - width / 2; y: 102 - height / 2
                            text: "Y"; color: LabTheme.inkSoft
                            font.pixelSize: 40; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        // the rails, on the long sides where a DIP carries
                        // them, offset sideways so the pad dome misses them
                        Text {
                            x: 235 - width / 2; y: 25 - height / 2
                            text: "VCC"; color: LabTheme.inkSoft
                            font.pixelSize: 36; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            x: 235 - width / 2; y: 255 - height / 2
                            text: "GND"; color: LabTheme.inkSoft
                            font.pixelSize: 36; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }

        Part {  // the case
            width: 8.0; height: 1.5; depth: 6.0
            position: Qt.vector3d(0, 0, 0)
            color: _gate.caseColor
        }

        // The top face, printed. It covers the case's whole top rather than
        // sitting on it as a smaller plate: this material is unlit, so a patch
        // of it in the middle of a toon-shaded face would read as a sticker
        // that caught the light differently.
        Model {
            position: Qt.vector3d(0, 1.53, 0)
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.08, 0.06, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    sourceItem: Item {
                        width: 320; height: 240
                        Rectangle { anchors.fill: parent; color: _gate.caseColor }
                        Rectangle {  // the pin-1 index mark, at the VCC end
                            x: 22; y: 22; width: 20; height: 20
                            radius: 10
                            color: LabTheme.inkOn(_gate.caseColor)
                            opacity: 0.4
                        }
                        Text {
                            anchors.centerIn: parent
                            // The one thing that tells two of these apart, so
                            // it is set as large as the case allows. Ink from
                            // the fill it is printed on, never pinned.
                            text: LabLang.t("gate." + root.func)
                            color: LabTheme.inkOn(_gate.caseColor)
                            font.pixelSize: 92; font.bold: true
                            font.letterSpacing: 2
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }

        Repeater3D {  // five pins, each one running from the case to its pad
            model: 5
            Model {
                readonly property var pad: root.termAt(index)
                // VCC and GND leave through the long sides, the signal pins
                // through the ends - which axis a pin runs along is simply
                // which way its pad lies
                readonly property bool sideways: Math.abs(pad.x) > Math.abs(pad.z)
                source: "#Cylinder"
                position: sideways ? Qt.vector3d(pad.x > 0 ? 4.9 : -4.9, 0.55, pad.z)
                                   : Qt.vector3d(pad.x, 0.55, pad.z > 0 ? 3.75 : -3.75)
                // a #Cylinder stands along Y: tip it onto X for the signal
                // pins, onto Z for the two rails
                eulerRotation: sideways ? Qt.vector3d(0, 0, 90) : Qt.vector3d(90, 0, 0)
                scale: Qt.vector3d(0.0034, sideways ? 0.026 : 0.022, 0.0034)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }

        // What the output is doing, as a pip beside the output pin - the
        // gate's answer to the transistor's collar. A logic board is a row of
        // identical black cases, and "which of these is putting out a high"
        // is the entire question being asked of it. Small and quiet on
        // purpose: it reports a level, it is not a lamp.
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(4.9, 0.60, 1.7)
            scale: Qt.vector3d(0.016, 0.004, 0.016)
            materials: Matte {
                baseColor: root.lit ? LabTheme.forest : LabTheme.inkFaint
                emissiveFactor: Qt.vector3d(0.05, 0.20, 0.09).times(_gate.glow)
            }
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
                // Lightened rather than recoloured: the lever's colour is
                // already carrying on/off, and a hover that changed it would
                // be answering a question nobody asked.
                color: root.actuatorHovered
                       ? Qt.lighter(root.switchOn ? LabTheme.forest
                                                  : LabTheme.clay, 1.45)
                       : (root.switchOn ? LabTheme.forest : LabTheme.clay)
                Behavior on color { ColorAnimation { duration: 90 } }
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
    // The face is the kernel's Gauge rendered to a texture, so the instrument
    // shows what it measures the way an instrument does: a scale, a range it
    // picked itself, and a needle that swings. It also makes an ammeter
    // unmistakably an ammeter from across the board, which a coloured ring
    // never did.
    //
    // The dial was written out here first and generalized afterwards; the
    // ranges below are the only part of it that was ever about circuits.
    Node {
        id: _meter
        visible: root.type === "ammeter" || root.type === "voltmeter"
        readonly property bool isAmp: root.type === "ammeter"
        readonly property color ring: isAmp ? LabTheme.forest : LabTheme.plum
        readonly property real reading: Math.abs(isAmp ? root.simI : root.simV)

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
                    // a render-to-texture source item is laid out in its own
                    // pixels rather than the screen's, so this one deliberately
                    // does NOT follow uiScale: the texel budget is fixed, and
                    // how large the part reads is the camera's business
                    sourceItem: Gauge {
                        width: 260; height: 200
                        symbol: _meter.isAmp ? "A" : "V"
                        unit: _meter.isAmp ? "A" : "V"
                        ranges: _meter.isAmp ? [0.01, 0.1, 1, 10] : [1, 5, 12, 60]
                        value: _meter.reading
                        accent: _meter.ring
                        frameRadius: 0    // a rounded corner here is a hole in the plate
                    }
                }
            }
        }
    }
}
