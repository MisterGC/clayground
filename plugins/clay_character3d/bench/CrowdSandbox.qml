// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief How many characters a machine can afford, and what detail costs
// @tags 3D, Character, Benchmark, Performance
// @category Plugin Benchmarks
//
// CrowdSandbox - the answer to "how many of these can I have?", on the machine
// being asked.
//
// It exists because that question has no general answer and a wrong one is
// expensive: a lab built on a developer's machine and shipped to a classroom
// full of ten-year-old hardware is a lab that excludes the people it was for.
// This runs where the doubt is.
//
//   claydojo --sbx plugins/clay_character3d/bench/CrowdSandbox.qml
//
//   clayrender plugins/clay_character3d/bench/CrowdSandbox.qml --size 1000x600 \
//       --eval 'setCount(20); setDetail("high")' --frames 220 --out /tmp/a.png
//
// WHAT TO READ. draws is the number that matters and verts is the number that
// does not, which is the least obvious thing here and the most useful. On the
// machine this was written on:
//
//   render_ms = 0.0178 x draws + 2.6      (fits five configurations, R2 ~ .999)
//
// Vertices barely appear. Six hundred cubes cost 6.9 ms and six hundred of
// Qt's spheres - orders of magnitude more geometry, same draw count - cost
// 8.4. So a character's cost is very nearly a count of its boxes, and making
// those boxes rounder or smoother is close to free while having more of them
// is not.
//
// A character is 21 boxes at Low, 43 at High and 20 at Minimal, measured here
// at twenty characters: 420, 860 and 400 draw calls, for 10.68, 17.13 and
// 10.07 ms of render time.
//
// Those three numbers used to be 33, 53 and 20, and the gap between the first
// and the last was the face - thirteen boxes carrying none of the silhouette,
// which is why Minimal deleted it. The face is drawn in a fragment shader now
// and costs no draw calls at all, so it no longer appears in this table. Two
// consequences worth knowing before tuning anything:
//
//   * Minimal saves ONE box over Low. As a performance tier it has almost
//     stopped existing; what it is for now is legibility at twenty pixels.
//     Nearly all of the remaining spread is the twenty boxes of fingers.
//   * The face is free in fragment cost too, not just in draw calls. Twenty
//     characters at High measure 17.13 ms filling the frame and 17.13 ms as
//     specks at camZ=250 - same draws, same time. The SDF work is gated to the
//     flat front quad and disappears with it.
//
// Close anything else using the GPU before believing a number here. Measured
// with the dojo open on another scene, the same configuration read 28 ms
// instead of 17 - a 65% error, and a completely stable one.
//
// The absolute milliseconds are this machine's. The SHAPE of the result - draw
// call bound, vertex cheap - is what carries to another one.

