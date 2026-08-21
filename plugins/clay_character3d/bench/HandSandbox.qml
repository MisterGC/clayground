// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief A rig for looking at one hand very closely, at both levels of detail
// @tags 3D, Character, Hand, Bench
// @category Plugin Benchmarks
//
// HandSandbox - the bench DetailedHand is developed against.
//
// A hand is the one part of these characters that is judged from two distances
// at once. Close up it has to look like a hand; from across a room it only has
// to keep the silhouette of the gesture, and the ten extra boxes it costs are
// wasted. So this bench always shows BOTH: the plain single-box Hand on the
// left, the articulated one on the right, same character, same pose, same
// light. A change that improves the close-up and destroys the far read is
// visible here in one frame instead of two sessions apart.
//
// There are two ways to drive it, and both are needed. raise()/setPose() hold
// the arm and the hand still, which is the only way to look at a shape; play()
// runs the real gesture through GestureAnim, which is the only way to see the
// shape the hand is actually shipped in - aimed, wrist-rolled, and settling.
//
//   claydojo --sbx plugins/clay_character3d/bench/HandSandbox.qml
//
//   clayrender plugins/clay_character3d/bench/HandSandbox.qml --size 900x700 \
//       --eval 'raise("point"); setPose("point"); look("hand")' \
//       --out /tmp/a.png
//
//   clayrender plugins/clay_character3d/bench/HandSandbox.qml --size 900x700 \
//       --eval 'play("point"); look("hand")' --settle --out /tmp/b.png
//
// The readout is the point of the distance test: figurePx is how tall the
// figure lands on screen and fingerPx how long the extended index is on the
// same screen. "Still readable at 200 px" is a claim those two numbers can be
// checked against instead of an impression. Under a point it also prints how
// far the finger misses the marker by.

