// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Working and boxing, live - one figure, its cycle running, from any angle
// @tags 3D, Character, Animation, Action, Boxing
// @category Plugin Benches
//
// ActionSandbox - the two whole-body actions, Using and Fighting, the way the
// hand bench shows a hand: ONE figure, close, orbitable, and moving. The
// gesture sheet freezes the cycles as strips of stills, which is where a pose
// is judged; this is where the MOTION is judged, because a punch that snaps
// and a punch that floats freeze to the same picture.
//
//   claydojo --sbx plugins/clay_character3d/bench/ActionSandbox.qml
//
// Everything on screen comes from action.js through the shipped animators -
// the figure's activity really is Character.Activity.Fighting, so what plays
// here is what plays in a game. Pausing switches it to Idle and writes one
// frame of the same model, so the phase slider scrubs the cycle the sheet
// freezes.
//
// PROPS. The work has a table under it and the fight has a bag in front of
// it, at the height and distance the model thinks it is working at, because
// "the hands are on the work" and "the fists sit where a guard sits" are both
// claims about a relation to something, and an empty room has nothing to be
// related to. `props=false` takes them away for a silhouette read.
//
// From the command line:
//
//   clayrender plugins/clay_character3d/bench/ActionSandbox.qml --size 900x700 \
//       --set 'action="fight"' --set 'playing=false' --set 'phase=0.62' \
//       --wait-for 'posed' --out /tmp/cross.png
//
//   clayrender plugins/clay_character3d/bench/ActionSandbox.qml \
//       --set 'action="fight"' --trace 'report()' --wait-for 'posed' \
//       --set 'playing=false'
//
// report() measures the hands against the body in the figure's own frame -
// height over the shoulder in head heights, forward reach in arm lengths -
// which is what a guard or a working posture is a claim about.

