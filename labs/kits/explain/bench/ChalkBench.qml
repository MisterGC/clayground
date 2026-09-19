// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The chalkboard's bench - a scene worth cutting away FROM, and the board that
// cuts away from it.
//
// The scene is deliberately the one thing the mechanism cannot explain: a black
// TO-92 lump with three legs, standing on the same squared paper every lab
// stands on. Look at it as long as you like and it will not tell you what is
// inside it. That is the problem the board exists for, and a bench that showed
// something already legible would let the mechanism off the hook.
//
// Keys: O cut to the board / back · D draw it · R rewind · H half-drawn ·
// X the cross-section · G the gain graph (1 and 2 do the same). Camera as
// everywhere else: right-drag turns, middle drags, wheel zooms, Space+left pans.
// Bound so the inline BenchButton may name the ids around it (`controls`,
// `root`) instead of reaching for them unqualified. Safe here because nothing
// in this file animates a Repeater3D delegate - Bound plus a Behavior on one
// is a SIGSEGV on Qt 6.11.1.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import ".."
import "../chalk.js" as Chalk

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: root.forceActiveFocus()

    // --- the subject ---------------------------------------------------------
    // Where the three legs reach the board, as the circuit kit puts them -
    // collector left, base on the near side, emitter right.
    readonly property var pads: [Qt.vector3d(-3.5, 0.62, 0),
                                 Qt.vector3d(0, 0.62, 3.5),
                                 Qt.vector3d(3.5, 0.62, 0)]

    // --- what is on the board ------------------------------------------------
    // English literals: a bench is not a lab, and the kit types take their text
    // as data precisely so the lab can own the translation instead.
    readonly property var sectionLabels: ({ n: "N", p: "P",
                                           collector: "collector", base: "base",
                                           emitter: "emitter",
                                           ib: "I_B  0.8 mA", ic: "I_C  9.8 mA" })
    readonly property var gainLabels: ({ ib: "I_B", ic: "I_C", beta: "β ≈ 12" })

    property string picked: "section"

    function showDrawing(name) {
        if (name === root.picked) return
        root.picked = name
        // A new drawing starts from nothing: carrying the old cursor over would
        // show the second half of a drawing whose first half was never drawn.
        board.progress = 0
    }

    function toggleBoard() { if (board.shown) board.close(); else board.open() }

    function report() {
        const r = board.report()
        r.drawing = root.picked
        return r
    }

    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        LabStage3D {
            id: stage
            cellSize: 1
            majorEvery: 5
            gridMode: grid
            workExtent: Qt.vector2d(40, 40)
        }

        OrbitCamera3D {
            id: rig
            view: view3d
            pivot: Qt.vector3d(0, 2, 0)
            homePivot: Qt.vector3d(0, 2, 0)
            yaw: 20; pitch: 26; distance: 24
            minDistance: 3; maxDistance: 120
            minHeight: 0.5
            // The default near plane is 10 units; a part 4 units across is
            // gone long before the camera is close enough to look at it.
            Component.onCompleted: rig.camera.clipNear = 0.5
        }

        // The epoxy blob, at the circuit kit's own dimensions and colour: a
        // physical part colour, not a role in the palette.
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, 1.55, -0.35)
            scale: Qt.vector3d(0.042, 0.031, 0.042)
            materials: PrincipledMaterial {
                baseColor: "#2a2724"
                roughness: 1; metalness: 0; specularAmount: 0
            }
        }

        // Three legs, lying flat just above the board, half way out to their
        // pads. A #Cylinder stands along Y, so the two side legs tip onto X
        // and the base leg onto Z.
        Repeater3D {
            model: root.pads
            Model {
                id: leg
                required property int index
                required property vector3d modelData
                source: "#Cylinder"
                position: Qt.vector3d(leg.modelData.x * 0.5, 0.55, leg.modelData.z * 0.5)
                eulerRotation: leg.index === 1 ? Qt.vector3d(90, 0, 0)
                                               : Qt.vector3d(0, 0, 90)
                scale: Qt.vector3d(0.0032, 0.035, 0.0032)
                materials: PrincipledMaterial {
                    baseColor: LabTheme.muted
                    roughness: 1; metalness: 0; specularAmount: 0
                }
            }
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // --- the cut -------------------------------------------------------------
    // Over the View3D, filling it: the board is an overlay on the lab, not a
    // thing in the scene. Which is also its main limitation - see the report.
    Chalkboard {
        id: board
        anchors.fill: parent
        drawing: root.picked === "gain"
               ? Chalk.gainGraph(12, root.gainLabels)
               : Chalk.transistorSection(root.sectionLabels)
        caption: root.picked === "gain"
               ? "Twelve times over: the collector current follows the base"
                 + " current, until the lamp cannot pass any more."
               : "A small current into the base opens the way for a large one"
                 + " from collector to emitter."
    }

    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(210)
        title: "CHALKBOARD BENCH"
        tag: "?"

        component BenchButton: Rectangle {
            id: btn
            property string label: ""
            property bool active: false
            signal hit()
            width: controls.body.width
            height: LabTheme.px(24)
            radius: LabTheme.px(4)
            color: btn.active ? LabTheme.secondary
                 : hover.containsMouse ? LabTheme.step(LabTheme.panel, 1.2)
                                       : LabTheme.panel
            border.color: LabTheme.panelEdge
            border.width: Math.max(1, LabTheme.uiScale)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: LabTheme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.active ? LabTheme.inkOn(LabTheme.secondary) : LabTheme.ink
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.forceActiveFocus(); btn.hit() }
            }
        }

        BenchButton {
            label: board.shown ? "back to the part (O)" : "cut to the board (O)"
            active: board.shown
            onHit: root.toggleBoard()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "draw it      (D)"
            onHit: board.progress = 1
        }
        BenchButton {
            label: "half of it   (H)"
            onHit: board.progress = 0.5
        }
        BenchButton {
            label: "rewind       (R)"
            onHit: board.progress = 0
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "cross-section (X)"
            active: root.picked === "section"
            onHit: root.showDrawing("section")
        }
        BenchButton {
            label: "gain graph    (G)"
            active: root.picked === "gain"
            onHit: root.showDrawing("gain")
        }
        Item { width: 1; height: LabTheme.spaceM }
        // What the board is doing, in the numbers report() answers with: a
        // bench that only shows the picture cannot say why the picture is wrong.
        Text {
            text: "shown    " + board.shown
                + "\npresence " + board.presence.toFixed(2)
                + "\nprogress " + board.progress.toFixed(2)
                + "\ndrawn    " + board.progressNow.toFixed(2)
                + "\nops      " + board.report().opsDrawn + "/" + board.report().ops
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        keys: [
            { key: "O", label: "cut to the board / back", action: () => root.toggleBoard() },
            { key: "D", label: "draw the whole thing", action: () => board.progress = 1 },
            { key: "H", label: "half of it", action: () => board.progress = 0.5 },
            { key: "R", label: "rewind", action: () => board.progress = 0 },
            { key: "X", label: "the cross-section", action: () => root.showDrawing("section") },
            { key: "G", label: "the gain graph", action: () => root.showDrawing("gain") }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    // The digits first: LabKeys maps LETTERS, so 1 and 2 would never reach the
    // key list. They are here because a bench with two drawings wants them.
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_1) { root.showDrawing("section"); ev.accepted = true; return }
        if (ev.key === Qt.Key_2) { root.showDrawing("gain"); ev.accepted = true; return }
        keymap.handle(ev)
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
