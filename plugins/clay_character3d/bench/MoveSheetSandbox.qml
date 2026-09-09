// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Every move of a loadable move set side by side, one frozen figure each
// @tags 3D, Character, Animation, MoveSet, Martial Arts
// @category Plugin Benches
//
// MoveSheetSandbox - a loadable move set the way GestureSheetSandbox shows the
// gestures and GaitSheetSandbox shows a walk: all of it at once, same figure,
// same light, same angle, labelled, and NOTHING MOVING.
//
// The SET is what is being judged, not any one move. A kick looked at on its
// own is looked at against a memory of the last one, and a memory grades
// generously - which is how a "high" roundhouse that never got the foot past
// the hip survived being watched a dozen times. Side by side against a jab,
// a front kick and a stance, the question "is this move the thing its name
// says" is one the sheet answers in a single frame.
//
//   claydojo --sbx plugins/clay_character3d/bench/MoveSheetSandbox.qml
//
//   clayrender plugins/clay_character3d/bench/MoveSheetSandbox.qml \
//       --size 2600x760 --wait-for 'ready' --out /tmp/moves.png
//
// TWO SHEETS, one component. With `move` empty it draws the SET - one column
// per move, each frozen at the phase it is meant to be read at. With `move`
// set to one of the names it draws that move as a strip of phases, which is
// how a move's TIMING is judged rather than its peak:
//
//   clayrender plugins/clay_character3d/bench/MoveSheetSandbox.qml \
//       --size 2600x700 --set 'move="roundhouse"' --set 'frames=10' \
//       --wait-for 'ready' --out /tmp/roundhouse.png
//
// EVERY POSE HERE IS FROZEN AND DETERMINISTIC. The columns come from
// Character.applyMovePose(), the pure pose model in the set's own JavaScript -
// the same function MoveSet plays - so the sheet cannot show a stance the
// shipped move does not have.
//
// HOW TO READ IT. Two questions, in this order. First: can a stranger name
// each column from its SILHOUETTE alone? `silhouette=true` takes the lighting
// and the colour away and leaves exactly that. Second: is every figure ON the
// floor? The floor slab's top face is y = 0 and each column stands on it, so
// a crouch that sinks or a stance that floats is visible as a gap, and both
// were real while this set was being written.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    /*! Which set is on the sheet. Any name Character::moveSet accepts. */
    property string set: "martial arts"

    /*!
        Empty for the set sheet; a move's name to draw that one move as a strip
        of \l frames phases instead.
    */
    property string move: ""

    /*! How many phases the strip freezes, evenly spaced over the whole move. */
    property int frames: 10

    /*! How hard the moves are thrown, 0..1. Size and speed, never the pose. */
    property real intensity: 0.5

    /*!
        Where each move is worth freezing: the moment it is meant to be read
        at, which is its peak for a strike and its settled frame for a stance.
        Anything the set offers and this does not name is read at its midpoint.
    */
    readonly property var readAt: ({
        stance: 0.0, step: 0.34, guard: 0.45, jab: 0.48, cross: 0.52,
        uppercut: 0.54, lowGuard: 0.5, sweep: 0.58, frontKick: 0.54,
        roundhouse: 0.6, jumpPunch: 0.5, jumpKick: 0.52,
        knockdown: 1.0, getUp: 0.64
    })

    /*! How the figures are turned: 0 head-on, 35 three-quarter, 90 side-on. */
    property real yaw: 35

    /*! How far the camera is lifted, in degrees. The floor drops past 60. */
    property real pitch: 0

    /*! Flat ink on everything, no lights, no floor: the outline alone. */
    property bool silhouette: false

    /*! Shrink every figure in place, for the small-on-screen read. */
    property real scale: 1.0

    property real bodyHeight: 10

    // --- driving it -----------------------------------------------------------

    function show(what) { root.move = (what === undefined ? "" : what) }
    function sheet() { root.move = "" }
    function setYaw(deg) { root.yaw = deg }

    readonly property bool strip: root.move !== ""

    // Read from the PROBE and never from the row of figures: the row's length
    // is what this answers, so a name list that asked the row would be asking
    // its own answer - which QML reports as a binding loop and clayrender
    // turns into a non-zero exit.
    readonly property var names: {
        let out = []
        for (let i = 0; i < _probe.moves.length; ++i)
            out.push(_probe.moves[i].name)
        return out
    }
    readonly property int count: root.strip ? root.frames
                                            : Math.max(1, root.names.length)

    /*!
        How many figures have taken their pose. Wait for \l ready: a --set
        lands whenever clayrender has finished loading, which can be after
        ready was already true once, so the tally is cleared on every change
        and the capture waits for the new one.
    */
    property int posed: 0
    readonly property bool ready: root.count > 0 && root.posed >= root.count

    property int _generation: 0
    function invalidate() {
        root.posed = 0
        for (let i = 0; i < _figures.count; ++i) {
            const f = _figures.objectAt(i)
            if (f) f.counted = false
        }
        root._generation++
    }
    onMoveChanged: root.invalidate()
    onIntensityChanged: root.invalidate()
    onFramesChanged: root.posed = 0

    property int _layout: 0
    onWidthChanged: root._layout++
    onHeightChanged: root._layout++

    readonly property real _pitchPx: {
        root._layout
        const a = v3d.mapFrom3DScene(Qt.vector3d(0, 0, 0))
        const b = v3d.mapFrom3DScene(Qt.vector3d(root._spacing, 0, 0))
        return Math.abs(b.x - a.x)
    }

    /*!
        One line for the header and for --eval to read back: what is drawn, and
        the numbers behind the poses that a picture cannot state. The floor
        figure is the one worth having - "every foot is on the ground" is a
        claim about a number, and a picture of a foot near a line is not.
    */
    function report() {
        let s = (root.strip ? root.move + ", " + root.frames + " frames"
                            : root.set + ", " + root.names.length + " moves")
              + "  yaw " + root.yaw.toFixed(0) + " pitch " + root.pitch.toFixed(0)
              + "  effort " + root.intensity.toFixed(2)
              + "  x" + root.scale.toFixed(2)
              + (root.silhouette ? "  SILHOUETTE" : "")
        if (!root.strip && root.names.length > 0) {
            const g = _probe.movePoseAt("stance", 0)
            const k = _probe.movePoseAt("frontKick", root.readAt.frontKick)
            if (g && k)
                s += "  |  stance blade " + g.torso[1].toFixed(0)
                   + " lift " + g.lift.toFixed(2)
                   + "  |  front kick hip " + k.rightLeg.upper[0].toFixed(0)
                   + " knee " + k.rightLeg.lower[0].toFixed(0)
        }
        return s
    }

    readonly property real _spacing: root.bodyHeight * 0.9
    readonly property real _span: root._spacing * root.count

    // A character that is never drawn, purely so the sheet can ask the set
    // what it contains before the row of figures exists - the row's length is
    // the answer, so it cannot be the thing that answers.
    Item {
        ParametricCharacter { id: _probe; visible: false; moveSet: root.set }
    }

    // --- the scene ------------------------------------------------------------

    View3D {
        id: v3d
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#f4f2ed"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        DirectionalLight {
            eulerRotation.x: -35
            eulerRotation.y: -30
            brightness: root.silhouette ? 0.0 : 0.9
            ambientColor: root.silhouette ? Qt.rgba(1, 1, 1, 1)
                                          : Qt.rgba(0.55, 0.55, 0.6, 1.0)
        }
        DirectionalLight {
            eulerRotation.x: -15
            eulerRotation.y: 160
            visible: !root.silhouette
            brightness: 0.4
        }

        // Orthographic: the figures along X map linearly to the screen, so a
        // label sits under its own figure and two columns are the same size
        // whatever they are doing.
        OrthographicCamera {
            id: cam
            readonly property real _r: Math.PI / 180 * root.pitch
            position: Qt.vector3d(root._span * 0.5 - root._spacing * 0.5,
                                  root.bodyHeight * 0.5 + 200 * Math.sin(cam._r),
                                  200 * Math.cos(cam._r))
            eulerRotation: Qt.vector3d(-root.pitch, 0, 0)
            horizontalMagnification: Math.max(0.01, v3d.width) / (root._span * 1.05)
            verticalMagnification: horizontalMagnification
            clipNear: 1
            clipFar: 400
        }

        // The floor: a slab whose top face is y = 0, so every figure stands on
        // one line and a crouch that sinks into it is visible as such.
        Box3D {
            visible: !root.silhouette && root.pitch < 60
            position: Qt.vector3d(root._span * 0.5 - root._spacing * 0.5, -0.3, 0)
            width: root._span * 1.1
            height: 0.6
            depth: root.bodyHeight * 1.5
            color: "#d7d3ca"
            showEdges: true
            edgeColorFactor: 0.7
        }

        Repeater3D {
            id: _figures
            model: root.count

            ParametricCharacter {
                id: figure
                required property int index

                readonly property string what: root.strip ? root.move
                    : (root.names.length > index ? root.names[index] : "")
                readonly property real at: root.strip
                    ? figure.index / Math.max(1, root.frames - 1)
                    : (root.readAt[figure.what] === undefined
                       ? 0.5 : root.readAt[figure.what])

                position: Qt.vector3d(index * root._spacing, 0, 0)
                eulerRotation: Qt.vector3d(0, root.yaw, 0)
                scale: Qt.vector3d(root.scale, root.scale, root.scale)

                moveSet: root.set
                bodyHeight: root.bodyHeight
                realism: 0.3
                roundness: 0.15
                detail: Character.Detail.High
                autoBlink: false
                gazeBehaviour: false
                activity: Character.Activity.Idle
                actionIntensity: root.intensity

                skin: root.silhouette ? "#1b1b1f" : "#e8beac"
                topClothing: root.silhouette ? "#1b1b1f" : "#b8453a"
                bottomClothing: root.silhouette ? "#1b1b1f" : "#2f3d52"
                footColor: root.silhouette ? "#1b1b1f" : "#4a3728"
                hairTone: root.silhouette ? "#1b1b1f" : "#2b2119"
                eyeTone: root.silhouette ? "#1b1b1f" : "#4a3728"

                // The hands are not written by applyMovePose - they are
                // handPose's - so the sheet asks the model what the move wants
                // and sets it, exactly as the gesture sheet does for an
                // action. Without it a sweep plants a fist on the floor.
                function pose() {
                    if (figure.what === "")
                        return
                    const p = figure.movePoseAt(figure.what, figure.at)
                    if (p === null)
                        return
                    figure.handPose = p.hand
                    figure.applyMovePose(figure.what, figure.at)
                }

                property bool counted: false
                function take() {
                    figure.pose()
                    if (figure.counted)
                        return
                    figure.counted = true
                    root.posed++
                }

                // The first pose waits out IdleAnim's 200 ms: it zeroes what
                // it does not own, and a pose written inside that window is
                // animated away under the capture.
                Timer {
                    id: _first
                    interval: 300
                    onTriggered: figure.take()
                }
                Component.onCompleted: _first.start()

                Connections {
                    target: root
                    function on_GenerationChanged() { figure.take() }
                }
            }
        }
    }

    // --- the labels -----------------------------------------------------------

    Repeater {
        model: root.count
        Text {
            id: _label
            required property int index
            readonly property point at: {
                root._layout
                const p = v3d.mapFrom3DScene(Qt.vector3d(index * root._spacing, -1.2, 0))
                return Qt.point(p.x, p.y)
            }
            x: at.x - width / 2
            y: at.y + 4
            width: Math.max(40, root._pitchPx - 6)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: _header.font.family
            font.pixelSize: Math.max(8, Math.min(13, root._pitchPx / 9))
            color: "#4a4a50"
            text: root.strip
                ? "t=" + (index / Math.max(1, root.frames - 1)).toFixed(2)
                : (root.names.length > index ? root.names[index] : "")
        }
    }

    Rectangle {
        x: 0; y: 0
        width: _header.implicitWidth + 20
        height: _header.implicitHeight + 12
        color: Qt.rgba(1, 1, 1, 0.85)
        visible: !root.silhouette
    }
    Text {
        id: _header
        x: 10; y: 6
        // No font.family: "monospace" resolves to nothing on macOS and Qt
        // warns about it once, which is enough to make clayrender exit 2 on a
        // bench that is perfectly fine.
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 13
        color: "#1b1b1f"
        visible: !root.silhouette
        text: root.report()
        Timer { interval: 400; running: true; repeat: true; onTriggered: _header.text = root.report() }
    }

    Text {
        x: 10
        y: root.height - implicitHeight - 8
        font.family: _header.font.family
        font.pixelSize: 11
        color: "#6b6b72"
        visible: !root.silhouette
        text: "0 the set   1..9 one move as a strip   left/right turn   w/s camera up/down   "
            + "up/down frames   h silhouette   -/+ scale"
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_0) root.sheet()
        else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
            const i = e.key - Qt.Key_1
            if (i < root.names.length) root.show(root.names[i])
        }
        else if (e.key === Qt.Key_Left) root.yaw -= 15
        else if (e.key === Qt.Key_Right) root.yaw += 15
        else if (e.key === Qt.Key_W) root.pitch = Math.min(80, root.pitch + 10)
        else if (e.key === Qt.Key_S) root.pitch = Math.max(0, root.pitch - 10)
        else if (e.key === Qt.Key_Up) root.frames = Math.min(24, root.frames + 1)
        else if (e.key === Qt.Key_Down) root.frames = Math.max(2, root.frames - 1)
        else if (e.key === Qt.Key_H) root.silhouette = !root.silhouette
        else if (e.key === Qt.Key_Minus) root.scale = Math.max(0.2, root.scale - 0.1)
        else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)
            root.scale = Math.min(1.5, root.scale + 0.1)
        else return
        e.accepted = true
    }
}
