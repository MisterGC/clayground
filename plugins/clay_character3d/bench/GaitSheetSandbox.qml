// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief A walk or run cycle as a strip of stills - the way animators check one
// @tags 3D, Character, Animation, Gait
// @category Plugin Benchmarks
//
// GaitSheetSandbox - one cycle of one gait, laid out as N frozen figures at
// successive phases, so the whole walk is on one sheet and a flaw that hides
// from a debugger and springs to the eye in motion is on paper.
//
//   clayrender plugins/clay_character3d/bench/GaitSheetSandbox.qml --size 1800x500 \
//       --set 'preset="elderly"' --set 'emotion="sad"' --set 'maturity=0.9' \
//       --set 'frames=8' --set 'yaw=90' --out /tmp/elderly.png
//
// Every figure is an idle ParametricCharacter with the same Gait object and
// the same build; Character.applyGaitPose(base, t) freezes it at t = i/frames.
// Nothing animates, so the render is deterministic and a sheet is a fair
// comparison across presets and across commits.
//
// HOW TO READ IT. t = 0 and t = 0.5 are the CONTACTS: legs furthest apart,
// the leading heel down, the figure at its lowest. t = 0.25 and 0.75 are the
// PASSING positions: legs crossing, the free knee at its highest, the figure
// at its highest if the gait bounces. Between them the arms should oppose the
// legs, the head hold its attitude, and nothing should fold the wrong way. A
// gait reads as a person walking that way when these four poses do; if one
// of them looks wrong on the sheet it looks wrong at speed.
//
// yaw turns the figures: 90 is the classic side view walking screen-right,
// 0 is head-on, 180 from behind, 45 three-quarter. pitch lifts the CAMERA
// instead - 0 is eye level, 90 straight down - so the same sheet can be read
// from above, which is the only angle that shows sway and rock honestly.
// Factors beyond a preset go through the shared Gait:
// --eval 'sheetGait.lean = 6'.
//
// The four views worth checking a change against, as one loop:
//
//   for v in "front 0 0" "side 90 0" "back 180 0" "top 90 88"; do
//     set -- $v
//     clayrender plugins/clay_character3d/bench/GaitSheetSandbox.qml \
//       --size 1800x520 --set 'preset="dejected"' \
//       --set "yaw=$2" --set "pitch=$3" --wait-for 'ready' --out /tmp/sheet-$1.png
//   done
//
// A silhouette that reads as walking from all four is a cycle; one that only
// reads from the side is a side view.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    /*! How many phases of the cycle to freeze, evenly spaced from t = 0. */
    property int frames: 8

    /*! "walk" or "run". */
    property string base: "walk"

    /*! Gait preset for every figure, or empty. */
    property string preset: ""

    /*! Emotion for every figure ("happy", "sad", "angry") or empty. */
    property string emotion: ""

    /*! The build, as ParametricCharacter's sliders. */
    property real maturity: 0.5
    property real femininity: 0.5
    property real mass: 0.5
    property real muscle: 0.5
    property real bodyHeight: 10

    /*! Whether the build feeds the gait (Character.gaitFromBuild). */
    property bool fromBuild: true

    /*! How the figures are turned: 90 is side-on walking screen-right,
        0 head-on, 180 from behind. */
    property real yaw: 90

    /*! How far the camera is lifted, in degrees: 0 is eye level, 90 straight
        down. The floor is dropped past 60, where it would cover the figures. */
    property real pitch: 0

    /*! The shared gait; drive its factors with --eval for tuning. */
    readonly property Gait gait: sheetGait

    /*! How many figures have had their first pose put on; wait for \l ready,
        which is this reaching \l frames. */
    property int applied: 0
    readonly property bool ready: root.applied >= root.frames

    // The first pose has to wait out IdleAnim, which zeroes every joint over
    // its first 200 ms - hence the timer and the counter. Every change after
    // that re-poses SYNCHRONOUSLY in the handler, because a --set lands
    // whenever clayrender is done loading, which can be after ready is already
    // true: a timer-driven re-pose then loses the race with the capture and
    // the sheet shows the old gait under a header naming the new one.
    property int _generation: 0
    function invalidate() { root._generation++ }
    onEmotionChanged: root.invalidate()
    onBaseChanged: root.invalidate()
    onBodyHeightChanged: root.invalidate()
    onFramesChanged: root.applied = 0

    // Bumped whenever the view changes size so the labels re-map.
    property int _layout: 0
    onWidthChanged: root._layout++
    onHeightChanged: root._layout++

    /*! What the first figure ended up walking with - the line to read back. */
    function report() {
        const c = _figures.count > 0 ? _figures.objectAt(0) : null
        if (!c) return "no figure"
        const f = c.gaitFactors
        const keys = Object.keys(f)
        let s = root.base + "  preset=" + (root.preset || "-")
              + (sheetGait.presetKnown ? "" : "(UNKNOWN)")
              + "  emotion=" + (root.emotion || "-")
              + "  build m" + root.maturity.toFixed(2) + " f" + root.femininity.toFixed(2)
              + " w" + root.mass.toFixed(2) + " u" + root.muscle.toFixed(2)
              + "  |  "
        for (const k of keys) {
            const v = f[k]
            const neutralMul = (k === "tempo" || k === "stride" || k === "armSwing" || k === "kneeLift")
            const isNeutral = neutralMul ? Math.abs(v - 1) < 1e-9 : Math.abs(v) < 1e-9
            if (!isNeutral) s += k + "=" + (+v.toFixed(3)) + " "
        }
        const cycle = root.base === "run" ? c.runSpeed : c.walkSpeed
        s += " | speed " + cycle.toFixed(2)
        // What the trunk is actually doing, which is the thing a sheet is read
        // for and the one thing a factor list does not say outright.
        const p = c.gaitPoseAt(root.base, 0)
        s += "  | belly " + p.belly[0].toFixed(1) + " chest " + p.chest[0].toFixed(1)
           + " back " + (p.chest[0] - p.belly[0]).toFixed(1)
        s += "  | yaw " + root.yaw.toFixed(0) + " pitch " + root.pitch.toFixed(0)
        return s
    }

    Gait { id: sheetGait; preset: root.preset }

    readonly property real _spacing: root.bodyHeight * 0.75
    readonly property real _span: root._spacing * root.frames

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
            brightness: 0.9
            ambientColor: Qt.rgba(0.55, 0.55, 0.6, 1.0)
        }
        DirectionalLight {
            eulerRotation.x: -15
            eulerRotation.y: 160
            brightness: 0.4
        }

        // Orthographic: figures along X map linearly to the screen, so a frame
        // label sits under its figure and the lift reads against the floor
        // line without perspective in the way. pitch swings the camera up over
        // the row on the same arc, keeping the row centred whatever it is.
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

        // The floor: a slab whose top face is y = 0, so the feet stand on a
        // line and a bounce leaves it visibly.
        Box3D {
            // From overhead it would be a lid over the whole sheet.
            visible: root.pitch < 60
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
            model: root.frames

            ParametricCharacter {
                id: figure
                required property int index
                readonly property real phase: index / root.frames

                position: Qt.vector3d(index * root._spacing, 0, 0)
                eulerRotation: Qt.vector3d(0, root.yaw, 0)

                bodyHeight: root.bodyHeight
                maturity: root.maturity
                femininity: root.femininity
                mass: root.mass
                muscle: root.muscle
                gaitFromBuild: root.fromBuild
                gait: sheetGait
                realism: 0.3
                roundness: 0.15
                detail: Character.Detail.Low
                autoBlink: false
                gazeBehaviour: false
                activity: Character.Activity.Idle
                skin: "#e8beac"
                topClothing: "#3d6fb4"
                bottomClothing: "#2c3e50"
                footColor: "#4a3728"

                function pose() { figure.applyGaitPose(root.base, figure.phase) }

                // First pose after IdleAnim has had its 200 ms; every later
                // change re-poses at once (see root.invalidate).
                Timer {
                    id: _first
                    interval: 300
                    onTriggered: {
                        figure.setEmotion(root.emotion)
                        figure.pose()
                        root.applied++
                    }
                }
                Component.onCompleted: _first.start()
                onGaitFactorsChanged: figure.pose()
                Connections {
                    target: root
                    function on_GenerationChanged() {
                        figure.setEmotion(root.emotion)
                        figure.pose()
                    }
                }
            }
        }
    }

    // Frame labels, under each figure.
    Repeater {
        model: root.frames
        Text {
            required property int index
            readonly property point at: {
                root._layout
                const p = v3d.mapFrom3DScene(Qt.vector3d(index * root._spacing, -1.2, 0))
                return Qt.point(p.x, p.y)
            }
            x: at.x - width / 2
            y: at.y + 4
            font.family: _header.font.family
            font.pixelSize: 13
            color: "#4a4a50"
            readonly property real t: index / root.frames
            text: "t=" + t.toFixed(3)
                  + (Math.abs(t) < 1e-9 || Math.abs(t - 0.5) < 1e-9 ? "  contact"
                   : Math.abs(t - 0.25) < 1e-9 || Math.abs(t - 0.75) < 1e-9 ? "  passing" : "")
        }
    }

    Rectangle {
        x: 0; y: 0
        width: _header.implicitWidth + 20
        height: _header.implicitHeight + 12
        color: Qt.rgba(1, 1, 1, 0.85)
    }
    Text {
        id: _header
        x: 10; y: 6
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 13
        color: "#1b1b1f"
        text: root.report()
        Timer { interval: 400; running: true; repeat: true; onTriggered: _header.text = root.report() }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Right) root.yaw += 15
        else if (e.key === Qt.Key_Left) root.yaw -= 15
        else if (e.key === Qt.Key_W) root.pitch = Math.min(90, root.pitch + 15)
        else if (e.key === Qt.Key_S) root.pitch = Math.max(0, root.pitch - 15)
        else if (e.key === Qt.Key_Up) root.frames = Math.min(16, root.frames + 1)
        else if (e.key === Qt.Key_Down) root.frames = Math.max(2, root.frames - 1)
        else if (e.key === Qt.Key_B) root.base = root.base === "walk" ? "run" : "walk"
        else if (e.key === Qt.Key_P) {
            const names = sheetGait.presetNames
            const i = names.indexOf(root.preset)
            root.preset = names[(i + 1) % names.length]
        }
        else if (e.key === Qt.Key_1) root.emotion = "happy"
        else if (e.key === Qt.Key_2) root.emotion = "sad"
        else if (e.key === Qt.Key_3) root.emotion = "angry"
        else if (e.key === Qt.Key_0) root.emotion = ""
        else return
        e.accepted = true
    }

    Text {
        x: 10
        y: root.height - implicitHeight - 8
        font.family: _header.font.family
        font.pixelSize: 11
        color: "#6b6b72"
        text: "left/right turn   w/s camera up/down   up/down frames   b walk/run"
            + "   p next preset   1/2/3/0 emotion"
    }
}
