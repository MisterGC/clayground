// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Every hand and arm gesture side by side, one frozen figure each
// @tags 3D, Character, Animation, Gesture, Hand
// @category Plugin Benches
//
// GestureSheetSandbox - the gestures the way the gait cycle sheet shows a walk
// and the face sheet shows the expressions: all of them at once, same figure,
// same light, same angle, labelled, and NOTHING MOVING.
//
// The set is the thing being judged, not any one pose. A gesture looked at on
// its own is looked at against a memory of the last one, and a memory grades
// generously - which is how a fist that never closed and a guard with its
// elbows out at shoulder height both survived for as long as they were only
// ever seen one at a time. Side by side, "clearly recognisable at a glance" is
// a question the sheet answers in one frame.
//
//   claydojo --sbx plugins/clay_character3d/bench/GestureSheetSandbox.qml
//
//   clayrender plugins/clay_character3d/bench/GestureSheetSandbox.qml \
//       --size 2000x700 --wait-for 'ready' --out /tmp/gestures.png
//
// TWO SHEETS, one component. With `action` empty it draws the SET - one column
// per gesture, each at the moment it is meant to be read at. With `action` set
// to "fight" or "use" it draws that one cycle as a strip of phases, which is
// the gait sheet's trick applied to an action:
//
//   clayrender plugins/clay_character3d/bench/GestureSheetSandbox.qml \
//       --size 2000x600 --set 'action="fight"' --set 'frames=8' \
//       --wait-for 'ready' --out /tmp/boxing.png
//
// EVERY POSE HERE IS FROZEN AND DETERMINISTIC, which is what makes two renders
// comparable across a change:
//
//   * the cycles come from Character.applyActionPose(), the pure pose model in
//     action.js - the same function ActionCycleAnim plays, so the sheet cannot
//     show a boxing stance the shipped cycle does not have;
//   * the aimed gestures (point, present, thumbs up) go through the real
//     GestureAnim solver with its settle cut to a frame, and `ready` is not
//     true until every one of them has arrived.
//
// HOW TO READ IT. Ask each column one question and no other: can a stranger
// name the gesture from the SILHOUETTE alone? `silhouette=true` takes the
// lighting and the colours away and leaves exactly that. Then ask it at the
// distance the character is actually seen from - `scale` shrinks every figure
// in place, and a gesture that stops reading around a third of the frame's
// height is a gesture that will not survive a wide shot.
//
// yaw turns the figures (0 head-on, 90 side, 180 from behind, 35 the
// three-quarter view most of these are seen at); pitch lifts the camera.
// The four views worth checking a change against:
//
//   for v in "front 0" "quarter 35" "side 90" "back 180"; do
//     set -- $v
//     clayrender plugins/clay_character3d/bench/GestureSheetSandbox.qml \
//       --size 2000x700 --set "yaw=$2" --wait-for 'ready' --out /tmp/g-$1.png
//   done

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- what is on the sheet -------------------------------------------------

    /*!
        The set, in the order it is laid out. `kind` says how a column is
        driven: "rest" leaves the idle pose alone, "hand" only shapes the
        fingers, "gesture" runs the real GestureAnim solver, and "action"
        freezes a cycle at a phase.
    */
    readonly property var columns: [
        { name: "idle",     kind: "rest",    label: "idle" },
        { name: "relax",    kind: "hand",    label: "hand: relax" },
        { name: "open",     kind: "hand",    label: "hand: open" },
        { name: "fist",     kind: "hand",    label: "hand: fist" },
        { name: "thumbsUp", kind: "gesture", label: "thumbs up" },
        { name: "point",    kind: "gesture", label: "point" },
        // The same gesture aimed above the character's own head, which is the
        // case the pointing solver has the least room in: safeSilhouette
        // forbids the raised straight arm, so the elbow folds, and a folded
        // arm brings the hand back toward a head that is a large box. Kept as
        // a column of its own because a sheet that only shows the easy aim is
        // a sheet that will not notice the day the hard one breaks.
        { name: "pointHigh", kind: "gesture", label: "point (overhead)" },
        { name: "present",  kind: "gesture", label: "present" },
        // The three phases of the boxing loop worth judging: the guard it
        // holds most of the time (settled, late in the cycle), the jab, and
        // the cross it is named for. The phases are the peaks of action.js's
        // jab1 and cross slots.
        { name: "fight",    kind: "action",  at: 0.95,  label: "boxing: guard" },
        { name: "fight",    kind: "action",  at: 0.084, label: "boxing: jab" },
        { name: "fight",    kind: "action",  at: 0.605, label: "boxing: cross" },
        // Two beats of the working loop: the hands at the work, and the
        // reach that says the work is a thing rather than a spot.
        { name: "use",      kind: "action",  at: 0.45,  label: "working" },
        { name: "use",      kind: "action",  at: 0.10,  label: "working: reach" }
    ]

    /*!
        Empty for the set sheet; "fight" or "use" to draw that one cycle as a
        strip of \l frames phases instead.
    */
    property string action: ""

    /*! How many phases the cycle strip freezes, evenly spaced from t = 0. */
    property int frames: 8

    /*! How hard at it the action is, 0..1. Only read by the cycle strip. */
    property real intensity: 0.5

    /*! Where the work is: 0 waist, 1 shoulder. Only read by "use". */
    property real workHeight: 0.35

    readonly property bool strip: root.action !== ""
    readonly property int count: root.strip ? root.frames : root.columns.length

    /*! How the figures are turned: 0 head-on, 35 three-quarter, 90 side-on. */
    property real yaw: 35

    /*! How far the camera is lifted, in degrees. The floor drops past 60. */
    property real pitch: 0

    /*!
        Flat ink on everything, no lights, no floor. What is left is the
        outline, which is the only thing a gesture has at any distance - and
        the test this sheet exists for.

        The eyes stay light: the face is a shader and the white of an eye is
        written into it, not taken from a property. It is two pixels and it
        marks which way a figure is facing, which a silhouette otherwise has
        to be read for.
    */
    property bool silhouette: false

    /*! Shrink every figure in place, for the small-on-screen read. */
    property real scale: 1.0

    /*! Fingers or a single box: the two levels of detail a hand ships at. */
    property bool fingers: true

    /*! Cartoon hands - gloved and oversized, the way a comic draws them. */
    property bool gloves: false

    property real bodyHeight: 10

    // --- driving it -----------------------------------------------------------

    function show(what) { root.action = (what === undefined ? "" : what) }
    function sheet() { root.action = "" }
    function setSilhouette(on) { root.silhouette = on }
    function setYaw(deg) { root.yaw = deg }
    function scaleTo(s) { root.scale = s }
    function setFingers(on) { root.fingers = on }

    /*!
        How many figures have taken their pose. Wait for \l ready, never for a
        settle: an aimed gesture arrives when its solver says so, and a capture
        taken before that photographs the arm on its way there.
    */
    property int posed: 0
    readonly property bool ready: root.posed >= root.count

    // Every change to what is being drawn re-poses every figure, synchronously
    // in the handler. A --set lands whenever clayrender has finished loading,
    // which can be after ready is already true, so a timer-driven re-pose loses
    // the race with the capture and the sheet shows the old pose under a header
    // naming the new one. (The same trap GaitSheetSandbox documents.)
    property int _generation: 0
    function invalidate() {
        root.posed = 0
        for (let i = 0; i < _figures.count; ++i) {
            const f = _figures.objectAt(i)
            if (f) f.counted = false
        }
        root._generation++
    }
    onActionChanged: root.invalidate()
    // A change of frame count rebuilds the model, so the new figures pose and
    // count themselves; only the tally has to be cleared.
    onFramesChanged: root.posed = 0
    onIntensityChanged: root.invalidate()
    onWorkHeightChanged: root.invalidate()

    // Bumped whenever the view changes size, so the labels re-map.
    property int _layout: 0

    // How many screen pixels one column is wide. The camera is orthographic
    // and fits the whole row across the viewport, so this shrinks as columns
    // are added and as the window gets TALLER - vertical magnification follows
    // horizontal, so a tall window squeezes the row sideways. The labels are
    // sized off it: written at a fixed pixel size they collide the moment the
    // sheet is opened in anything but the wide frame it is rendered at, and a
    // sheet whose captions overlap is a sheet that cannot be read.
    readonly property real _pitchPx: {
        root._layout
        const a = v3d.mapFrom3DScene(Qt.vector3d(0, 0, 0))
        const b = v3d.mapFrom3DScene(Qt.vector3d(root._spacing, 0, 0))
        return Math.abs(b.x - a.x)
    }
    onWidthChanged: root._layout++
    onHeightChanged: root._layout++

    /*!
        Where an aimed gesture aims, as an offset from the figure's OWN feet
        rather than a place in the room. The columns stand apart, and one
        shared target would turn each of them by a different amount and pose
        their arms differently - which is the one thing a side-by-side
        comparison must not do.
    */
    property vector3d pointAtOffset: Qt.vector3d(-5, 7, 9)
    property vector3d pointHighAtOffset: Qt.vector3d(-3, 15, 7)
    property vector3d presentAtOffset: Qt.vector3d(-4, 5, 9)

    function _markerFor(name) {
        return name === "point" ? root.pointAtOffset
             : name === "pointHigh" ? root.pointHighAtOffset
             : root.presentAtOffset
    }

    /*!
        One line for the header and for --eval to read back: what is drawn, and
        the numbers behind the poses that a picture cannot state.
    */
    function report() {
        let s = (root.strip ? root.action + " cycle, " + root.frames + " frames"
                            : "the set, " + root.columns.length + " gestures")
              + "  yaw " + root.yaw.toFixed(0) + " pitch " + root.pitch.toFixed(0)
              + "  hands " + (root.fingers ? "fingers" : "box")
              + (root.gloves ? "+gloves" : "")
              + "  x" + root.scale.toFixed(2)
              + (root.silhouette ? "  SILHOUETTE" : "")
        const c = _figures.count > 0 ? _figures.objectAt(0) : null
        if (c) {
            const f = c.actionPoseAt("fight", 0)
            const u = c.actionPoseAt("use", 0.5)
            s += "  |  guard elbow " + f.rightArm.lower[0].toFixed(0)
               + " blade " + f.torso[1].toFixed(0)
               + "  |  work elbow " + u.rightArm.lower[0].toFixed(0)
               + " lean " + (u.belly[0] + u.chest[0]).toFixed(1)
        }
        return s
    }

    readonly property real _spacing: root.bodyHeight * 0.82
    readonly property real _span: root._spacing * root.count

    // --- the scene ------------------------------------------------------------

    View3D {
        id: v3d
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: root.silhouette ? "#f4f2ee" : "#f4f2ed"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Four is the hard maximum for directional lights, so silhouette mode
        // cannot add one of its own: the key light flattens to pure ambient
        // instead and the fill goes out.
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
        // whatever they are doing. Perspective would make the outer ones lean.
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
        // one line and a stance that lifts a heel leaves it visibly.
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

                readonly property var spec: root.strip
                    ? { name: root.action, kind: "action",
                        at: figure.index / root.frames, label: "" }
                    : root.columns[figure.index]

                position: Qt.vector3d(index * root._spacing, 0, 0)
                eulerRotation: Qt.vector3d(0, root.yaw, 0)
                scale: Qt.vector3d(root.scale, root.scale, root.scale)

                bodyHeight: root.bodyHeight
                realism: 0.3
                roundness: 0.15
                // Fixed, never Auto: a sheet whose columns decided for
                // themselves how much hand to draw would be comparing two
                // things at once.
                detail: root.fingers ? Character.Detail.High : Character.Detail.Low
                gloves: root.gloves
                handScale: root.gloves ? 1.35 : 1.0
                autoBlink: false
                gazeBehaviour: false
                activity: Character.Activity.Idle
                actionIntensity: root.intensity
                workHeight: root.workHeight
                // The solver's ease is the one thing on this sheet that is
                // time: cut to a frame, a pose is simply there.
                gestureSettleMs: 16

                // One ink in silhouette mode: a two-tone figure hands the eye
                // an inner edge to read the shape by, which is exactly what is
                // not available at the distance this mode exists to test.
                skin: root.silhouette ? "#1b1b1f" : "#e8beac"
                topClothing: root.silhouette ? "#1b1b1f" : "#3d6fb4"
                bottomClothing: root.silhouette ? "#1b1b1f" : "#2c3e50"
                footColor: root.silhouette ? "#1b1b1f" : "#4a3728"
                hairTone: root.silhouette ? "#1b1b1f" : "#5c3a21"
                eyeTone: root.silhouette ? "#1b1b1f" : "#4a3728"

                function pose() {
                    const s = figure.spec
                    figure.stopGesture()
                    figure.handPose = "relax"
                    if (s.kind === "hand") {
                        figure.handPose = s.name
                        figure.showHand()
                    } else if (s.kind === "gesture") {
                        if (s.name === "thumbsUp")
                            figure.thumbsUp("right")
                        // "auto", never a named arm: which hand a character
                        // reaches with is part of what is being judged, and
                        // forcing the far one produces an arm across the chest
                        // that nothing in normal use would ever ask for.
                        else if (s.name === "point" || s.name === "pointHigh")
                            figure.pointAt(figure.scenePosition.plus(root._markerFor(s.name)))
                        else if (s.name === "present")
                            figure.presentAt(figure.scenePosition.plus(root.presentAtOffset))
                    } else if (s.kind === "action") {
                        // The hands are not written by applyActionPose - they
                        // are handPose's - so the sheet asks the model what
                        // the action wants and sets it.
                        figure.handPose = figure.actionPoseAt(s.name, s.at).hand
                        figure.applyActionPose(s.name, s.at)
                    }
                }

                // The hand columns hold the right arm OUT, forearm level and
                // clear of the torso, the way somebody shows you their hand.
                // Left down at the character's side the whole column is one
                // figure standing still with a lump at its hip, and the shape
                // that is supposed to be under judgement is the one thing on
                // the sheet nobody can see. Written straight onto the joints
                // rather than animated: IdleAnim owns them, and it has already
                // run and stopped by the time this is called.
                function showHand() {
                    figure.rightArm.upperArm.eulerRotation = Qt.vector3d(-30, 0, 34)
                    figure.rightArm.lowerArm.eulerRotation = Qt.vector3d(-80, 0, 0)
                    // A quarter turn, so the back of the hand faces the camera
                    // at the three-quarter view the sheet defaults to: the
                    // fingers read against the background rather than against
                    // the palm behind them.
                    figure.rightArm.hand.eulerRotation = Qt.vector3d(0, 45, 0)
                }

                // A column counts toward `ready` once it HOLDS the pose it is
                // labelled with, which is not the same moment for the two
                // kinds: a frozen action is there as soon as it is written, an
                // aimed gesture only when its solver says it has arrived.
                property bool counted: false
                function count() {
                    if (figure.counted)
                        return
                    figure.counted = true
                    root.posed++
                }
                function take() {
                    figure.pose()
                    if (figure.spec.kind !== "gesture")
                        figure.count()
                }

                // The first pose waits out IdleAnim's 200 ms: it zeroes what it
                // does not own, and a pose written inside that window is
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
                onGestureSettledChanged: if (figure.gestureSettled) figure.count()
            }
        }

        // What a point is aimed at. Visible because "the finger is on it" is
        // the half of an aim that no number shows: the marker says which way
        // it missed.
        Repeater3D {
            model: root.strip ? 0 : root.columns.length
            Model {
                required property int index
                source: "#Sphere"
                visible: !root.silhouette
                         && root.columns[index].kind === "gesture"
                         && root.columns[index].name !== "thumbsUp"
                position: Qt.vector3d(index * root._spacing, 0, 0).plus(
                              root._markerFor(root.columns[index].name))
                scale: Qt.vector3d(0.008, 0.008, 0.008)
                materials: PrincipledMaterial {
                    baseColor: "#c0392b"
                    lighting: PrincipledMaterial.NoLighting
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
            font.pixelSize: Math.max(8, Math.min(13, root._pitchPx / 11))
            color: "#4a4a50"
            readonly property real t: index / Math.max(1, root.frames)
            text: root.strip ? "t=" + _label.t.toFixed(3)
                             : root.columns[index].label
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
        // No font.family: "monospace" resolves to nothing on macOS and Qt warns
        // about it once, which is enough to make clayrender exit 2 on a bench
        // that is perfectly fine.
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
        text: "0 the set   1 boxing   2 working   left/right turn   w/s camera up/down   "
            + "up/down frames   h silhouette   d fingers/box   g gloves   -/+ scale"
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_0) root.sheet()
        else if (e.key === Qt.Key_1) root.show("fight")
        else if (e.key === Qt.Key_2) root.show("use")
        else if (e.key === Qt.Key_Right) root.yaw += 15
        else if (e.key === Qt.Key_Left) root.yaw -= 15
        else if (e.key === Qt.Key_W) root.pitch = Math.min(90, root.pitch + 15)
        else if (e.key === Qt.Key_S) root.pitch = Math.max(0, root.pitch - 15)
        else if (e.key === Qt.Key_Up) root.frames = Math.min(16, root.frames + 1)
        else if (e.key === Qt.Key_Down) root.frames = Math.max(2, root.frames - 1)
        else if (e.key === Qt.Key_H) root.silhouette = !root.silhouette
        else if (e.key === Qt.Key_D) root.fingers = !root.fingers
        else if (e.key === Qt.Key_G) root.gloves = !root.gloves
        else if (e.key === Qt.Key_Minus) root.scale = Math.max(0.15, root.scale * 0.8)
        else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal)
            root.scale = Math.min(1, root.scale * 1.25)
        else return
        e.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
    }
}