import QtQuick
import QtQuick3D
import QtQuick.Controls.Basic
import Clayground.Canvas3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- what plays -----------------------------------------------------------

    /*! "fight" or "use". */
    property string action: "fight"

    /*! How hard at it, 0..1 - Character.actionIntensity. */
    property real intensity: 0.5

    /*! Where the work is, 0 waist .. 1 shoulder - Character.workHeight. */
    property real workHeight: 0.35

    /*! Running, or frozen at \l phase. */
    property bool playing: true

    /*! The phase held while not playing, 0..1. */
    property real phase: 0

    /*! True once the frozen frame is on the joints; false while playing. */
    property bool posed: false

    /*! The table under the work and the bag in front of the guard. */
    property bool props: true

    /*! Flat ink, no lights, no floor: the outline and nothing else. */
    property bool silhouette: false

    /*! Fingers or a single box for the hands. */
    property bool fingers: true

    property real bodyHeight: 10
    property real mass: 0.5
    property real muscle: 0.5

    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo"
                                     : Qt.platform.os === "windows" ? "Consolas"
                                     : "monospace"

    // --- driving it -----------------------------------------------------------

    function show(what) { root.action = what }
    function play() { root.playing = true }
    function pause() { root.playing = false }
    function scrub(t) { root.phase = t - Math.floor(t); root.playing = false }
    function step(frames) { root.scrub(root.phase + frames / 24) }
    function setIntensity(v) { root.intensity = Math.max(0, Math.min(1, v)) }
    function setWorkHeight(v) { root.workHeight = Math.max(0, Math.min(1, v)) }
    function setSilhouette(on) { root.silhouette = on }
    function setProps(on) { root.props = on }
    function setFingers(on) { root.fingers = on }

    readonly property var builds: [
        { name: "neutral", mass: 0.5, muscle: 0.5 },
        { name: "thin",    mass: 0.1, muscle: 0.2 },
        { name: "heavy",   mass: 0.9, muscle: 0.4 },
        { name: "brawny",  mass: 0.6, muscle: 1.0 }
    ]
    property int build: 0
    function nextBuild() {
        root.build = (root.build + 1) % root.builds.length
        root.mass = root.builds[root.build].mass
        root.muscle = root.builds[root.build].muscle
    }

    // The cycle in milliseconds, read off the character's own table so the
    // header says what is actually playing.
    readonly property real cycleMs: subject.actionTable(root.action).cycleMs

    // A frozen frame is written the same way the sheet writes one: once the
    // idle animator has finished zeroing what it owns. Written inside that
    // window it is animated straight back off the joints.
    onPlayingChanged: {
        root.posed = false
        if (!root.playing)
            _freeze.restart()
    }
    onPhaseChanged: root.freeze()
    onActionChanged: { root.posed = false; root.freeze() }
    onIntensityChanged: root.freeze()
    onWorkHeightChanged: root.freeze()
    Timer {
        id: _freeze
        interval: 350
        onTriggered: {
            root._apply()
            _settled.restart()
        }
    }
    // The fingers close over their own settle time (Hand/DetailedHand
    // settleMs, 220 ms) - a frame taken the moment the pose is written shows
    // a fist half open.
    Timer {
        id: _settled
        interval: 260
        onTriggered: root.posed = true
    }
    // Until the first frame is on the joints every request goes through the
    // timer - a pose written while IdleAnim is still easing is eased away
    // again, and `posed` would be true of a figure half way back to standing.
    function freeze() {
        if (root.playing)
            return
        if (root.posed)
            root._apply()
        else
            _freeze.restart()
    }
    function _apply() {
        subject.handPose = subject.actionPoseAt(root.action, root.phase).hand
        subject.applyActionPose(root.action, root.phase)
    }

    /*!
        The hands against the body, in the figure's own frame and in HEAD
        HEIGHTS: each fist as an offset from its own shoulder (x out from the
        body's centre line, y up, z forward), and its distance from the
        chin. A guard is a claim about exactly these - fists at the cheeks,
        in front of the face, above the elbows - and a working posture about
        the same numbers lower down. Read it back with --trace on a frozen
        frame or on the running cycle alike.
    */
    function report() {
        const c = subject
        const head = Math.max(0.01, c.headHeight)
        function local(node) { return c.mapPositionFromScene(node.scenePosition) }
        const chin = local(c.head).minus(Qt.vector3d(0, head * 0.45, 0))
        function one(label, arm, side) {
            const s = local(arm.upperArm)
            const e = local(arm.lowerArm)
            const h = local(arm.hand)
            return label + " fist dx" + ((h.x - s.x) / head * side).toFixed(2)
                 + " dy" + ((h.y - s.y) / head).toFixed(2)
                 + " dz" + ((h.z - s.z) / head).toFixed(2)
                 + " elbow dx" + ((e.x - s.x) / head * side).toFixed(2)
                 + " dy" + ((e.y - s.y) / head).toFixed(2)
                 + " dz" + ((e.z - s.z) / head).toFixed(2)
                 + " chin" + (Math.hypot(h.x - chin.x, h.y - chin.y, h.z - chin.z) / head).toFixed(2)
                 + " x" + (h.x / head).toFixed(2)
        }
        return root.action + " " + (root.playing ? "playing" : "phase " + root.phase.toFixed(3))
             + " i" + root.intensity.toFixed(2)
             + (root.action === "use" ? " h" + root.workHeight.toFixed(2) : "")
             + " " + root.cycleMs.toFixed(0) + "ms"
             + " | " + one("R", c.rightArm, 1) + " | " + one("L", c.leftArm, -1)
             + " | hands " + c.rightArm.handPose + "/" + c.handPose
             + " | trunk yaw " + c.torso.eulerRotation.y.toFixed(1)
             + " chest " + c.chest.eulerRotation.x.toFixed(1) + "/" + c.chest.eulerRotation.y.toFixed(1)
             + " head " + c.head.poseEuler.x.toFixed(1) + "/" + c.head.poseEuler.y.toFixed(1)
             + " lift " + (c.gaitLift / c.legHeight).toFixed(3)
    }

    // --- the camera -----------------------------------------------------------

    property real camYaw: 35
    property real camPitch: 8
    property real camDist: 24
    property vector3d camPivot: Qt.vector3d(0, root.bodyHeight * 0.55, 0)
    property string viewpoint: "quarter"

    function look(preset) {
        const mid = Qt.vector3d(0, root.bodyHeight * 0.55, 0)
        const hands = Qt.vector3d(0, root.bodyHeight * 0.62, root.bodyHeight * 0.2)
        if (preset === "front")        { root.camYaw = 0;   root.camPitch = 6;  root.camDist = 24; root.camPivot = mid }
        else if (preset === "quarter") { root.camYaw = 35;  root.camPitch = 8;  root.camDist = 24; root.camPivot = mid }
        else if (preset === "side")    { root.camYaw = 90;  root.camPitch = 6;  root.camDist = 24; root.camPivot = mid }
        else if (preset === "top")     { root.camYaw = 30;  root.camPitch = 78; root.camDist = 26; root.camPivot = mid }
        else if (preset === "hands")   { root.camYaw = 40;  root.camPitch = 12; root.camDist = 11; root.camPivot = hands }
        else if (preset === "far")     { root.camYaw = 35;  root.camPitch = 5;  root.camDist = 60; root.camPivot = mid }
        else return
        root.viewpoint = preset
    }

    // Right button only, so the sliders keep the left. The wheel arrives here
    // whatever the accepted buttons are, so zoom works over the panel too.
    MouseArea {
        id: _orbit
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        z: -1
        property real lastX: 0
        property real lastY: 0
        property real rate: 0.35
        onPressed: (e) => { _orbit.lastX = e.x; _orbit.lastY = e.y; root.forceActiveFocus() }
        onPositionChanged: (e) => {
            root.camYaw += (e.x - _orbit.lastX) * _orbit.rate
            root.camPitch = Math.max(-88, Math.min(88,
                                root.camPitch + (e.y - _orbit.lastY) * _orbit.rate))
            _orbit.lastX = e.x
            _orbit.lastY = e.y
            root.viewpoint = "free"
        }
        onWheel: (w) => {
            const k = w.angleDelta.y > 0 ? 0.88 : 1 / 0.88
            root.camDist = Math.max(2, Math.min(300, root.camDist * k))
            root.viewpoint = "free"
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space) root.playing = !root.playing
        else if (e.key === Qt.Key_F) root.show("fight")
        else if (e.key === Qt.Key_U) root.show("use")
        else if (e.key === Qt.Key_Comma) root.step(-1)
        else if (e.key === Qt.Key_Period) root.step(1)
        else if (e.key === Qt.Key_1) root.look("front")
        else if (e.key === Qt.Key_2) root.look("quarter")
        else if (e.key === Qt.Key_3) root.look("side")
        else if (e.key === Qt.Key_4) root.look("top")
        else if (e.key === Qt.Key_5) root.look("hands")
        else if (e.key === Qt.Key_6) root.look("far")
        else if (e.key === Qt.Key_S) root.silhouette = !root.silhouette
        else if (e.key === Qt.Key_P) root.props = !root.props
        else if (e.key === Qt.Key_H) root.fingers = !root.fingers
        else if (e.key === Qt.Key_B) root.nextBuild()
        else if (e.key === Qt.Key_K) console.log(root.report())
        else if (e.key === Qt.Key_Minus) root.setIntensity(root.intensity - 0.1)
        else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) root.setIntensity(root.intensity + 0.1)
        else if (e.key === Qt.Key_BracketLeft) root.setWorkHeight(root.workHeight - 0.1)
        else if (e.key === Qt.Key_BracketRight) root.setWorkHeight(root.workHeight + 0.1)
        else if (e.key === Qt.Key_Q) root.camYaw -= 10
        else if (e.key === Qt.Key_E) root.camYaw += 10
        else if (e.key === Qt.Key_R) root.camPitch = Math.min(85, root.camPitch + 5)
        else if (e.key === Qt.Key_G) root.camDist = Math.min(300, root.camDist * 1.25)
        else if (e.key === Qt.Key_T) root.camDist = Math.max(2, root.camDist * 0.8)
        else return
        e.accepted = true
    }

    // --- the scene ------------------------------------------------------------

    View3D {
        id: view
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: root.silhouette ? "#f4f2ee" : "#f0efeb"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        DirectionalLight {
            eulerRotation.x: -40
            eulerRotation.y: -45
            castsShadow: !root.silhouette
            shadowFactor: 70
            shadowMapQuality: Light.ShadowMapQualityHigh
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
            brightness: 0.45
        }
        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: 90
            visible: !root.silhouette
            brightness: 0.3
        }

        Node {
            position: root.camPivot
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)
            PerspectiveCamera {
                id: cam
                z: root.camDist
                clipNear: 0.5
                clipFar: 800
            }
        }

        // The floor, top face at y = 0. A Box3D's position is its BOTTOM
        // centre.
        Box3D {
            visible: !root.silhouette
            position: Qt.vector3d(0, -0.6, 0)
            width: root.bodyHeight * 5
            height: 0.6
            depth: root.bodyHeight * 5
            color: "#d9d5cc"
            showEdges: true
            edgeColorFactor: 0.75
        }

        ParametricCharacter {
            id: subject
            bodyHeight: root.bodyHeight
            mass: root.mass
            muscle: root.muscle
            realism: 0.3
            roundness: 0.15
            // Fixed: a bench that let the figure decide how much hand to draw
            // would be judging two things at once.
            detail: root.fingers ? Character.Detail.High : Character.Detail.Low
            autoBlink: !root.silhouette
            gazeBehaviour: false
            actionIntensity: root.intensity
            workHeight: root.workHeight
            activity: !root.playing ? Character.Activity.Idle
                    : root.action === "fight" ? Character.Activity.Fighting
                    : Character.Activity.Using

            skin: root.silhouette ? "#1b1b1f" : "#e8beac"
            topClothing: root.silhouette ? "#1b1b1f" : "#3d6fb4"
            bottomClothing: root.silhouette ? "#1b1b1f" : "#2c3e50"
            footColor: root.silhouette ? "#1b1b1f" : "#4a3728"
            hairTone: root.silhouette ? "#1b1b1f" : "#5c3a21"
            eyeTone: root.silhouette ? "#1b1b1f" : "#4a3728"

        }

        // Where the model puts the hands at this height, solved from the
        // table it is playing: the surface sits under the fingertips, and
        // runs from a little behind the resting hands to where the reach
        // goes. Anything else and the figure works in the air over a table
        // or through one.
        readonly property var _work: subject.actionTable("use")
        readonly property real _upperLen: subject.armHeight * 0.5
        readonly property real _shoulderY: subject.legHeight + subject.footHeight + subject.hipHeight + subject.torsoHeight
        readonly property real _rad: Math.PI / 180
        readonly property real _handY: view._shoulderY
                                     - view._upperLen * Math.cos(view._work.upper * view._rad)
                                     - view._upperLen * Math.cos((view._work.upper + view._work.elbow) * view._rad)
        readonly property real _handZ: view._upperLen * Math.sin(view._work.upper * view._rad)
                                     + view._upperLen * Math.sin((view._work.upper + view._work.elbow) * view._rad)
        readonly property real _tableTop: view._handY - subject.rightArm.handHeight * 1.7
        readonly property real _tableZ: view._handZ + view._upperLen * 0.2
        readonly property real _shoulder: view._shoulderY

        // The table. Wide enough that a sideways reach still lands on it.
        Node {
            visible: root.props && !root.silhouette && root.action === "use"
            Box3D {
                position: Qt.vector3d(0, view._tableTop - 0.3, view._tableZ)
                width: subject.shoulderWidth * 2.6
                height: 0.3
                depth: view._upperLen * 1.6
                color: "#b48a5a"
                showEdges: true
                edgeColorFactor: 0.7
            }
            Repeater3D {
                model: 4
                Box3D {
                    required property int index
                    readonly property real _sx: (index % 2 === 0 ? -1 : 1) * subject.shoulderWidth * 1.2
                    readonly property real _sz: (index < 2 ? -1 : 1) * view._upperLen * 0.7
                    position: Qt.vector3d(_sx, 0, view._tableZ + _sz)
                    width: 0.35
                    height: view._tableTop - 0.3
                    depth: 0.35
                    color: "#8d6a43"
                    showEdges: true
                    edgeColorFactor: 0.7
                }
            }
        }

        // The bag: hung a straight's reach in front of the chest, from above
        // the frame, its middle at the guard's height.
        Node {
            id: _bag
            visible: root.props && !root.silhouette && root.action === "fight"
            // Its near face is where a straight lands: the punching shoulder
            // comes round to the centre line, the arm is all but straight
            // and level, and the fist is a hand's depth further.
            readonly property real _face: subject.shoulderWidth * 0.22 + subject.armHeight * 0.92
                                        + subject.rightArm.handDepth
            readonly property real _thick: subject.shoulderWidth * 0.5
            readonly property real _base: view._shoulderY - subject.torsoHeight * 1.0
            readonly property real _tall: subject.torsoHeight * 1.9
            // See-through, because a bag at a straight's reach sits square in
            // front of the figure from the very angle a guard is judged at.
            Box3D {
                position: Qt.vector3d(0, _bag._base, _bag._face + _bag._thick * 0.5)
                width: _bag._thick
                height: _bag._tall
                depth: _bag._thick
                color: "#8e3b3b"
                opacity: 0.55
                showEdges: true
                edgeColorFactor: 0.7
            }
            Box3D {
                position: Qt.vector3d(0, _bag._base + _bag._tall, _bag._face + _bag._thick * 0.5)
                width: 0.2
                height: root.bodyHeight * 0.8
                depth: 0.2
                color: "#55545a"
            }
        }
    }

    // --- the panel ------------------------------------------------------------

    Rectangle {
        id: _panel
        visible: !root.silhouette
        anchors { right: parent.right; top: parent.top; margins: 8 }
        width: 300
        height: _rows.implicitHeight + 20
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.93)
        border.color: "#c9c6c0"

        Column {
            id: _rows
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 3

            Text {
                text: (root.action === "fight" ? "boxing" : "working")
                    + (root.playing ? "  playing" : "  frozen at " + root.phase.toFixed(3))
                    + "  " + root.cycleMs.toFixed(0) + " ms"
                font.family: root.monoFont
                font.pixelSize: 13
                font.bold: true
                color: "#1b1b1f"
            }
            Item { width: 1; height: 4 }

            component Row_: Row {
                id: _r
                property string label
                property real from: 0
                property real to: 1
                property real value: 0
                property bool live: true
                signal moved(real v)
                spacing: 6
                Text {
                    width: 84
                    text: _r.label
                    font.family: root.monoFont
                    font.pixelSize: 10
                    color: _r.live ? "#3a3a40" : "#a0a0a6"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    width: 140
                    enabled: _r.live
                    from: _r.from
                    to: _r.to
                    value: _r.value
                    onMoved: _r.moved(value)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: 42
                    horizontalAlignment: Text.AlignRight
                    text: _r.value.toFixed(2)
                    font.family: root.monoFont
                    font.pixelSize: 10
                    color: "#1b1b1f"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row_ { label: "intensity"; value: root.intensity; onMoved: (v) => root.setIntensity(v) }
            Row_ { label: "work height"; value: root.workHeight; live: root.action === "use"
                   onMoved: (v) => root.setWorkHeight(v) }
            Row_ { label: "phase"; value: root.phase; live: !root.playing
                   onMoved: (v) => root.scrub(v) }

            Item { width: 1; height: 6 }
            Text {
                width: _panel.width - 20
                wrapMode: Text.WordWrap
                font.family: root.monoFont
                font.pixelSize: 9
                color: "#6b6b72"
                text: "space play/pause   , . step a frame   f fight   u use   "
                    + "-/+ intensity   [ ] work height"
            }
        }
    }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
        color: "#6b6b72"
        font.family: root.monoFont
        font.pixelSize: 11
        visible: !root.silhouette
        text: "1-6 front, quarter, side, top, hands, far   right-drag orbit   wheel zoom   "
            + "p props   h fingers   b build (" + root.builds[root.build].name + ")   "
            + "s silhouette   k print report   qe/r/tg camera"
    }
}
