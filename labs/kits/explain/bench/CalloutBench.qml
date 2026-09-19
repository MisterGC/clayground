// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The callout bench - one transistor-shaped lump, six things to say about it,
// and a key per way of revealing them.
//
// Deliberately not a lab and not the real anatomy: a CalloutLayer's whole job
// is geometry (does a card sit where the reader can read it, does its leader
// still point at the thing after the camera turns) and that question is asked
// fastest against a subject that cannot change under it. The subject here is
// the circuit kit's transistor silhouette copied at part scale - epoxy blob,
// flat face, three legs on the board - so the numbers the layer reports are
// the numbers it will report in electronics-101.
//
// Keys: N reveal one more · P one fewer · A all · 0 none · L numbers on/off ·
// K a keep-out box over the left third (a professor standing there). Camera as
// everywhere else: right-drag turns, middle drags, wheel zooms, Space+left pans.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import ".."

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: forceActiveFocus()

    // --- what there is to say -------------------------------------------------
    // Six points on one part, chosen to break a naive layout rather than to
    // look tidy: three of them are within a leg's length of each other, one is
    // above the part, one is on the near face and one is INSIDE the case - the
    // last being the reason this approach exists at all.
    readonly property var callouts: [
        { at: Qt.vector3d(-1.75, 0.7, 0), label: "Collector",
          detail: "the leg the load current leaves by" },
        { at: Qt.vector3d(0, 0.7, 1.75), label: "Base",
          detail: "a small current here controls the big one" },
        { at: Qt.vector3d(1.75, 0.7, 0), label: "Emitter",
          detail: "the leg the current comes in by" },
        { at: Qt.vector3d(0, 3.1, -0.35), label: "Epoxy case",
          detail: "protects a chip a tenth its size" },
        { at: Qt.vector3d(0, 1.55, 1.45), label: "Flat face",
          detail: "the side the base pad is on" },
        { at: Qt.vector3d(0, 1.4, 0), label: "The die",
          detail: "three layers of silicon: N-P-N" }
    ]

    // The three pads the legs reach, in the circuit kit's cell units.
    readonly property var pads: [
        Qt.vector3d(-3.5, 0.62, 0),     // collector
        Qt.vector3d(0, 0.62, 3.5),      // base
        Qt.vector3d(3.5, 0.62, 0)       // emitter
    ]

    // --- the state the keys move ---------------------------------------------
    property int revealed: 0
    property bool numbered: true
    property bool blocked: false        // is the keep-out box up?

    function revealNext() {
        revealed = revealed < 0 ? layer.count
                                : Math.min(layer.count, revealed + 1)
    }
    function revealFewer() {
        revealed = Math.max(0, (revealed < 0 ? layer.count : revealed) - 1)
    }
    function revealAll() { revealed = -1 }
    function revealNone() { revealed = 0 }

    // A standing presenter's projected box, near enough: the left third of the
    // viewport from the waist of the frame down. Not the whole height - a box
    // that reaches the top edge leaves a column with nowhere to put a card,
    // and then the interesting question (where do the cards GO) never gets
    // asked.
    readonly property var keepOutBox: ({ x: 0, y: root.height * 0.35,
                                         width: root.width / 3,
                                         height: root.height * 0.65 })

    // --- the verification seams ----------------------------------------------

    /*
        True when every callout is up, in front of the camera, and its card is
        inside the viewport and touches no other card. The one question a
        headless render can ask about a layout, so --wait-for waits on this
        rather than on a screenshot.
    */
    function cardsClean() {
        const n = layer.count
        if (layer.shownCount !== n) return false
        const rects = []
        for (let i = 0; i < n; ++i) {
            if (layer.screenOf(i).z <= 0) return false
            const r = layer.cardRectOf(i)
            if (r.width <= 0 || r.height <= 0) return false
            if (r.x < 0 || r.y < 0
                || r.x + r.width > layer.width || r.y + r.height > layer.height)
                return false
            rects.push(r)
        }
        for (let i = 0; i < rects.length; ++i)
            for (let j = i + 1; j < rects.length; ++j)
                if (root._overlap(rects[i], rects[j])) return false
        return true
    }

    function _overlap(a, b) {
        return a.x < b.x + b.width && b.x < a.x + a.width
               && a.y < b.y + b.height && b.y < a.y + a.height
    }

    function report() {
        const screens = []
        const cards = []
        for (let i = 0; i < layer.count; ++i) {
            const s = layer.screenOf(i)
            screens.push([s.x, s.y, s.z])
            cards.push(layer.cardRectOf(i))
        }
        return ({ revealed: layer.revealed, shownCount: layer.shownCount,
                  visibleCount: layer.visibleCount, count: layer.count,
                  screens: screens, cards: cards })
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
            // The default near plane is 10 units and this subject is 3 units
            // tall: without this the part is gone the moment you zoom in.
            Component.onCompleted: rig.camera.clipNear = 0.5
        }
        CameraAnchorMark { pointer: nav }

        // --- the subject ---------------------------------------------------
        // A stand-in for TransistorAnatomy3D, matching the circuit kit's
        // transistor pose exactly so the callout points here are the points
        // the real part will be called out at.
        Node {
            id: part

            Model {  // the epoxy body - a physical part colour, not a theme role
                source: "#Cylinder"
                position: Qt.vector3d(0, 1.55, -0.35)
                scale: Qt.vector3d(0.042, 0.031, 0.042)
                materials: PrincipledMaterial {
                    baseColor: "#2a2724"   // the circuit kit's epoxy
                    roughness: 1; metalness: 0; specularAmount: 0
                }
            }

            Model {  // the flat face, on the side the base pad is on
                source: "#Cube"
                position: Qt.vector3d(0, 1.55, 0.85)
                scale: Qt.vector3d(0.038, 0.031, 0.012)
                materials: PrincipledMaterial {
                    baseColor: "#332f2b"   // the same epoxy, one step lighter
                    roughness: 1; metalness: 0; specularAmount: 0
                }
            }

            Repeater3D {  // three legs, half way out to their pads
                model: 3
                Model {
                    id: leg
                    required property int index
                    readonly property var pad: root.pads[leg.index]
                    source: "#Cylinder"
                    position: Qt.vector3d(leg.pad.x * 0.5, 0.55, leg.pad.z * 0.5)
                    // A #Cylinder stands along Y: tip it onto X for the two
                    // side legs, onto Z for the base leg reaching the near pad.
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
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // The thing under test. Sibling of the View3D, never a child of it.
    CalloutLayer {
        id: layer
        anchors.fill: parent
        view: view3d
        // From the VIEW, never from the rig: naming rig.camera gets the layer
        // past its own null guard while the view still has none, and the first
        // projection then goes through "Cannot resolve view position".
        camera: view3d.camera
        callouts: root.callouts
        revealed: root.revealed
        numbered: root.numbered
        keepOut: root.blocked ? root.keepOutBox : null
    }

    // --- the bench controls ---------------------------------------------------
    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(210)
        title: "CALLOUT BENCH"
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
            label: "reveal one more (N)"
            onHit: root.revealNext()
        }
        BenchButton {
            label: "one fewer      (P)"
            onHit: root.revealFewer()
        }
        BenchButton {
            label: "all            (A)"
            active: root.revealed < 0
            onHit: root.revealAll()
        }
        BenchButton {
            label: "none           (0)"
            active: root.revealed === 0
            onHit: root.revealNone()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "numbers        (L)"
            active: root.numbered
            onHit: root.numbered = !root.numbered
        }
        BenchButton {
            label: "keep-out box   (K)"
            active: root.blocked
            onHit: root.blocked = !root.blocked
        }
    }

    // What the layer says about itself, in numbers. A bench that only shows
    // the picture cannot tell you why the picture is wrong.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(190)
        title: "STATE"
        Text {
            text: "count    " + layer.count
                + "\nrevealed " + layer.revealed
                + "\nshown    " + layer.shownCount
                + "\nvisible  " + layer.visibleCount
                + "\nkeep-out " + (root.blocked ? "on" : "off")
                + "\nclean    " + root.cardsClean()
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // --- keeping your place across a reload ----------------------------------
    function viewState() {
        return ({ revealed: root.revealed, numbered: root.numbered,
                  blocked: root.blocked, cam: rig.state() })
    }

    function applyViewState(s) {
        if (!s) return
        if (s.revealed !== undefined) root.revealed = s.revealed
        if (s.numbered !== undefined) root.numbered = s.numbered
        if (s.blocked !== undefined) root.blocked = s.blocked
        if (s.cam) rig.applyState(s.cam)
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        keys: [
            { key: "N", label: "reveal one more", action: () => root.revealNext() },
            { key: "P", label: "one fewer", action: () => root.revealFewer() },
            { key: "A", label: "reveal all", action: () => root.revealAll() },
            { key: "0", label: "reveal none", action: () => root.revealNone() },
            { key: "L", label: "numbers on / off",
              action: () => root.numbered = !root.numbered },
            { key: "K", label: "a presenter stands in the left third",
              action: () => root.blocked = !root.blocked }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    // LabKeys maps LETTERS, so the 0 listed above documents the key without
    // ever receiving it - the digit has to be caught here.
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_0 && !(ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            root.revealNone()
            ev.accepted = true
            return
        }
        keymap.handle(ev)
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
