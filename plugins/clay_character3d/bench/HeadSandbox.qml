// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief The head at all three levels of detail, side by side
// @tags 3D, Character, Face, LOD
// @category Plugin Benches
//
// The bench for the face. Three heads, identical but for their detail level,
// so the thing being judged - whether a level swap is visible - can be judged
// by looking at two of them at once rather than by remembering what the last
// one looked like.
//
// What it is for:
//
//   * The face is drawn in a shader now, not built out of boxes. That buys the
//     eyes their lids, their irises and a gaze direction for nothing, and it
//     means the cheap levels can thin the face instead of deleting it. Whether
//     that actually reads at size is not something the change itself can prove.
//   * A blink, a glance and a talking mouth are all one uniform each. They are
//     also the three things most likely to look wrong, because they move.
//   * The numbers in the corner exist so "still readable at 90 px" is a claim
//     that can be checked rather than an impression.
//
//   ./build/bin/claydojo --sbx plugins/clay_character3d/bench/HeadSandbox.qml
//   ./build/bin/clayrender plugins/clay_character3d/bench/HeadSandbox.qml \
//       --eval 'look("work"); play("talk")' --frames 90 --out head.png
//
// Launch the dojo with QT_DISABLE_SHADER_DISK_CACHE=1.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- what is being shown -------------------------------------------------

    /*! Distance from the row of heads. */
    property real camDist: 5.6
    /*! Orbit angle, degrees. 0 is face on, 90 is full profile. */
    property real camYaw: 0
    property real camHeight: 0.72

    /*! Which head the readout measures. 0 High, 1 Low, 2 Minimal. */
    property int subject: 0

    /*! Draw all three, or one on its own to look at it without a neighbour. */
    property bool row: true

    /*! Flat ink on everything - the silhouette test, with the face still on it. */
    property bool silhouette: false

    property int activity: Head.Activity.Idle
    property bool blinking: true
    property vector2d gaze: Qt.vector2d(0, 0)

    readonly property real spread: 1.85

    // --- driving it ----------------------------------------------------------

    function look(preset) {
        if (preset === "face")   { camYaw = 0;  camDist = 5.6; camHeight = 0.72 }
        // The distance the thing has to survive: a head about ninety pixels
        // tall, which is roughly where Auto stops asking for High.
        else if (preset === "work")  { camYaw = 20; camDist = 11.0; camHeight = 0.7 }
        else if (preset === "far")   { camYaw = 15; camDist = 26.0; camHeight = 0.7 }
        // Twenty degrees off axis is where the old eye showed its own side
        // wall. Worth keeping as a named viewpoint for exactly that reason.
        else if (preset === "quarter") { camYaw = 22; camDist = 4.6; camHeight = 0.72 }
        else if (preset === "profile") { camYaw = 90; camDist = 4.6; camHeight = 0.72 }
    }

    function play(what) {
        if (what === "talk")  root.activity = Head.Activity.Talk
        else if (what === "joy")   root.activity = Head.Activity.ShowJoy
        else if (what === "anger") root.activity = Head.Activity.ShowAnger
        else if (what === "sad")   root.activity = Head.Activity.ShowSadness
        else root.activity = Head.Activity.Idle
    }

    function glance(x, y) { root.gaze = Qt.vector2d(x, y) }

    // --- the numbers ---------------------------------------------------------

    function headPx() {
        // The readout is bound before the View3D has adopted its camera, and
        // mapFrom3DScene warns rather than returning nothing when asked early.
        if (!_view.camera) return 0
        const h = root.subject === 0 ? _high : (root.subject === 1 ? _low : _min)
        const base = h.scenePosition
        const top = base.plus(Qt.vector3d(0, h.height, 0))
        const a = _view.mapFrom3DScene(base)
        const b = _view.mapFrom3DScene(top)
        if (a.z <= 0 || b.z <= 0) return 0
        return Math.abs(b.y - a.y)
    }

    function eyePx() {
        const h = root.subject === 0 ? _high : (root.subject === 1 ? _low : _min)
        return root.headPx() * (h.eyeWidth / Math.max(1e-6, h.height))
    }

    function report() {
        const names = ["High", "Low", "Minimal"]
        const s = "subject=" + names[root.subject]
                + "  head=" + root.headPx().toFixed(0) + "px"
                + "  eye=" + root.eyePx().toFixed(1) + "px"
                + "  yaw=" + root.camYaw.toFixed(0)
                + "  blink=" + (root.blinking ? "on" : "off")
        console.log(s)
        return s
    }

    // --- the scene -----------------------------------------------------------

    View3D {
        id: _view
        anchors.fill: parent
        camera: _cam

        environment: SceneEnvironment {
            clearColor: root.silhouette ? "#f2efe9" : "#e8e4dc"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        PerspectiveCamera {
            id: _cam
            // Well inside the default clipNear of 10, which would swallow a
            // head-sized subject entirely.
            clipNear: 0.05
            clipFar: 400
            fieldOfView: 32
            position: Qt.vector3d(root.camDist * Math.sin(root.camYaw * Math.PI / 180),
                                  root.camHeight,
                                  root.camDist * Math.cos(root.camYaw * Math.PI / 180))
            eulerRotation: Qt.vector3d(0, root.camYaw, 0)
        }

        DirectionalLight {
            eulerRotation: Qt.vector3d(-25, -35, 0)
            brightness: root.silhouette ? 0.0 : 1.5
        }
        DirectionalLight {
            eulerRotation: Qt.vector3d(10, 150, 0)
            brightness: root.silhouette ? 0.0 : 0.5
            ambientColor: root.silhouette ? "#ffffff" : "#000000"
        }

        // One component so the three cannot differ by accident. Detail is the
        // only thing passed in - that is the whole experiment.
        component Bust: Head {
            required property int level
            detail: level
            activity: root.activity
            autoBlink: root.blinking
            gaze: root.gaze
            skinColor: root.silhouette ? "#3a3f45" : "#d38d5f"
            hairColor: root.silhouette ? "#3a3f45" : "#734120"
            eyeColor: root.silhouette ? "#3a3f45" : "#4a3728"
        }

        // basePos, never x. A Head is a BodyPart, and BodyPart binds position
        // to basePos - so an x set here is overwritten the moment that binding
        // evaluates and all three busts sit on top of each other.
        Bust { id: _high; level: Head.Detail.High
               basePos: Qt.vector3d(root.row ? -root.spread : 0, 0, 0) }
        Bust { id: _low;  level: Head.Detail.Low
               basePos: Qt.vector3d(0, 0, 0)
               visible: root.row || root.subject === 1 }
        Bust { id: _min;  level: Head.Detail.Minimal
               basePos: Qt.vector3d(root.row ? root.spread : 0, 0, 0)
               visible: root.row || root.subject === 2 }
    }

    // Labels, so a screenshot of three heads says which is which.
    Row {
        visible: root.row && root.camYaw === 0
        anchors.top: parent.top
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        Repeater {
            model: ["High", "Low", "Minimal"]
            Label {
                width: root.width / 3
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: "#3a3f45"
                font.pixelSize: 15
                font.bold: true
            }
        }
    }

    Label {
        anchors.left: parent.left; anchors.bottom: parent.bottom
        anchors.margins: 8
        color: "#3a3f45"
        font.family: "monospace"
        font.pixelSize: 12
        text: root.report()
        // scenePosition does not notify, so the readout is sampled.
        Timer { running: true; repeat: true; interval: 250
                onTriggered: parent.text = root.report() }
    }

    Label {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 8
        horizontalAlignment: Text.AlignRight
        color: "#6b7075"
        font.family: "monospace"
        font.pixelSize: 12
        text: "1/2/3 subject   R row   F face  Q quarter  W work  E far  P profile\n"
            + "T talk  J joy  A anger  S sad  I idle   B blink   arrows gaze   H silhouette"
    }

    Keys.onPressed: (e) => {
        switch (e.key) {
        case Qt.Key_1: root.subject = 0; break
        case Qt.Key_2: root.subject = 1; break
        case Qt.Key_3: root.subject = 2; break
        case Qt.Key_R: root.row = !root.row; break
        case Qt.Key_F: root.look("face"); break
        case Qt.Key_Q: root.look("quarter"); break
        case Qt.Key_W: root.look("work"); break
        case Qt.Key_E: root.look("far"); break
        case Qt.Key_P: root.look("profile"); break
        case Qt.Key_T: root.play("talk"); break
        case Qt.Key_J: root.play("joy"); break
        case Qt.Key_A: root.play("anger"); break
        case Qt.Key_S: root.play("sad"); break
        case Qt.Key_I: root.play("idle"); break
        case Qt.Key_B: root.blinking = !root.blinking; break
        case Qt.Key_H: root.silhouette = !root.silhouette; break
        case Qt.Key_Left:  root.gaze = Qt.vector2d(-1, root.gaze.y); break
        case Qt.Key_Right: root.gaze = Qt.vector2d(1, root.gaze.y); break
        case Qt.Key_Up:    root.gaze = Qt.vector2d(root.gaze.x, 1); break
        case Qt.Key_Down:  root.gaze = Qt.vector2d(root.gaze.x, -1); break
        case Qt.Key_Space: root.gaze = Qt.vector2d(0, 0); break
        default: return
        }
        e.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
    }
}
