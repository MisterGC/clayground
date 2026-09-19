// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The bench for approach 1: the transistor anatomy on one side and the circuit
// kit's own transistor on the other, so the one question this mechanism lives
// or dies by can be asked at a glance - at spread 0, are those the same part?
// If a learner has to be told they are, the explosion explains a model rather
// than the thing on the board.
//
// Keys: E come apart / go back together · X ghost the epoxy · F walk the
// teaching order · 0 reset everything and the camera. Camera as everywhere
// else: right-drag turns, middle drags, wheel zooms, Space+left pans.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import ".."
import "../../circuit"

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: root.forceActiveFocus()

    // Where the focus walk stands: -1 is "nothing focused", and the walk ends
    // back there rather than looping straight into part one, so there is always
    // a press that gives the whole part back.
    property int focusAt: -1

    function toggleSpread() { assembly.spread = assembly.spread > 0.5 ? 0 : 1 }
    function toggleXray() { assembly.xray = assembly.xray > 0.5 ? 0 : 1 }

    function cycleFocus() {
        const ids = assembly.idsInOrder()
        root.focusAt = root.focusAt + 1
        if (root.focusAt >= ids.length) {
            root.focusAt = -1
            assembly.focus = ""
        } else {
            assembly.focus = ids[root.focusAt]
        }
    }

    function resetAll() {
        assembly.spread = 0
        assembly.xray = 0
        assembly.focus = ""
        root.focusAt = -1
        rig.applyState({ yaw: 20, pitch: 28, distance: 26, px: 0, py: 3, pz: 0 })
    }

    // The bench's verification seam: goals, the interpolant, and where every
    // part's anchor actually is. `at` is what a claim about the picture is
    // checked against - a slab said to be above another one is two numbers, not
    // a screenshot.
    function report() {
        const ids = assembly.partIds
        const at = {}
        for (let i = 0; i < ids.length; ++i) {
            const p = assembly.partAt(ids[i])
            at[ids[i]] = [p.x, p.y, p.z]
        }
        return {
            spread: assembly.spread, spreadNow: assembly.spreadNow,
            xray: assembly.xray, xrayNow: assembly.xrayNow,
            focus: assembly.focus, animating: assembly.animating,
            partIds: ids, order: assembly.idsInOrder(), at: at
        }
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

        // Close enough to read a 0.2-unit slab, which is what the near plane
        // has to be told about: the default is 10 units and a part 4 across
        // vanishes into it long before the camera is near enough to see the die.
        OrbitCamera3D {
            id: rig
            view: view3d
            pivot: Qt.vector3d(0, 3, 0)
            homePivot: Qt.vector3d(0, 3, 0)
            yaw: 20; pitch: 28; distance: 26
            minDistance: 3; maxDistance: 120
            minHeight: 0.5
            Component.onCompleted: rig.camera.clipNear = 0.5
        }
        CameraAnchorMark { pointer: nav }

        TransistorAnatomy3D {
            id: assembly
            position: Qt.vector3d(0, 0, 0)
        }

        // The reference part, untouched, beside it. Not decoration: this is the
        // control the anatomy is judged against, and it has to be the real
        // component rather than a copy of it - a copy would drift silently the
        // next time the circuit kit's transistor is retouched.
        CircuitElement3D {
            type: "transistor"
            position: Qt.vector3d(14, 0, 0)
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(210)
        title: "EXPLODE BENCH"
        tag: "1"

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
            label: assembly.spread > 0.5 ? "put it back  (E)" : "come apart   (E)"
            active: assembly.spread > 0.5
            onHit: root.toggleSpread()
        }
        BenchButton {
            label: assembly.xray > 0.5 ? "solid epoxy  (X)" : "ghost epoxy  (X)"
            active: assembly.xray > 0.5
            onHit: root.toggleXray()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "focus: " + (assembly.focus === "" ? "-" : assembly.focus) + " (F)"
            active: assembly.focus !== ""
            onHit: root.cycleFocus()
        }
        BenchButton {
            label: "reset everything (0)"
            onHit: root.resetAll()
        }
    }

    // What the mechanism is doing, in numbers. Three of the eight taught parts,
    // because the one thing a reader has to be able to check by eye is that the
    // die comes apart in the right order.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(200)
        title: "STATE"
        Text {
            readonly property vector3d pc: assembly.partAt("die.collector")
            readonly property vector3d pb: assembly.partAt("die.base")
            readonly property vector3d pe: assembly.partAt("die.emitter")
            text: "spread    " + assembly.spread.toFixed(2)
                + "\nspreadNow " + assembly.spreadNow.toFixed(3)
                + "\nxray      " + assembly.xray.toFixed(2)
                + "\nmoving    " + assembly.animating
                + "\nfocus     " + (assembly.focus === "" ? "-" : assembly.focus)
                + "\nparts     " + assembly.partIds.length
                + "\ndie.coll  " + pc.x.toFixed(2) + " " + pc.y.toFixed(2) + " " + pc.z.toFixed(2)
                + "\ndie.base  " + pb.x.toFixed(2) + " " + pb.y.toFixed(2) + " " + pb.z.toFixed(2)
                + "\ndie.emit  " + pe.x.toFixed(2) + " " + pe.y.toFixed(2) + " " + pe.z.toFixed(2)
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // Keeping your place across a reload - the loader captures this from the
    // outgoing root and applies it to the new one, so editing a slab's
    // thickness does not throw away the pose you were judging it from.
    function viewState() {
        return { spread: assembly.spread, xray: assembly.xray,
                 focusAt: root.focusAt, cam: rig.state() }
    }

    function applyViewState(s) {
        if (!s) return
        if (s.spread !== undefined) assembly.spread = s.spread
        if (s.xray !== undefined) assembly.xray = s.xray
        if (s.cam) rig.applyState(s.cam)
        if (s.focusAt !== undefined) {
            root.focusAt = s.focusAt - 1
            root.cycleFocus()
        }
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        keys: [
            { key: "E", label: "come apart / go back together",
              action: () => root.toggleSpread() },
            { key: "X", label: "ghost the epoxy / make it solid",
              action: () => root.toggleXray() },
            { key: "F", label: "focus the next part in teaching order",
              action: () => root.cycleFocus() }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    // 0 is the bench's own, not a LabKeys entry: LabKeys only dispatches
    // LETTERS to a lab, and the digit is already the camera's reset - which is
    // half of what "reset" has to mean here, so the bench does both and keeps
    // the key.
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_0 && !(ev.modifiers & Qt.ControlModifier)) {
            root.resetAll()
            ev.accepted = true
            return
        }
        keymap.handle(ev)
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
