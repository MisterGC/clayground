// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "parts.js" as Parts
import "hydro.js" as Hydro

pragma ComponentBehavior: Bound

// One hydro part on the board: body by type, pads where parts.js says they
// are. Purely visual - the board owns state, hit testing and the solver; this
// node just renders what it is told, and it takes the same properties as the
// circuit kit's CircuitElement3D under the domain's own names (simQ for simI,
// simDp for simV, turning for lit), so a lab written against one can be read
// beside a lab written against the other.
//
// Shading is deliberately flat: toon-shaded boxes with ink edges and fully
// matte round parts, so shapes read by silhouette and value, never by glare.
//
// Nothing here animates itself. A water wheel turns by `phase`, an angle the
// LAB drives from the sim clock (phase += dt * speed * k), because a component
// that spun on wall time would drift away from a stepped clock and could not
// be photographed twice the same way.
Node {
    id: root

    property string type: "pipe"
    property real value: 8           // pump kPa, pipe kPa*s/L
    property bool switchOn: true     // valve open
    property real simQ: 0            // L/s through the part
    property real simDp: 0           // kPa across the part
    property real simPower: 0        // watts
    property bool turning: false     // water wheel doing work
    property real speed: 0           // wheel speed, rpm-like
    property real phase: 0           // wheel angle in degrees, driven by the lab
    property bool shorted: false     // pump outlet piped back to its suction
    property bool overloaded: false  // heavy but honest load
    property bool hovered: false
    property bool actuatorHovered: false   // the valve's handwheel, specifically
    property bool selected: false
    property int wiringTerminal: -1  // pad glowing during plumbing, -1 none

    // --- board geometry, from the one file that owns it ---------------------
    readonly property var _spec: Parts.specOf(type)
    readonly property int termCount: _spec ? _spec.terminals.length : 0
    readonly property real halfWidth: _spec ? _spec.half.x : 4.6
    readonly property real halfDepth: _spec ? _spec.half.y : 3.4

    /*! Local offset of pad `i`, as a board vector (y is up, always 0 here). */
    function termAt(i) {
        if (!_spec || i < 0 || i >= _spec.terminals.length)
            return Qt.vector3d(0, 0, 0)
        return Qt.vector3d(_spec.terminals[i].x, 0, _spec.terminals[i].y)
    }

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
    // The one thing in this component View3D.pick can find, and the reason a
    // handheld instrument can be pointed at a part at all: QQuick3DModel's
    // `pickable` is false by default, so without this every body here is
    // invisible to a ray and the stage's ground answers every click.
    //
    // One volume rather than a pickable flag on each body: a ray hits a model
    // whose parent Node is `visible: false` just the same, so pickable bodies
    // would give a flat pipe the hit target of the wheel it is not showing.
    // A Model with no material renders nothing while still being hit, so this
    // costs a bounds test and no draw call.
    Model {
        objectName: "pickVolume"
        source: "#Cube"
        pickable: true
        // #Cube is 100 units, and the box stands from the board up over the
        // tallest body here (the wheel's rim, whose top is at y 6.4)
        readonly property real high: root.type === "junction" ? 1.2
                                   : root.type === "wheel" ? 6.8 : 5.0
        position: Qt.vector3d(0, high * 0.5, 0)
        scale: Qt.vector3d(root.halfWidth * 2 / 100, high / 100,
                           root.halfDepth * 2 / 100)
    }

    // --- hover / selection frame --------------------------------------------
    SelectionFrame3D {
        selected: root.selected
        hovered: root.hovered
        halfWidth: root.halfWidth + 0.6
        halfDepth: root.halfDepth + 0.5
        // a T-piece has no front, so it gets no facing mark
        showNose: root.type !== "junction"
        // A part sits slightly SUNK into the board so its shadow hugs it; the
        // frame has to lie on the board, not inside it and not hovering above.
        height: 0.62
    }

    // --- junction: a T-piece where pipe runs meet ---------------------------
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

    // --- pads ---------------------------------------------------------------
    // Brass flange discs sunk into the board rather than balls on posts: the
    // pipe runs lie flat on the paper, so they have to meet the pads at board
    // level. Their places come from termAt(), which is parts.js's table - the
    // pads and the board's own hit test cannot disagree.
    Repeater3D {
        model: root.termCount
        Model {
            id: _pad
            required property int index
            visible: root.type !== "junction"   // the dot is its own pad
            source: "#Cylinder"
            position: root.termAt(_pad.index).plus(Qt.vector3d(0, 0.5, 0))
            scale: Qt.vector3d(0.024, 0.006, 0.024)
            // a material's parent is the Model, not the enclosing Node, so the
            // pad's index has to be reached through its id
            materials: Matte {
                baseColor: root.wiringTerminal === _pad.index
                           ? LabTheme.secondary : LabTheme.highlight
                emissiveFactor: root.wiringTerminal === _pad.index
                                ? Qt.vector3d(0, 0.3, 0.6) : Qt.vector3d(0, 0, 0)
            }
        }
    }

    // --- pump ---------------------------------------------------------------
    // A squat volute casing with the outlet spout on the terminal-0 side, in
    // the same gold the pads wear: the part states its own polarity, the way
    // the circuit kit's cell does with its + cap.
    Node {
        visible: root.type === "pump"
        Model {                                  // casing
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.2, 0)
            scale: Qt.vector3d(0.048, 0.024, 0.048)
            materials: Matte {
                baseColor: root.shorted ? LabTheme.alarm
                         : root.overloaded ? LabTheme.highlight
                         : Parts.colorOf("pump")
            }
            SequentialAnimation on opacity {
                running: root.shorted; loops: Animation.Infinite; alwaysRunToEnd: true
                NumberAnimation { to: 0.45; duration: 240 }
                NumberAnimation { to: 1.0; duration: 240 }
            }
        }
        Part {                                   // outlet spout, toward pad 0
            width: 2.6; height: 1.7; depth: 1.7
            position: Qt.vector3d(-3.0, 0.4, 0); color: LabTheme.highlight
        }
        Part {                                   // suction port, toward pad 1
            width: 2.2; height: 1.1; depth: 1.4
            position: Qt.vector3d(3.0, 0.3, 0); color: LabTheme.muted
        }
        // One printed plate instead of little 3D glyphs: it carries the head
        // the pump is set to and marks which side the water leaves by.
        Model {
            position: Qt.vector3d(0, 2.47, 0)
            source: "#Rectangle"
            eulerRotation.x: -90
            // inside the casing's circle, or the plate's corners hang over its
            // rim and the part reads as a card resting on a tin
            scale: Qt.vector3d(0.038, 0.024, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                // a plane needs no flips, unlike a cube's up face
                baseColorMap: Texture {
                    // laid out in its own pixels: a render-to-texture source
                    // deliberately does NOT follow uiScale, because the texel
                    // budget is fixed and how large the part reads on screen
                    // is the camera's business
                    sourceItem: Item {
                        width: 300; height: 190
                        Rectangle { anchors.fill: parent; color: LabTheme.panel }
                        Text {
                            // the arrow points at pad 0, the outlet - the same
                            // job the cell's + does in the circuit kit
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            text: "◀"; color: LabTheme.clay
                            font.pixelSize: 44
                            font.family: LabTheme.monoFont
                        }
                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 20
                            text: LabLang.num(root.value, 0) + " kPa"
                            color: LabTheme.ink
                            font.pixelSize: 48; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- valve --------------------------------------------------------------
    // The one part you operate: a body, a rising stem and a handwheel that
    // turns a quarter and changes colour. The handwheel lightens while the
    // pointer is over it, which is how the board says "this is the bit you
    // grab" before anything is clicked.
    Node {
        id: _valve
        visible: root.type === "valve"
        readonly property color tone: root.switchOn ? LabTheme.forest : LabTheme.clay
        readonly property color wheelTone: root.actuatorHovered
                                           ? LabTheme.step(tone, 1.25) : tone
        Part {                                   // body
            width: 5.0; height: 1.5; depth: 3.0
            position: Qt.vector3d(0, 0.05, 0)
            color: Parts.colorOf("valve")
        }
        Repeater3D {                             // the two flanges
            model: 2
            Model {
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -2.6 : 2.6, 0.75, 0)
                eulerRotation.z: 90
                scale: Qt.vector3d(0.017, 0.006, 0.017)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }
        Model {                                  // stem
            source: "#Cylinder"
            position: Qt.vector3d(0, 2.0, 0)
            scale: Qt.vector3d(0.004, 0.008, 0.004)
            materials: Matte { baseColor: LabTheme.muted }
        }
        Node {                                   // handwheel
            position: Qt.vector3d(0, 2.7, 0)
            eulerRotation.y: root.switchOn ? 0 : 90
            Behavior on eulerRotation.y { NumberAnimation { duration: 160 } }
            Model {                              // rim
                source: "#Cylinder"
                scale: Qt.vector3d(0.026, 0.003, 0.026)
                materials: Matte { baseColor: _valve.wheelTone }
            }
            Repeater3D {                         // spokes, so the turn is visible
                model: 2
                Part {
                    required property int index
                    width: index === 0 ? 5.0 : 0.5
                    height: 0.28
                    depth: index === 0 ? 0.5 : 5.0
                    position: Qt.vector3d(0, -0.14, 0)
                    color: LabTheme.step(_valve.wheelTone, 0.85)
                    showEdges: false
                }
            }
        }
        Model {                                  // printed state
            // a handwheel's angle is hard to read from straight above, and
            // from above is how a board is mostly seen
            position: Qt.vector3d(0, 1.57, 1.1)
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.026, 0.008, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    sourceItem: Item {
                        width: 200; height: 92
                        Rectangle { anchors.fill: parent; color: LabTheme.panel }
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.t(root.switchOn ? "valve.open" : "valve.closed")
                            color: _valve.tone
                            font.pixelSize: 60; font.bold: true
                            font.letterSpacing: 4
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- narrow pipe (the restriction) --------------------------------------
    // The bore is the resistance, drawn: a high setting is a hair-thin neck
    // between two full-size flanges, and the number is printed beside it so
    // the picture and the value are never in doubt about each other.
    Node {
        id: _pipe
        visible: root.type === "pipe"
        readonly property real bore: {
            const n = Hydro.pipeSteps.length
            const f = Hydro.pipeStepOf(root.value || 8) / Math.max(1, n - 1)
            return 1.05 - 0.85 * f
        }
        Repeater3D {                             // flanges
            model: 2
            Model {
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -2.2 : 2.2, 1.1, 0)
                eulerRotation.z: 90
                scale: Qt.vector3d(0.022, 0.007, 0.022)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }
        Model {                                  // the neck
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.1, 0)
            eulerRotation.z: 90
            scale: Qt.vector3d(_pipe.bore * 0.022, 0.021, _pipe.bore * 0.022)
            materials: Matte { baseColor: Parts.colorOf("pipe") }
        }
        Repeater3D {                             // stub pipes out to the pads
            model: 2
            Model {
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(index === 0 ? -3.0 : 3.0, 1.1, 0)
                eulerRotation.z: 90
                scale: Qt.vector3d(0.016, 0.008, 0.016)
                materials: Matte { baseColor: LabTheme.muted }
            }
        }
        Model {                                  // printed resistance
            position: Qt.vector3d(0, 0.12, 2.3)
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(0.03, 0.009, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    sourceItem: Item {
                        width: 220; height: 66
                        Rectangle { anchors.fill: parent; color: LabTheme.panel }
                        Text {
                            anchors.centerIn: parent
                            text: LabLang.num(root.value, root.value < 10 ? 1 : 0)
                            color: LabTheme.ink
                            font.pixelSize: 46; font.bold: true
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }

    // --- water wheel --------------------------------------------------------
    // Two nested nodes rather than one Euler triple: the outer one lays the
    // wheel's own axis along the board's z, the inner one spins about it. The
    // angle is `phase`, which the lab advances from the sim clock - nothing
    // here consumes wall time or the clock's RNG.
    Node {
        id: _wheel
        visible: root.type === "wheel"
        readonly property real radius: 2.9
        readonly property color blade: root.turning
                                       ? LabTheme.step(Parts.colorOf("wheel"), 1.18)
                                       : Parts.colorOf("wheel")
        Repeater3D {                             // the trough it sits in
            model: 2
            Part {
                required property int index
                width: 8.4; height: 0.9; depth: 0.7
                position: Qt.vector3d(0, 0, index === 0 ? -2.5 : 2.5)
                color: LabTheme.muted
            }
        }
        Node {
            position: Qt.vector3d(0, _wheel.radius + 0.5, 0)
            eulerRotation.x: 90                  // axle along the board's z
            Node {
                eulerRotation.y: root.phase      // the lab's clock drives this
                Model {                          // hub
                    source: "#Cylinder"
                    position: Qt.vector3d(0, -0.2, 0)
                    scale: Qt.vector3d(0.011, 0.011, 0.011)
                    materials: Matte { baseColor: LabTheme.inkSolid }
                }
                // A wheel has to read as a wheel from the side AND from above,
                // so it is built the way one is built: spokes out of the hub
                // and paddles across their tips. A solid disc reads as a coin.
                Repeater3D {                     // spokes
                    model: 8
                    Part {
                        required property int index
                        readonly property real ang: index * Math.PI / 4
                        width: _wheel.radius * 0.95; height: 0.26; depth: 0.38
                        position: Qt.vector3d(Math.cos(ang) * _wheel.radius * 0.5,
                                              -0.13,
                                              Math.sin(ang) * _wheel.radius * 0.5)
                        eulerRotation.y: -index * 45
                        color: LabTheme.step(_wheel.blade, 0.86)
                        showEdges: false
                    }
                }
                Repeater3D {                     // paddles, across the flow
                    model: 8
                    Part {
                        required property int index
                        readonly property real ang: index * Math.PI / 4
                        width: 1.05; height: 1.7; depth: 0.24
                        position: Qt.vector3d(Math.cos(ang) * _wheel.radius * 0.86,
                                              -0.85,
                                              Math.sin(ang) * _wheel.radius * 0.86)
                        eulerRotation.y: -index * 45
                        color: _wheel.blade
                    }
                }
            }
        }
    }

    // --- meters: a real dial, printed onto the part -------------------------
    // The kernel's Gauge rendered to a texture, so the instrument shows what it
    // measures the way an instrument does: a scale, a range it picked itself,
    // and a needle that swings. Q and p, in the units the domain is taught in.
    Node {
        id: _meter
        visible: root.type === "flowmeter" || root.type === "gauge"
        readonly property bool isFlow: root.type === "flowmeter"
        readonly property color ring: isFlow ? Parts.colorOf("flowmeter")
                                             : Parts.colorOf("gauge")
        readonly property real reading: Math.abs(isFlow ? root.simQ : root.simDp)

        Part {                                   // case (Box3D sits on its y)
            width: 7.0; height: 1.4; depth: 5.6
            position: Qt.vector3d(0, 0, 0)
            color: _meter.ring
        }
        Model {                                  // dial plate: its up face
            source: "#Cube"                      // carries the rendered face
            position: Qt.vector3d(0, 1.55, 0)
            scale: Qt.vector3d(0.062, 0.004, 0.048)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting   // keep the print crisp
                baseColorMap: Texture {
                    // the cube's up face maps U mirrored: flip both so the
                    // print reads the right way round
                    flipU: true
                    flipV: true
                    sourceItem: Gauge {
                        width: 260; height: 200
                        symbol: _meter.isFlow ? "Q" : "p"
                        unit: _meter.isFlow ? "L/s" : "kPa"
                        ranges: _meter.isFlow ? [0.5, 2, 5, 20] : [5, 20, 60, 150]
                        value: _meter.reading
                        accent: _meter.ring
                        frameRadius: 0   // a rounded corner here is a hole in the plate
                    }
                }
            }
        }
    }
}
