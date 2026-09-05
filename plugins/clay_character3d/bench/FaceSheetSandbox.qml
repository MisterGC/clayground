// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief The six facial expressions side by side, one head each
// @tags 3D, Character, Face, Expression
// @category Plugin Benches
//
// The bench for the expressions, and the reason it is a sheet rather than one
// head with a key to press: "these six are distinguishable" is a claim about
// the set, not about any one of them. A face judged on its own is judged
// against a memory of the last one, and a memory grades generously - neutral
// and sadness looked fine one at a time for as long as they were only ever
// seen one at a time.
//
// What it is for:
//
//   * All six at once, same head, same light, same angle, labelled. The only
//     thing that differs between the tiles is Head.activity.
//   * `--set expression=<name>` blows one up to fill the frame, for judging a
//     single face at the size it will actually be read at.
//   * The face is a shader, so an expression is nothing but its uniforms.
//     `report()` prints them, which is what makes "distinct" a number rather
//     than an impression - the suite in tests/qml_head asserts on the same
//     ten values.
//
//   ./build/bin/claydojo --sbx plugins/clay_character3d/bench/FaceSheetSandbox.qml
//   ./build/bin/clayrender plugins/clay_character3d/bench/FaceSheetSandbox.qml \
//       --size 1500x1000 --settle 1600 --out faces.png
//   ./build/bin/clayrender plugins/clay_character3d/bench/FaceSheetSandbox.qml \
//       --set expression=disgust --size 700x700 --settle 1600 --out disgust.png
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

    /*! The six, in the order they are laid out. */
    readonly property var expressions: [
        { name: "neutral",   activity: Head.Activity.Idle },
        { name: "happy",     activity: Head.Activity.ShowJoy },
        { name: "sad",       activity: Head.Activity.ShowSadness },
        { name: "angry",     activity: Head.Activity.ShowAnger },
        { name: "disgust",   activity: Head.Activity.ShowDisgust },
        { name: "surprised", activity: Head.Activity.ShowSurprise }
    ]

    /*!
        One expression by name, filling the frame - or "" for the whole sheet.
        A settable string rather than an index because that is what a
        clayrender line and a paper both want to say.
    */
    property string expression: ""

    /*! Orbit angle, degrees. 0 is face on, 90 is full profile. */
    property real camYaw: 0

    /*! Distance from the head in each tile. */
    property real camDist: 4.6

    /*! Flat ink on everything: does the expression survive without shading? */
    property bool silhouette: false

    readonly property int soloIndex: {
        for (let i = 0; i < root.expressions.length; ++i)
            if (root.expressions[i].name === root.expression) return i
        return -1
    }
    readonly property bool solo: root.soloIndex >= 0

    // --- driving it ----------------------------------------------------------

    function show(name) { root.expression = (name === undefined ? "" : name) }
    function sheet() { root.expression = "" }

    // What the face is actually wearing, as the ten numbers the emotions
    // animate. Printed rather than screenshotted because "clearly different"
    // has to be checkable by something other than an eye - the suite in
    // tests/qml_head asserts on exactly these.
    function faceOf(name) {
        const cell = _heads.itemAt(_indexOf(name))
        if (!cell || !cell.head) return null
        const h = cell.head
        return {
            expression: name,
            cornerLift: h.mouthCornerLift, skew: h.mouthSkew,
            open: h.mouthOpen, wide: h.mouthWide, round: h.mouthRound,
            hood: h.eyeHood, squint: h.eyeSquint,
            browAngle: h.browAngle, browRise: h.browRise, browSkew: h.browSkew
        }
    }

    function _pad(s, n) {
        s = "" + s
        while (s.length < n) s += " "
        return s
    }

    function _indexOf(name) {
        for (let i = 0; i < root.expressions.length; ++i)
            if (root.expressions[i].name === name) return i
        return 0
    }

    function report() {
        let out = []
        for (let i = 0; i < root.expressions.length; ++i) {
            const f = root.faceOf(root.expressions[i].name)
            if (!f) continue
            out.push(root._pad(f.expression, 10)
                     + " lift=" + f.cornerLift.toFixed(2)
                     + " skew=" + f.skew.toFixed(2)
                     + " open=" + f.open.toFixed(2)
                     + " wide=" + f.wide.toFixed(2)
                     + " round=" + f.round.toFixed(2)
                     + " hood=" + f.hood.toFixed(2)
                     + " squint=" + f.squint.toFixed(2)
                     + " brow=" + f.browAngle.toFixed(0) + "deg"
                     + "/" + f.browRise.toFixed(3)
                     + "/" + f.browSkew.toFixed(3))
        }
        const s = out.join("\n")
        console.log(s)
        return s
    }

    // --- the scene -----------------------------------------------------------

    // A tile is a View3D of its own rather than six heads in one scene: each
    // face then sits dead centre of its own frame at the same size, which is
    // the comparison being made. Spread across one camera, the outer heads are
    // seen from the side and lit differently, and a difference in the lighting
    // reads as a difference in the expression.
    component Tile: Item {
        id: _tile
        required property int activity
        property alias head: _bust

        View3D {
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
                clipNear: 0.05
                clipFar: 400
                fieldOfView: 32
                // Far enough back that the hair and the chin both stay in the
                // tile: a head is about 1.5 units tall with its hair on, and a
                // cropped fringe is the first thing an eye reads as an
                // expression that has gone wrong.
                position: Qt.vector3d(root.camDist * Math.sin(root.camYaw * Math.PI / 180),
                                      0.78,
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

            Head {
                id: _bust
                activity: _tile.activity
                // Off: a blink lands on top of an expression, and a sheet
                // caught mid-blink says the wrong thing about a face.
                autoBlink: false
                skinColor: root.silhouette ? "#3a3f45" : "#d38d5f"
                hairColor: root.silhouette ? "#3a3f45" : "#734120"
                eyeColor: root.silhouette ? "#3a3f45" : "#4a3728"
            }
        }
    }

    Grid {
        anchors.fill: parent
        // columns only. Setting rows as well makes Grid warn whenever the two
        // disagree with the number of visible items for even one binding pass,
        // which a solo view does on every change - and a bench that warns
        // makes clayrender exit 2 on a render that is perfectly fine.
        columns: root.solo ? 1 : 3
        Repeater {
            id: _heads
            model: root.expressions
            delegate: Item {
                id: _cell
                required property var modelData
                required property int index
                visible: !root.solo || root.soloIndex === _cell.index
                width: visible ? (root.solo ? root.width : root.width / 3) : 0
                height: visible ? (root.solo ? root.height : root.height / 2) : 0

                // The Repeater's item is this cell; the readout wants the
                // head inside it.
                readonly property var head: _t.head

                Tile {
                    id: _t
                    anchors.fill: parent
                    activity: _cell.modelData.activity
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    text: _cell.modelData.name
                    color: "#3a3f45"
                    font.pixelSize: root.solo ? 22 : 16
                    font.bold: true
                }
            }
        }
    }

    Label {
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 8
        horizontalAlignment: Text.AlignRight
        color: "#6b7075"
        // No font.family: "monospace" resolves to nothing on macOS and Qt
        // warns about it once, which is enough to make clayrender exit 2 -
        // "loaded with scene errors" - on a bench that has none.
        font.pixelSize: 12
        text: "1-6 one face   0 the sheet   F face  Q quarter  P profile   H silhouette"
    }

    Keys.onPressed: (e) => {
        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_6) {
            root.expression = root.expressions[e.key - Qt.Key_1].name
        } else {
            switch (e.key) {
            case Qt.Key_0: root.sheet(); break
            case Qt.Key_F: root.camYaw = 0; break
            case Qt.Key_Q: root.camYaw = 22; break
            case Qt.Key_P: root.camYaw = 90; break
            case Qt.Key_H: root.silhouette = !root.silhouette; break
            default: return
            }
        }
        e.accepted = true
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.forceActiveFocus()
    }
}
