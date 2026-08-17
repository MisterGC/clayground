// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PointBench - a throwaway rig for looking at PointAnim. One character,
// a ground plane and four markers in places that break a naive aim:
// hard left, hard right, high up and behind, and a pebble at the feet.
//
//   clayrender labs/kits/professor/PointBench.qml --size 1000x800 \
//       --eval 'pointAt("high"); look("side")' --settle --out /tmp/a.png
//
// aimError() reports, in degrees, how far the finger line misses the
// marker - a number to check when a screenshot is merely plausible.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent

    readonly property var markers: ({
        "left":  Qt.vector3d(-14, 3, 6),
        "right": Qt.vector3d(16, 5, -4),
        "high":  Qt.vector3d(-4, 18, -13),
        "feet":  Qt.vector3d(1.5, 0.6, 3),
        // The two the maths can trip over: straight overhead, where the aim
        // yaw stops being defined, and dead behind, a 180 degree turn.
        "over":   Qt.vector3d(0.4, 15, 0.2),
        "behind": Qt.vector3d(0, 4, -18)
    })

    property string picked: ""

    // Sampled rather than bound: aimError() reads scene positions, which
    // change without notifying, so a binding would show the pose at t=0.
    property string status: "released"

    // Camera presets, so the same pose can be judged from more than one side.
    property real camYaw: 0
    property real camPitch: 18
    property real camDist: 34

    /*! Point at one of the markers by name, or at nothing when name is "". */
    function pointAt(name) {
        root.picked = name === undefined ? "" : name
        point.target = root.markers[root.picked] ?? null
        point.active = root.picked !== ""
    }

    /*! Move the fixed camera to a named viewpoint. */
    function look(preset) {
        if (preset === "front") { root.camYaw = 0; root.camPitch = 14; root.camDist = 34 }
        else if (preset === "side") { root.camYaw = 80; root.camPitch = 14; root.camDist = 34 }
        else if (preset === "back") { root.camYaw = 175; root.camPitch = 14; root.camDist = 34 }
        else if (preset === "top") { root.camYaw = 35; root.camPitch = 55; root.camDist = 40 }
        else if (preset === "wide") { root.camYaw = 30; root.camPitch = 22; root.camDist = 60 }
    }

    /*! Angle in degrees between the pointing finger's line and the marker. */
    function aimError() {
        if (point.activeHand === "")
            return -1
        const a = root._finger()
        const b = root.markers[root.picked].minus(root._shoulder()).normalized()
        const d = Math.max(-1, Math.min(1, a.dotProduct(b)))
        return Math.acos(d) * 180 / Math.PI
    }

    /*! One line summarising the pose, for --eval to print. */
    function report() {
        return root.picked + " hand=" + point.activeHand
             + " err=" + root.aimError().toFixed(1) + "deg"
             + " yaw=" + prof.eulerRotation.y.toFixed(1)
    }

    /*! Stand the character somewhere else, facing somewhere else. */
    function place(x, z, yaw) {
        prof.position = Qt.vector3d(x, 0, z)
        prof.eulerRotation = Qt.vector3d(0, yaw, 0)
        root.restYaw = yaw
    }

    property real restYaw: 0

    /*! Largest angle left anywhere in the driven joints - 0 is a clean idle. */
    function residual() {
        const joints = [prof.head,
                        prof.rightArm.upperArm, prof.rightArm.lowerArm, prof.rightArm.hand,
                        prof.leftArm.upperArm, prof.leftArm.lowerArm, prof.leftArm.hand]
        let worst = Math.abs(prof.eulerRotation.y - root.restYaw)
        for (let i = 0; i < joints.length; ++i) {
            const e = joints[i].eulerRotation
            worst = Math.max(worst, Math.abs(e.x), Math.abs(e.y), Math.abs(e.z))
        }
        return worst
    }

    // Toggles the gesture faster than it can settle, which is where a
    // half-finished transition would strand a limb if it were going to.
    property bool stressDone: false
    property int _stressLeft: 0

    function stress(times) {
        root.stressDone = false
        root._stressLeft = times * 2
        stressTimer.restart()
    }

    Timer {
        id: stressTimer
        interval: 220
        repeat: true
        onTriggered: {
            if (root._stressLeft <= 0) {
                stressTimer.stop()
                root.pointAt("")
                stressTail.restart()
                return
            }
            root._stressLeft--
            if (point.active)
                root.pointAt("")
            else
                root.pointAt(["left", "right", "high", "feet"][root._stressLeft % 4])
        }
    }

    // Points at a, waits for it to land, switches to b and raises `midway`
    // atMs into the re-aim - a moment to photograph the transition in.
    property bool midway: false
    property string _reaimTo: ""

    function reaim(a, b, atMs) {
        root.midway = false
        root._reaimTo = b
        midwayTimer.interval = atMs
        root.pointAt(a)
        reaimTimer.restart()
    }

    Timer {
        id: reaimTimer
        interval: point.settleMs + 200
        onTriggered: {
            root.pointAt(root._reaimTo)
            midwayTimer.restart()
        }
    }

    Timer {
        id: midwayTimer
        interval: 150
        onTriggered: root.midway = true
    }

    Timer {
        id: stressTail
        interval: point.settleMs + 250
        onTriggered: root.stressDone = true
    }

    function _arm() { return point.activeHand === "right" ? prof.rightArm : prof.leftArm }
    function _shoulder() { return root._arm().upperArm.scenePosition }

    // Where the finger actually points, taken from the hand's own transform
    // rather than from the angles PointAnim believes it asked for.
    function _finger() {
        const arm = root._arm()
        const tip = arm.hand.mapPositionToScene(Qt.vector3d(0, -prof.handHeight, 0))
        return tip.minus(arm.upperArm.scenePosition).normalized()
    }

    // A dotted beam leaving the fingertip along the direction the hand
    // really has, stopping at the marker's distance. It lands on the
    // marker exactly when the arm aims where it was told to.
    function _sample() {
        root.status = point.pointing ? root.report()
                                     : "released residual=" + root.residual().toFixed(2) + "deg"
        if (point.activeHand === "") {
            root.rayVisible = false
            return
        }
        const arm = root._arm()
        const tip = arm.hand.mapPositionToScene(Qt.vector3d(0, -prof.handHeight, 0))
        const reach = root.markers[root.picked].minus(root._shoulder()).length()
                    - tip.minus(root._shoulder()).length()
        root.rayFrom = tip
        root.rayStep = root._finger().times(reach / root.rayDots)
        root.rayVisible = true
    }

    readonly property int rayDots: 26
    property vector3d rayFrom: Qt.vector3d(0, 0, 0)
    property vector3d rayStep: Qt.vector3d(0, 0, 0)
    property bool rayVisible: false

    View3D {
        id: view
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: LabTheme.board
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            tonemapMode: SceneEnvironment.TonemapModeNone
        }

        DirectionalLight {
            eulerRotation.x: -40
            eulerRotation.y: -45
            castsShadow: true
            shadowFactor: LabTheme.shadowFactor
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            brightness: 0.6
            ambientColor: LabTheme.ambient3d
        }

        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: 180
            castsShadow: false
            brightness: 0.5
        }

        Node {
            // Orbit rig: the camera hangs off a yaw/pitch pivot at chest
            // height so every preset frames the same body, not the feet.
            position: Qt.vector3d(0, 6, 0)
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)

            PerspectiveCamera {
                z: root.camDist
                clipFar: 500
            }
        }

        Box3D {
            id: ground
            width: 120
            depth: 120
            height: 1
            y: -1
            color: LabTheme.table
            showEdges: false
        }

        Character {
            id: prof
            name: "prof"
            skinColor: LabTheme.clay
            torsoColor: LabTheme.teal
            hipColor: LabTheme.plum
            legColor: LabTheme.plum
            armColor: LabTheme.teal
            activity: Character.Activity.Idle
        }

        Repeater3D {
            model: ["left", "right", "high", "feet", "over", "behind"]

            Model {
                id: marker
                required property string modelData
                source: "#Sphere"
                position: root.markers[marker.modelData]
                scale: Qt.vector3d(0.012, 0.012, 0.012)
                castsShadows: false
                materials: PrincipledMaterial {
                    baseColor: root.picked === marker.modelData ? LabTheme.alarm
                                                                : LabTheme.highlight
                    lighting: PrincipledMaterial.NoLighting
                }
            }
        }

        Repeater3D {
            model: root.rayDots

            Model {
                id: dot
                required property int index
                source: "#Sphere"
                visible: root.rayVisible
                position: root.rayFrom.plus(root.rayStep.times(dot.index + 1))
                scale: Qt.vector3d(0.004, 0.004, 0.004)
                castsShadows: false
                materials: PrincipledMaterial {
                    baseColor: LabTheme.secondary
                    lighting: PrincipledMaterial.NoLighting
                }
            }
        }
    }

    PointAnim {
        id: point
        character: prof
        settleMs: 450
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: root._sample()
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: LabTheme.spaceM
        color: LabTheme.ink
        font.family: LabTheme.monoFont
        font.pixelSize: LabTheme.fontBody
        text: root.status
    }
}
