// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PointBench - a throwaway rig for looking at the professor's gestures. One
// professor, a ground plane and six markers in places that break a naive
// aim: hard left, hard right, high up and behind, a pebble at the feet,
// straight overhead and dead behind.
//
//   clayrender labs/kits/professor/PointBench.qml --size 1000x800 \
//       --eval 'pointAt("high"); look("side")' \
//       --wait-for 'prof.settled' --out /tmp/a.png
//
// aimError() reports, in degrees, how far the finger line misses the
// marker - a number to check when a screenshot is merely plausible.
// presentReport() does the same job for the open-hand "present": where the
// hand sits between waist and chest, and how far the elbow is bent.
//
// It drives the REAL professor through its public verbs (pointAt, presentAt,
// stopGesture), not a gesture driver of its own, so what it measures is what
// a lab gets. The professor is scaled up to the bench: height3d is nominal
// (see the kit README), and 8.4 stands the figure about eleven units tall,
// the height the markers were placed for.
//
// The gesture is solved in the character's frame, so the verbs wait until
// the professor has finished growing out of its puff: a point asked for
// while the body is still at half scale would be solved against a target
// twice as far away. `ready` says when; pointAt()/presentAt() queue until it.

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
        "behind": Qt.vector3d(0, 4, -18),
        // Board height, off to one side: what a present is for.
        "board":  Qt.vector3d(5, 1.2, 7)
    })

    property string picked: ""

    // Sampled rather than bound: aimError() reads scene positions, which
    // change without notifying, so a binding would show the pose at t=0.
    property string status: "released"

    // Camera presets, so the same pose can be judged from more than one side.
    property real camYaw: 0
    property real camPitch: 18
    property real camDist: 34

    /*! True once the professor stands at full size and can be asked to gesture. */
    property bool ready: false
    property var _queued: null

    Component.onCompleted: prof.appear()

    Timer {
        // appear() takes 90 + 380 ms; the overshoot has died down by then.
        interval: 700
        running: true
        onTriggered: {
            root.ready = true
            if (root._queued) { root._queued(); root._queued = null }
        }
    }

    function _when(fn) {
        if (root.ready) fn()
        else root._queued = fn
    }

    /*! Point at one of the markers by name, or at nothing when name is "". */
    function pointAt(name) {
        root._when(function () {
            root.picked = name === undefined ? "" : name
            if (root.picked === "") prof.stopGesture()
            else prof.pointAt(root.markers[root.picked])
        })
    }

    /*! Offer an open hand toward one of the markers by name. */
    function presentAt(name) {
        root._when(function () {
            root.picked = name === undefined ? "" : name
            if (root.picked === "") prof.stopGesture()
            else prof.presentAt(root.markers[root.picked])
        })
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
        if (prof.gestureHand === "" || root.picked === "")
            return -1
        const a = root._finger()
        const b = root.markers[root.picked].minus(root._shoulder()).normalized()
        const d = Math.max(-1, Math.min(1, a.dotProduct(b)))
        return Math.acos(d) * 180 / Math.PI
    }

    /*! How far the busy arm's elbow is bent, in degrees; 0 is straight. */
    function elbowBend() {
        if (prof.gestureHand === "")
            return 0
        return Math.abs(root._arm().lowerArm.eulerRotation.x)
    }

    /*! One line summarising the pose, for --eval to print. */
    function report() {
        return root.picked + " " + prof.gesture + " hand=" + prof.gestureHand
             + " err=" + root.aimError().toFixed(1) + "deg"
             + " elbow=" + root.elbowBend().toFixed(1) + "deg"
             + " yaw=" + (prof.heading + prof.character.eulerRotation.y).toFixed(1)
    }

    /*!
        Where the offered hand sits, as heights above the professor's feet
        next to the two it should sit between: waist (top of the hip) and
        chest (the shoulder joint). Plus the elbow bend.
    */
    function presentReport() {
        const c = prof.character
        const feet = c.scenePosition.y
        const sy = c.scale.y
        const wrist = root._arm().hand.scenePosition.y - feet
        const palm = root._arm().hand.mapPositionToScene(
                         Qt.vector3d(0, -c.handHeight * 0.5, 0)).y - feet
        return root.picked + " " + prof.gesture + " hand=" + prof.gestureHand
             + " wrist=" + wrist.toFixed(2)
             + " palm=" + palm.toFixed(2)
             + " waist=" + (c.torso.basePos.y * sy).toFixed(2)
             + " chest=" + (c.rightShoulderPos.y * sy).toFixed(2)
             + " height=" + (c.height * sy).toFixed(2)
             + " elbow=" + root.elbowBend().toFixed(1) + "deg"
             + " headYaw=" + c.head.eulerRotation.y.toFixed(1)
             + " bodyYaw=" + (prof.heading + c.eulerRotation.y).toFixed(1)
    }

    /*! Stand the professor somewhere else, facing somewhere else. */
    function place(x, z, yaw) {
        prof.stand = Qt.vector3d(x, 0, z)
        prof.heading = yaw
    }

    /*! Largest angle left anywhere in the driven joints - 0 is a clean idle. */
    function residual() {
        const c = prof.character
        const joints = [c.head,
                        c.rightArm.upperArm, c.rightArm.lowerArm, c.rightArm.hand,
                        c.leftArm.upperArm, c.leftArm.lowerArm, c.leftArm.hand]
        // The gesture turns the character INSIDE the professor; the
        // professor's own heading is untouched, so rest is zero here.
        let worst = Math.abs(c.eulerRotation.y)
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
            if (prof.gesture !== "")
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
        interval: prof.character.gestureSettleMs + 200
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
        interval: prof.character.gestureSettleMs + 250
        onTriggered: root.stressDone = true
    }

    function _arm() {
        return prof.gestureHand === "right" ? prof.character.rightArm
                                            : prof.character.leftArm
    }
    function _shoulder() { return root._arm().upperArm.scenePosition }

    // Where the finger actually ends, taken from the hand's own transform
    // rather than from the angles the gesture layer believes it asked for.
    // indexTip is the extended index finger on an articulated hand and the
    // far face of the box on a plain one - and the two differ by about a
    // degree over this arm, because the finger sits off the hand's axis and
    // the gesture layer aims the FINGER. Measuring the hand's axis instead
    // reports that correction as an error.
    function _tip() {
        const arm = root._arm()
        return arm.hand.mapPositionToScene(arm.indexTip)
    }

    function _finger() {
        return root._tip().minus(root._arm().upperArm.scenePosition).normalized()
    }

    // A dotted beam leaving the fingertip along the direction the hand
    // really has, stopping at the marker's distance. It lands on the
    // marker exactly when the arm aims where it was told to.
    function _sample() {
        root.status = prof.gesture === "present" && root.picked !== ""
                      ? root.presentReport()
                      : prof.gesture !== "" && root.picked !== ""
                      ? root.report()
                      : "released residual=" + root.residual().toFixed(2) + "deg"
        // The beam is a point's: a present offers the hand, it aims nothing.
        if (prof.gesture !== "point" || prof.gestureHand === "" || root.picked === "") {
            root.rayVisible = false
            return
        }
        const tip = root._tip()
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
        // Named, or the professor's bubble cannot find it and falls back to
        // world sizing with a warning.
        camera: cam

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
                id: cam
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

        Professor {
            id: prof
            view: view
            height3d: 8.4
            stand: Qt.vector3d(0, 0, 0)
        }

        Repeater3D {
            model: ["left", "right", "high", "feet", "over", "behind", "board"]

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
