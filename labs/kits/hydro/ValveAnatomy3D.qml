// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "parts.js" as Parts
import "valve.js" as Valve

// The valve as the hydro kit's own anatomy: at spread 0 this IS
// HydroElement3D's valve - the same body, the same two flanges, the same
// stem, the same handwheel that turns a quarter, the same printed state
// plate, drawn from the numbers valve.js pins. That match is the whole
// point: a learner who watches it open has to see THE part coming apart,
// not a different part appearing in its place.
//
// The second subject of #274, and the proof of the claim: nothing in
// ExplodedView3D or ExplodePart was touched to make it. What a subject
// brings is its models and a part table; the mechanism - the stages, the
// glide, the focus dimming, the assembly lines, the marks - is the block's.
//
// The subject never looks a word up: `stateText` is handed in already
// translated, because a kit component has no business deciding whose
// vocabulary the plate prints.
ExplodedView3D {
    id: root

    /*! Open or shut - the handwheel's quarter turn and the tone of the part. */
    property bool switchOn: true

    /*! True while the pointer is over the handwheel; it lightens, as on the board. */
    property bool actuatorHovered: false

    /*! What the state plate prints, already in the lesson's language. */
    property string stateText: ""

    /*! The part's tone: forest when it is open, clay when it is shut. */
    readonly property color tone: root.switchOn ? LabTheme.forest : LabTheme.clay

    /*! The handwheel's tone, lightened while the pointer is on it. */
    readonly property color wheelTone: root.actuatorHovered
                                       ? LabTheme.step(root.tone, 1.25) : root.tone

    /*! The role-to-colour table: what each piece is made of, as a colour. */
    function roleColor(role) {
        switch (role) {
        case "shell": return Parts.colorOf("valve")
        case "metal": return LabTheme.muted
        case "actuator": return root.wheelTone
        case "print": return LabTheme.panel
        }
        return LabTheme.ink
    }

    // The kit's two body materials, as HydroElement3D declares them: flat and
    // glare-free for the round parts, toon-shaded boxes with ink edges for the
    // rest, so shapes read by silhouette and value and never by glare.
    component Matte: PrincipledMaterial {
        roughness: 1.0
        metalness: 0.0
        specularAmount: 0.0
    }
    component Part: Box3D {
        useToonShading: true
        edgeColorFactor: 0.55
    }

    // --- the body ------------------------------------------------------------
    // The one piece that never travels: everything else is explained as having
    // come off IT, so an explosion that moved it too would have no centre.
    ExplodePart {
        row: Valve.partById("body")
        position: Qt.vector3d(0, Valve.BODY.y, 0)
        Part {
            width: Valve.BODY.width
            height: Valve.BODY.height
            depth: Valve.BODY.depth
            color: root.roleColor("shell")
        }
    }

    // --- the two pipe flanges ------------------------------------------------
    // Discs on the body's left and right faces. A #Cylinder stands along y, so
    // both are tipped onto x - the axis the pipe run arrives on.
    ExplodePart {
        row: Valve.partById("flange.in")
        position: Qt.vector3d(-Valve.FLANGE.x, Valve.FLANGE.y, 0)
        Model {
            source: "#Cylinder"
            eulerRotation.z: 90
            scale: Qt.vector3d(Valve.FLANGE.radius * 2 / 100, Valve.FLANGE.length / 100,
                               Valve.FLANGE.radius * 2 / 100)
            materials: Matte { baseColor: root.roleColor("metal") }
        }
    }
    ExplodePart {
        row: Valve.partById("flange.out")
        position: Qt.vector3d(Valve.FLANGE.x, Valve.FLANGE.y, 0)
        Model {
            source: "#Cylinder"
            eulerRotation.z: 90
            scale: Qt.vector3d(Valve.FLANGE.radius * 2 / 100, Valve.FLANGE.length / 100,
                               Valve.FLANGE.radius * 2 / 100)
            materials: Matte { baseColor: root.roleColor("metal") }
        }
    }

    // --- the stem ------------------------------------------------------------
    // What the handwheel turns and the body hides: it only appears once the
    // wheel is off, which is why it travels in the second stage.
    ExplodePart {
        row: Valve.partById("stem")
        position: Qt.vector3d(0, Valve.STEM.y, 0)
        Model {
            source: "#Cylinder"
            scale: Qt.vector3d(Valve.STEM.radius * 2 / 100, Valve.STEM.height / 100,
                               Valve.STEM.radius * 2 / 100)
            materials: Matte { baseColor: root.roleColor("metal") }
        }
    }

    // --- the handwheel, a sub-assembly ---------------------------------------
    // It leaves as one piece in the first stage and comes apart in the second:
    // the rim lifts off the spokes it is carried on.
    //
    // The quarter turn lives on a plain Node INSIDE the part, never on the part
    // itself: the part's own transform is the view's to write, and a mark on
    // the wheel must stay on the near side of the rim rather than ride round
    // with it.
    ExplodePart {
        row: Valve.partById("handwheel")
        position: Qt.vector3d(0, Valve.WHEEL.y, 0)

        Node {
            eulerRotation.y: root.switchOn ? 0 : 90
            Behavior on eulerRotation.y { NumberAnimation { duration: 160 } }

            ExplodePart {
                row: Valve.partById("handwheel.rim")
                position: Qt.vector3d(0, 0, 0)
                Model {
                    source: "#Cylinder"
                    scale: Qt.vector3d(Valve.WHEEL.rimRadius * 2 / 100,
                                       Valve.WHEEL.rimHeight / 100,
                                       Valve.WHEEL.rimRadius * 2 / 100)
                    materials: Matte { baseColor: root.wheelTone }
                }
            }

            // Two crossed bars, so the turn is visible from above - the one
            // angle a board is mostly seen from. Written out rather than
            // repeated: two pieces of one part, not a model of a list.
            ExplodePart {
                row: Valve.partById("handwheel.spokes")
                position: Qt.vector3d(0, 0, 0)
                Part {
                    width: Valve.WHEEL.spokeSpan
                    height: Valve.WHEEL.spokeHeight
                    depth: Valve.WHEEL.spokeWidth
                    position: Qt.vector3d(0, Valve.WHEEL.spokeY, 0)
                    color: LabTheme.step(root.wheelTone, 0.85)
                    showEdges: false
                }
                Part {
                    width: Valve.WHEEL.spokeWidth
                    height: Valve.WHEEL.spokeHeight
                    depth: Valve.WHEEL.spokeSpan
                    position: Qt.vector3d(0, Valve.WHEEL.spokeY, 0)
                    color: LabTheme.step(root.wheelTone, 0.85)
                    showEdges: false
                }
            }
        }
    }

    // --- the printed state ---------------------------------------------------
    // A handwheel's angle is hard to read from straight above, so the valve
    // says in words what it is doing. Drawn to a texture: the font sizes here
    // are texels, not UI sizes - the one place a bare pixelSize is right.
    ExplodePart {
        row: Valve.partById("plate")
        position: Qt.vector3d(0, Valve.PLATE.y, Valve.PLATE.z)
        Model {
            source: "#Rectangle"
            eulerRotation.x: -90
            scale: Qt.vector3d(Valve.PLATE.width / 100, Valve.PLATE.depth / 100, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture {
                    sourceItem: Item {
                        width: 200; height: 92
                        Rectangle { anchors.fill: parent; color: root.roleColor("print") }
                        Text {
                            anchors.centerIn: parent
                            text: root.stateText
                            color: root.tone
                            font.pixelSize: 60; font.bold: true
                            font.letterSpacing: 4
                            font.family: LabTheme.monoFont
                        }
                    }
                }
            }
        }
    }
}