import QtQuick
import QtQuick3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- what is on screen ----------------------------------------------------

    /*! Which pose both hands hold: relax, open, point, thumbsUp or fist. */
    property string pose: "relax"

    /*! Which shape the arms are held in: down, level, point, high or clear. */
    property string armPose: "clear"

    /*! Show the plain-hand character beside the articulated one. */
    property bool compare: true

    /*!
        Strip the scene back to shapes on a flat ground: no lights, no grid,
        everything in one ink. What is left is the outline - the thing that has
        to survive the distance the figure is actually seen from.
    */
    property bool silhouette: false

    /*! Uniform scale on both characters, for the small-on-screen tests. */
    property real figureScale: 1.0

    /*!
        Which figure the close-up presets frame and the readout measures: the
        articulated hand by default, the plain box with subject("plain"). The
        plain one needs looking at too - it is what an Auto detail switch pops
        to, and a switch is only invisible if both sides of it are right.
    */
    property var subject: high

    function setSubject(which) {
        root.subject = (which === "plain" || which === "low") ? low : high
        root._trackPivot()
    }

    // --- camera ---------------------------------------------------------------

    property real camYaw: 35
    property real camPitch: 8
    property real camDist: 2.0
    property vector3d camPivot: Qt.vector3d(0, 6, 0)
    property bool camOnHand: true

    /*!
        Move the camera to a named viewpoint. The hand presets re-centre on the
        right hand wherever the current arm pose has put it, so a close-up stays
        a close-up after raise().
    */
    function look(preset) {
        if (preset === "hand")          { root.camYaw = 35;  root.camPitch = 8;  root.camDist = 2.0 }
        else if (preset === "handSide") { root.camYaw = 110; root.camPitch = 6;  root.camDist = 2.0 }
        else if (preset === "handTop")  { root.camYaw = 20;  root.camPitch = 55; root.camDist = 2.0 }
        else if (preset === "handBack") { root.camYaw = 200; root.camPitch = 8;  root.camDist = 2.0 }
        else if (preset === "handPalm") { root.camYaw = 350; root.camPitch = -8; root.camDist = 2.0 }
        else if (preset === "body")     { root.camYaw = 32;  root.camPitch = 8;  root.camDist = 22 }
        else if (preset === "bodySide") { root.camYaw = 92;  root.camPitch = 6;  root.camDist = 22 }
        // The working distance the component has to survive: the figure lands
        // around 200 px tall in a 700 px frame.
        else if (preset === "work")     { root.camYaw = 32;  root.camPitch = 6;  root.camDist = 36 }
        else if (preset === "far")      { root.camYaw = 32;  root.camPitch = 5;  root.camDist = 70 }
        else return

        root.viewpoint = preset
        root.camOnHand = preset.indexOf("hand") === 0
        root._trackPivot()
    }

    property string viewpoint: "hand"

    // The hand moves when the arm pose does, and scenePosition does not notify,
    // so the pivot is sampled rather than bound - otherwise every close-up
    // would frame wherever the hand was at load time. Half a palm below the
    // wrist joint, because the hand hangs off the joint rather than sitting on
    // it and framing the joint puts the fingers at the bottom of the picture.
    function _trackPivot() {
        root.camPivot = root.camOnHand
                      ? root.subject.rightArm.hand.mapPositionToScene(
                            Qt.vector3d(0, -root.subject.rightArm.handHeight * 0.6, 0))
                      : Qt.vector3d(root.compare ? 0 : root.subject.basePos.x,
                                    root.subject.height * root.subject.scale.y * 0.55, 0)
    }

    // --- gestures ---------------------------------------------------------------
    //
    // The other half of the bench. raise()/setPose() are a vice - they hold the
    // hand still so it can be looked at - but nothing ships a hand in a vice.
    // What ships is a gesture: GestureAnim aims the arm, picks the hand pose
    // and rolls the wrist, and a hand that only ever looked right in the vice
    // is a hand that has not been checked. thumbsUp in particular is not a hand
    // pose at all until the wrist roll arrives, and the roll only comes from
    // here.
    //
    // A gesture owns the same joints the vice writes, so the two cannot both be
    // on: asking for one drops the other.

    /*! "" while the arms are posed by hand, otherwise the gesture being held. */
    property string gesture: ""

    /*! "point", "thumbsUp" or "talk". Anything else stops the gesture. */
    function play(name) {
        if (name !== "point" && name !== "thumbsUp" && name !== "talk") {
            root.stop()
            return
        }
        root.gesture = name
        for (const c of [high, low]) {
            if (name === "point") c.pointAt(root.aimFor(c), "right")
            else if (name === "thumbsUp") c.thumbsUp("right")
            else c.gesticulate()
        }
    }

    /*! Drop the gesture and go back to the posed arms. */
    function stop() {
        root.gesture = ""
        for (const c of [high, low])
            c.stopGesture()
        root._applyArm()
    }

    /*!
        Where a point aims, as an offset from the character's own feet rather
        than a place in the room. The two figures stand apart, and one shared
        target would turn them by different amounts and pose their arms
        differently - which is the one thing a side-by-side comparison must not
        do. Each gets its own marker at the same offset instead.
    */
    property vector3d aimOffset: Qt.vector3d(-5, 9, 7)

    function aimFor(c) { return c.scenePosition.plus(root.aimOffset) }

    function aimAt(x, y, z) {
        root.aimOffset = Qt.vector3d(x, y, z)
        if (root.gesture === "point")
            root.play("point")
    }

    // --- the arms -------------------------------------------------------------
    // Held by direct assignment rather than by an animation: the idle animation
    // owns the same joints and runs once at startup, so the pose has to be
    // written again after it has finished.

    /*! "down", "level", "point" (raised, bent elbow), "high" or "clear". */
    function raise(name) {
        root.armPose = name
        root.stop()
    }

    function _applyArm() {
        if (root.gesture !== "")
            return
        let upper = Qt.vector3d(0, 0, 0)
        let elbow = Qt.vector3d(0, 0, 0)
        let wrist = Qt.vector3d(0, 0, 0)
        if (root.armPose === "point") {
            upper = Qt.vector3d(-50, 0, 15); elbow = Qt.vector3d(-70, 0, 0); wrist = Qt.vector3d(-10, 0, 0)
        } else if (root.armPose === "high") {
            upper = Qt.vector3d(-38, 0, 12); elbow = Qt.vector3d(-92, 0, 0); wrist = Qt.vector3d(-14, 0, 0)
        } else if (root.armPose === "level") {
            upper = Qt.vector3d(-14, 0, 10); elbow = Qt.vector3d(-76, 0, 0); wrist = Qt.vector3d(0, 0, 0)
        } else if (root.armPose === "clear") {
            // Nothing anatomical about this one - it holds the hand out clear
            // of the torso and the head so a close-up has only the hand in it.
            upper = Qt.vector3d(-58, 0, 72); elbow = Qt.vector3d(-30, 0, 0); wrist = Qt.vector3d(0, 0, 0)
        }
        for (const c of [high, low]) {
            c.rightArm.upperArm.eulerRotation = upper
            c.rightArm.lowerArm.eulerRotation = elbow
            c.rightArm.hand.eulerRotation = wrist
            // The left arm stays down: with both arms up a close-up of one hand
            // has the other one in the background of it.
            c.leftArm.upperArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.lowerArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.hand.eulerRotation = Qt.vector3d(0, 0, 0)
        }
    }

    // Re-applied on a tick rather than once: the idle animation owns the same
    // joints, runs itself after load and would zero anything --eval set before
    // it got there. Writing the same numbers again costs nothing.
    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            root._applyArm()
            root._trackPivot()
            root.status = root.report()
        }
    }

    // --- what the hands are doing ---------------------------------------------

    /*! "relax", "open", "point", "thumbsUp" or "fist". */
    function setPose(name) { root.pose = name }

    function nextPose() {
        const all = ["relax", "open", "point", "thumbsUp", "fist"]
        root.pose = all[(all.indexOf(root.pose) + 1) % all.length]
    }

    /*! Shrink both figures; the fingers have to come with them. */
    function scaleTo(s) { root.figureScale = s }

    function setSilhouette(on) { root.silhouette = on }

    function setCompare(on) { root.compare = on; root._trackPivot() }

    // --- measurements ----------------------------------------------------------

    readonly property real _spread: 8

    readonly property real figureHeight: root.subject.height * root.subject.scale.y

    /*! Apparent height of the whole figure, in screen pixels. */
    function figurePx() {
        const foot = view.mapFrom3DScene(root.subject.scenePosition)
        const top = view.mapFrom3DScene(root.subject.scenePosition.plus(
                                            Qt.vector3d(0, root.figureHeight, 0)))
        return Math.abs(top.y - foot.y)
    }

    /*! Apparent length of the extended index finger, in the same pixels. */
    function fingerPx() {
        const h = root.subject.rightArm.hand
        const tip = root.subject.rightArm.indexTip
        const a = view.mapFrom3DScene(h.mapPositionToScene(Qt.vector3d(0, 0, 0)))
        const b = view.mapFrom3DScene(h.mapPositionToScene(tip))
        return Math.hypot(b.x - a.x, b.y - a.y)
    }

    /*!
        How far the extended index misses the marker by, in degrees - the angle
        between where the finger is aimed and where the thing actually is.
        Meaningless unless a point is being held.
    */
    function aimErrorDeg() {
        const h = root.subject.rightArm.hand
        const from = h.mapPositionToScene(Qt.vector3d(0, 0, 0))
        const along = h.mapPositionToScene(root.subject.rightArm.indexTip).minus(from)
        const toIt = root.aimFor(root.subject).minus(from)
        const denom = along.length() * toIt.length()
        if (denom < 1e-6)
            return 0
        return Math.acos(Math.max(-1, Math.min(1, along.dotProduct(toIt) / denom)))
             * 180 / Math.PI
    }

    /*! One line for --eval to print, and for the corner of every render. */
    function report() {
        // Character.handPose is only what the hand falls back to. While a
        // gesture holds it the arm's own handPose is the one on screen, and
        // printing the fallback instead is how a pose gets "fixed" twice.
        const held = root.subject.rightArm.handPose
        return (root.subject === low ? "plain  " : "")
             + (root.gesture !== "" ? "gesture " + root.gesture
                                    : root.armPose + "/" + root.pose)
             + " -> " + held
             + "  " + root.viewpoint
             + "  figure=" + root.figurePx().toFixed(0) + "px"
             + "  wrist-to-fingertip=" + root.fingerPx().toFixed(0) + "px"
             + (root.gesture === "point"
                    ? "  aim off by " + root.aimErrorDeg().toFixed(1) + " deg"
                    : "")
    }

    property string status: ""

    Component.onCompleted: {
        root._applyArm()
        root.look("hand")
    }

    // --- keys -------------------------------------------------------------------

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space) root.nextPose()
        else if (e.key === Qt.Key_1) root.look("hand")
        else if (e.key === Qt.Key_2) root.look("handSide")
        else if (e.key === Qt.Key_3) root.look("handTop")
        else if (e.key === Qt.Key_4) root.look("handBack")
        else if (e.key === Qt.Key_5) root.look("handPalm")
        else if (e.key === Qt.Key_6) root.look("body")
        else if (e.key === Qt.Key_7) root.look("work")
        else if (e.key === Qt.Key_8) root.look("far")
        else if (e.key === Qt.Key_P) root.play("point")
        else if (e.key === Qt.Key_O) root.play("thumbsUp")
        else if (e.key === Qt.Key_I) root.play("talk")
        else if (e.key === Qt.Key_X) root.stop()
        else if (e.key === Qt.Key_C) root.setCompare(!root.compare)
        else if (e.key === Qt.Key_D) root.setSubject(root.subject === high ? "plain" : "high")
        else if (e.key === Qt.Key_S) root.setSilhouette(!root.silhouette)
        else if (e.key === Qt.Key_A) {
            const all = ["clear", "point", "high", "level", "down"]
            root.raise(all[(all.indexOf(root.armPose) + 1) % all.length])
        }
        else if (e.key === Qt.Key_Q) root.camYaw -= 10
        else if (e.key === Qt.Key_E) root.camYaw += 10
        else if (e.key === Qt.Key_R) root.camPitch = Math.min(85, root.camPitch + 5)
        else if (e.key === Qt.Key_F) root.camPitch = Math.max(-85, root.camPitch - 5)
        else if (e.key === Qt.Key_T) root.camDist = Math.max(0.4, root.camDist * 0.8)
        else if (e.key === Qt.Key_G) root.camDist = Math.min(200, root.camDist * 1.25)
        else return
        e.accepted = true
    }

    // --- the scene ----------------------------------------------------------------

    component Figure: ParametricCharacter {
        bodyHeight: 10
        realism: 0.0
        maturity: 0.15
        mass: 0.55
        muscle: 0.3
        femininity: 0.2
        scale: Qt.vector3d(root.figureScale, root.figureScale, root.figureScale)
        handPose: root.pose
        activity: Character.Activity.Idle

        // One ink in silhouette mode: a two-tone figure hands the eye an inner
        // edge to read the shape by, which is exactly what is not available at
        // the distance this mode exists to test.
        skinColor: root.silhouette ? "#1b1b1f" : "#d38d5f"
        handColor: root.silhouette ? "#1b1b1f" : "#d38d5f"
        footColor: root.silhouette ? "#1b1b1f" : "#b5764a"
        eyeColor: root.silhouette ? "#1b1b1f" : "#ffffff"
        hairColor: root.silhouette ? "#1b1b1f" : "#5c3a21"
        torsoColor: root.silhouette ? "#1b1b1f" : "#3663c8"
        armColor: root.silhouette ? "#1b1b1f" : "#3663c8"
        hipColor: root.silhouette ? "#1b1b1f" : "#5a6b7d"
        legColor: root.silhouette ? "#1b1b1f" : "#5a6b7d"
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: root.silhouette ? "#f4f2ee" : "#f0f0f0"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Four is the hard maximum for directional lights, so silhouette mode
        // cannot add a light of its own: the key one flattens to pure ambient
        // instead and the other three go out.
        DirectionalLight {
            eulerRotation.x: -40
            eulerRotation.y: -45
            castsShadow: !root.silhouette
            shadowFactor: 75
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            softShadowQuality: Light.PCF16
            pcfFactor: 2
            shadowBias: 5
            shadowMapFar: 200
            brightness: root.silhouette ? 0.0 : 0.9
            ambientColor: root.silhouette ? Qt.rgba(1, 1, 1, 1)
                                          : Qt.rgba(0.55, 0.55, 0.6, 1.0)
        }

        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: 180
            visible: !root.silhouette
            brightness: 0.5
        }

        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: 90
            visible: !root.silhouette
            brightness: 0.35
        }

        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: -90
            visible: !root.silhouette
            brightness: 0.35
        }

        Node {
            position: root.camPivot
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)

            PerspectiveCamera {
                id: cam
                z: root.camDist
                // The default near plane is 10 units out, which is further than
                // the whole close-up rig - without this every hand preset
                // renders an empty room.
                clipNear: 0.05
                clipFar: 800
            }
        }

        Model {
            source: "#Rectangle"
            visible: !root.silhouette
            eulerRotation.x: -90
            scale: Qt.vector3d(4, 4, 1)
            materials: PrincipledMaterial {
                baseColor: "#e8e6e1"
                roughness: 0.9
            }
        }

        // What a point is aimed at. Visible, because "the finger is on it" is
        // the only way to read an aim error that the number cannot show you -
        // the number says how far off, the marker says which way.
        component Marker: Model {
            source: "#Sphere"
            visible: root.gesture === "point"
            scale: Qt.vector3d(0.006, 0.006, 0.006)
            materials: PrincipledMaterial {
                baseColor: "#c0392b"
                lighting: PrincipledMaterial.NoLighting
            }
        }

        Marker { position: root.aimFor(high) }
        Marker {
            position: root.aimFor(low)
            visible: low.visible && root.gesture === "point"
        }

        // The one under the microscope.
        Figure {
            id: high
            name: "articulated"
            // basePos, not x: BodyPart binds position to basePos, so an x of
            // its own is overwritten the moment anything re-evaluates. Fixed
            // rather than re-centred when the other figure is hidden - a
            // close-up that shifts sideways the moment compare goes off is a
            // close-up you cannot compare two renders of.
            basePos: Qt.vector3d(-root._spread * 0.5, 0, 0)
            detailedHands: true
        }

        // The same character with the plain box hand, for the far read. Off to
        // the side rather than behind: at the working distance the two have to
        // be comparable in one glance, not one after the other.
        Figure {
            id: low
            name: "plain"
            basePos: Qt.vector3d(root._spread * 0.5, 0, 0)
            visible: root.compare || root.subject === low
            detailedHands: false
        }
    }

    // --- readout --------------------------------------------------------------

    Text {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        color: "#1b1b1f"
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 13
        text: root.status
        visible: !root.silhouette
    }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
        color: "#6b6b72"
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 11
        visible: !root.silhouette
        text: "space pose   a arm   p/o/i point,thumbsUp,talk   x stop   "
            + "1-5 hand views   6-8 body/work/far   c compare   "
            + "s silhouette   qerf/tg camera"
    }
}