import QtQuick
import QtQuick3D
import Clayground.Character3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    /*! How many characters stand in the field. */
    property int count: 20

    /*! Detail level they are all held at, or "auto" to let them choose. */
    property string detail: "auto"

    /*!
        Whether they walk. Worth having as a switch: an animated character
        costs CPU that a still one does not, and it is the only way to tell
        whether a scene is bound by drawing or by animating. Measured here it
        was about 14% of the frame at forty characters - real, but not the
        thing that decides the budget.
    */
    property bool walking: true

    property real camZ: 60

    /*!
        Chamfer on every box. Here because this is the bench that answers what
        it costs, and the answer is the point: it changes verts and leaves
        draws alone, which is why a rounded character is affordable and a
        crowd of them is the same problem it always was.
    */
    property real roundness: 0.0
    function setRoundness(r) { root.roundness = r; root._reset() }

    function setCount(n) { root.count = n; root._reset() }
    function setWalking(b) { root.walking = b; root._reset() }
    function setCam(z) { root.camZ = z; root._reset() }

    function setDetail(s) {
        root.detail = s
        root._reset()
    }

    readonly property int _level: root.detail === "high" ? Character.Detail.High
                                : root.detail === "minimal" ? Character.Detail.Minimal
                                : root.detail === "low" ? Character.Detail.Low
                                : Character.Detail.Auto

    // --- the measurement --------------------------------------------------------

    readonly property var stats: v3d.renderStats

    // drawCallCount and drawVertexCount are the "extended" half of renderStats
    // and Qt does not collect them unless asked - without this they read zero
    // and the whole bench says nothing.
    Component.onCompleted: v3d.renderStats.extendedDataCollectionEnabled = true

    property real _accFrame: 0
    property real _accRender: 0
    property int _samples: 0
    property int _probeTier: -1

    function _reset() { root._accFrame = 0; root._accRender = 0; root._samples = 0 }

    // Averaged, and only after a warm-up: the first second is shader
    // compilation and the first upload of every geometry, which is real cost
    // but not the steady state anyone is asking about.
    Timer { id: _warmup; interval: 1500; running: true }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            const s = root.stats
            if (!s || _warmup.running)
                return
            root._accFrame += s.frameTime
            root._accRender += s.renderTime
            root._samples++
            _label.text = root.report()
        }
    }

    /*! One line for --eval to print and for the corner of every render. */
    function report() {
        const n = Math.max(1, root._samples)
        const s = root.stats
        const tier = root._probeTier < 0 ? "?"
                   : ["minimal", "low", "high"][root._probeTier]
        return "n=" + root.count
             + "  detail=" + root.detail + (root.detail === "auto" ? "(" + tier + ")" : "")
             + "  camZ=" + root.camZ.toFixed(0)
             + (root.roundness > 0 ? "  round=" + root.roundness.toFixed(2) : "")
             + "  draws=" + (s ? s.drawCallCount : "?")
             + "  verts=" + (s ? s.drawVertexCount : "?")
             + "  render=" + (root._accRender / n).toFixed(2)
             + "  frame=" + (root._accFrame / n).toFixed(2) + "ms"
    }

    /*! Draw calls per character, which is the portable number. */
    function perCharacter() {
        const s = root.stats
        return s && root.count > 0 ? s.drawCallCount / root.count : 0
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Up) root.setCount(root.count + 5)
        else if (e.key === Qt.Key_Down) root.setCount(Math.max(1, root.count - 5))
        else if (e.key === Qt.Key_1) root.setDetail("minimal")
        else if (e.key === Qt.Key_2) root.setDetail("low")
        else if (e.key === Qt.Key_3) root.setDetail("high")
        else if (e.key === Qt.Key_4) root.setDetail("auto")
        else if (e.key === Qt.Key_W) root.setWalking(!root.walking)
        else if (e.key === Qt.Key_R) root.setRoundness(root.roundness > 0 ? 0.0 : 0.15)
        else if (e.key === Qt.Key_T) root.setCam(Math.max(15, root.camZ * 0.8))
        else if (e.key === Qt.Key_G) root.setCam(Math.min(400, root.camZ * 1.25))
        else return
        e.accepted = true
    }

    // --- the scene ---------------------------------------------------------------

    View3D {
        id: v3d
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: "#eeece7"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
        }

        // No shadows anywhere. A shadow-casting light draws the whole scene a
        // second time into the shadow map, which doubles the number this bench
        // exists to report and hides what is being measured behind a constant.
        DirectionalLight {
            eulerRotation.x: -40
            eulerRotation.y: -45
            brightness: 0.9
            ambientColor: Qt.rgba(0.5, 0.5, 0.55, 1.0)
        }

        DirectionalLight {
            eulerRotation.y: 180
            brightness: 0.45
        }

        PerspectiveCamera {
            id: cam
            z: root.camZ
            y: root.camZ * 0.43
            eulerRotation.x: -18
            clipFar: 2000
        }

        Repeater3D {
            model: root.count

            ParametricCharacter {
                required property int index

                bodyHeight: 10
                detail: root._level
                // Auto measures the character against the viewport, so it needs
                // to be told which one. Note the id is NOT `view`: written as
                // `view: view` inside a delegate, the right-hand side resolves
                // to this object's own property and quietly assigns null, and
                // an Auto character with no view sits at Low forever.
                view: v3d
                roundness: root.roundness

                basePos: Qt.vector3d((index % 10) * 9 - 40, 0,
                                     -Math.floor(index / 10) * 11)

                // The one thing a crowd must not do is blink together. The
                // seed is deterministic, so the run is still repeatable - it
                // is shared by default, which is right for one character and
                // exactly wrong for forty of them.
                blinkSeed: index + 1

                activity: root.walking ? Character.Activity.Walking
                                       : Character.Activity.Idle

                // One character reports its tier, so an "auto" run says which
                // way it went rather than only what it cost.
                onEffectiveDetailChanged: if (index === 0)
                                              root._probeTier = effectiveDetail
            }
        }
    }

    Rectangle {
        x: 0; y: 0
        width: _label.implicitWidth + 20
        height: _label.implicitHeight + 12
        color: Qt.rgba(1, 1, 1, 0.85)
    }

    Text {
        id: _label
        x: 10; y: 6
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 14
        color: "#1b1b1f"
    }

    Text {
        x: 10
        y: root.height - implicitHeight - 8
        font.family: _label.font.family
        font.pixelSize: 11
        color: "#6b6b72"
        text: "up/down characters   1-4 minimal/low/high/auto   r round   w walk   t/g camera"
    }
}
