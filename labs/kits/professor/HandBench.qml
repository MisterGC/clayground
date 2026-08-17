// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// HandBench - a throwaway rig for looking at DetailedHand. One character on
// the standard lab ground, both hands fitted, a fixed camera with named
// viewpoints and an arm held in the pose the whole component exists for: a
// bent-elbow point at something high and forward.
//
//   clayrender labs/kits/professor/HandBench.qml --size 900x700 \
//       --eval 'raise("point"); setPose("point"); look("hand")' \
//       --settle --out /tmp/a.png
//
// The readout is the point of the distance test: figurePx is how tall the
// figure lands on screen and fingerPx how long the extended index is on the
// same screen. "Still readable at 200 px" is a claim those two numbers can be
// checked against instead of an impression.

import QtQuick
import QtQuick3D
import Clayground.Character3D
import Clayground.Lab

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent

    // --- camera ---------------------------------------------------------------

    property real camYaw: 32
    property real camPitch: 10
    property real camDist: 6
    property vector3d camPivot: Qt.vector3d(0, 6, 0)
    property bool camOnHand: true

    /*!
        Move the fixed camera to a named viewpoint. The three "hand*" presets
        re-centre on the hand wherever the current arm pose has put it, so a
        close-up stays a close-up after raise().
    */
    function look(preset) {
        if (preset === "hand") { root.camYaw = 35; root.camPitch = 8; root.camDist = 3.4 }
        else if (preset === "handSide") { root.camYaw = 100; root.camPitch = 6; root.camDist = 3.4 }
        else if (preset === "handTop") { root.camYaw = 20; root.camPitch = 52; root.camDist = 3.4 }
        else if (preset === "handBack") { root.camYaw = 190; root.camPitch = 8; root.camDist = 3.4 }
        else if (preset === "body") { root.camYaw = 32; root.camPitch = 8; root.camDist = 22 }
        else if (preset === "bodySide") { root.camYaw = 92; root.camPitch = 6; root.camDist = 22 }
        // The working distance the component has to survive: the figure lands
        // around 200 px tall in a 700 px frame.
        else if (preset === "work") { root.camYaw = 32; root.camPitch = 6; root.camDist = 36 }
        else if (preset === "workSide") { root.camYaw = 92; root.camPitch = 4; root.camDist = 36 }
        else if (preset === "far") { root.camYaw = 32; root.camPitch = 5; root.camDist = 70 }

        root.camOnHand = preset.indexOf("hand") === 0
        root._trackPivot()
    }

    // The hand moves when the arm pose does, and scenePosition does not notify,
    // so the pivot is sampled rather than bound - otherwise every close-up
    // would frame wherever the hand was at load time.
    function _trackPivot() {
        root.camPivot = root.camOnHand
                      ? char.rightArm.hand.scenePosition
                      : Qt.vector3d(0, root.figureHeight * 0.55, 0)
    }

    // --- the arm --------------------------------------------------------------
    // Held by direct assignment rather than by an animation: the idle animation
    // owns the same joints and runs once at startup, so the pose is written
    // again after it has finished.

    property string armPose: "point"

    /*! "point" (raised, bent elbow), "high", "level" (for thumbsUp) or "down". */
    function raise(name) {
        root.armPose = name
        root._applyArm()
        settleArm.restart()
    }

    function _applyArm() {
        let upper = Qt.vector3d(0, 0, 0)
        let elbow = Qt.vector3d(0, 0, 0)
        let wrist = Qt.vector3d(0, 0, 0)
        if (root.armPose === "point") {
            upper = Qt.vector3d(-50, 0, 15); elbow = Qt.vector3d(-70, 0, 0); wrist = Qt.vector3d(-10, 0, 0)
        } else if (root.armPose === "high") {
            upper = Qt.vector3d(-38, 0, 12); elbow = Qt.vector3d(-92, 0, 0); wrist = Qt.vector3d(-14, 0, 0)
        } else if (root.armPose === "level") {
            upper = Qt.vector3d(-14, 0, 10); elbow = Qt.vector3d(-76, 0, 0); wrist = Qt.vector3d(0, 0, 0)
        }
        char.rightArm.upperArm.eulerRotation = upper
        char.rightArm.lowerArm.eulerRotation = elbow
        char.rightArm.hand.eulerRotation = wrist
        // Mirrored on the other side: the side swing is the only component
        // that has to change sign.
        char.leftArm.upperArm.eulerRotation = Qt.vector3d(upper.x, upper.y, -upper.z)
        char.leftArm.lowerArm.eulerRotation = elbow
        char.leftArm.hand.eulerRotation = wrist
    }

    // Re-applied on a tick rather than once: the idle animation owns the same
    // joints, runs itself once after load and would zero anything --eval set
    // before it got there. Writing the same numbers again costs nothing.
    Timer {
        id: settleArm
        interval: 120
        repeat: true
        running: true
        onTriggered: root._applyArm()
    }

    // --- what the hands are doing ---------------------------------------------

    /*! "relax", "point", "thumbsUp" or "open", on both hands. */
    function setPose(name) {
        rightHand.pose = name
        leftHand.pose = name
    }

    /*! Prove the component copes with no arm: nothing drawn, nothing logged. */
    function detach() {
        rightHand.arm = null
        leftHand.arm = null
    }

    function attach() {
        rightHand.arm = char.rightArm
        leftHand.arm = char.leftArm
    }

    /*! Shrink the whole character; the fingers have to come with it. */
    function scaleTo(s) {
        char.scale = Qt.vector3d(s, s, s)
    }

    /*!
        Strip the scene back to shapes on a flat ground: no lights, no grid,
        everything in one ink. What is left is the outline, which is the thing
        that must not read as a salute.
    */
    function setSilhouette(on) {
        root.silhouette = on
    }

    property bool silhouette: false

    // --- measurements ----------------------------------------------------------

    readonly property real figureHeight: char.height * char.scale.y

    /*! Apparent height of the whole figure, in screen pixels. */
    function figurePx() {
        const foot = view.mapFrom3DScene(char.scenePosition)
        const top = view.mapFrom3DScene(char.scenePosition.plus(
                                            Qt.vector3d(0, root.figureHeight, 0)))
        return Math.abs(top.y - foot.y)
    }

    /*! Apparent length of the extended index finger, in the same pixels. */
    function fingerPx() {
        const h = char.rightArm.hand
        const a = view.mapFrom3DScene(h.mapPositionToScene(Qt.vector3d(0, 0, 0)))
        const b = view.mapFrom3DScene(h.mapPositionToScene(rightHand.indexTip))
        return Math.hypot(b.x - a.x, b.y - a.y)
    }

    /*! One line for --eval to print, and for the corner of every render. */
    function report() {
        return root.armPose + "/" + rightHand.pose
             + "  figure=" + root.figurePx().toFixed(0) + "px"
             + "  wrist-to-fingertip=" + root.fingerPx().toFixed(0) + "px"
    }

    property string status: ""

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            root._trackPivot()
            root.status = root.report()
        }
    }

    Component.onCompleted: {
        root._applyArm()
        root.look("hand")
    }

    // --- the scene --------------------------------------------------------------

    View3D {
        id: view
        anchors.fill: parent

        environment: stage.environment
        camera: cam

        LabStage3D {
            id: stage
            cellSize: 2
            workExtent: Qt.vector2d(40, 40)
            shadowMapFar: 120
            lightsEnabled: !root.silhouette
        }

        // In silhouette mode the ground would still be a lit sheet under an
        // unlit figure, which is exactly the contrast that hides an outline.
        Binding {
            target: stage.ground
            property: "visible"
            value: !root.silhouette
        }

        Node {
            position: root.camPivot
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)

            PerspectiveCamera {
                id: cam
                z: root.camDist
                // The default near plane is 10 units out, which is further
                // than the whole close-up rig - without this every hand
                // preset renders an empty room.
                clipNear: 0.05
                clipFar: 800
            }
        }

        ParametricCharacter {
            id: char
            name: "bench"
            bodyHeight: 10
            realism: 0.0
            maturity: 0.15
            mass: 0.55
            muscle: 0.3
            femininity: 0.2

            skinColor: root.silhouette ? LabTheme.inkSolid : LabTheme.clay
            hairColor: root.silhouette ? LabTheme.inkSolid : LabTheme.muted
            torsoColor: root.silhouette ? LabTheme.inkSolid : LabTheme.forest
            armColor: root.silhouette ? LabTheme.inkSolid : LabTheme.forest
            hipColor: root.silhouette ? LabTheme.inkSolid : LabTheme.inkFaint
            legColor: root.silhouette ? LabTheme.inkSolid : LabTheme.inkFaint

            activity: Character.Activity.Idle
        }

        DetailedHand {
            id: rightHand
            arm: char.rightArm
            tone: root.silhouette ? LabTheme.inkSolid : char.handColor
        }

        DetailedHand {
            id: leftHand
            arm: char.leftArm
            mirrored: true
            tone: root.silhouette ? LabTheme.inkSolid : char.handColor
        }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: LabTheme.spaceM
        color: LabTheme.ink
        font.family: LabTheme.monoFont
        font.pixelSize: LabTheme.fontBody
        text: root.status
        visible: !root.silhouette
    }
}
