// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// CrowdField - the answer to "how many of these can I have?", on the machine
// being asked. It exists because that question has no general answer and a
// wrong one is expensive: a lab built on a developer's machine and shipped to
// a classroom full of ten-year-old hardware is a lab that excludes the people
// it was for. This runs where the doubt is.
//
// WHAT TO READ. `draws` is the number that matters and `verts` is the number
// that does not, which is the least obvious thing here and the most useful. A
// character is 22 boxes at Low, 44 at High and 21 at Minimal, and a box is
// very nearly a draw call - so making those boxes rounder or smoother (the
// `roundness` knob) is close to free while having more of them is not. The
// absolute milliseconds are this machine's; the SHAPE of the result - draw
// call bound, vertex cheap - is what carries to another one.
//
// THE LAB'S STAGE ADDS A SHADOW PASS. The bench lit its crowd with two
// shadowless lights precisely so the draw count would be the crowd's own;
// LabStage3D's key light casts, which draws the whole scene a second time
// into the shadow map. That is the lab's rig and a scene cannot switch it
// off, so the numbers here come out about twice the bench's. Measured on this
// machine, 1400x900, detail low, walking, after the warm-up:
//
//     count    draws    verts    per character
//        1        69     2394
//       20       882    31692    42.8, against the bench's 22 boxes at Low
//
// 42.8 over 22 is 1.95: the shadow pass costs very nearly one extra draw per
// box, and it is a FACTOR, not an offset - the two counts fit a straight line
// of 42.8 draws per character on an intercept of 26. That intercept is
// BASELINE: the floor, the grid quad and the stage's own passes, what is left
// when the characters are taken off the top. It is a CONSTANT measured once,
// not something the scene can read - a crowd cannot hide itself to find out.
//
// A STEPPED RECORD READS ZERO, and that is the honest answer. renderStats
// only says anything about frames that were actually drawn: offscreen nothing
// is, and under `clayrender --paused` every --eval runs before the first
// frame, so both record 0 for draws, verts and per-character. Two runs of the
// gate therefore agree byte for byte on nothing having been drawn. With
// frames running the same configuration reads 882 draws and 31692 vertices on
// this machine, repeatably. frameMs reads 0 on top of that whenever the lab's
// frame ticker is stopped, because an average of frames nobody drew is not a
// frame time.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "crowd"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- knobs -----------------------------------------------------------------
    Parameter { id: pCount; name: "count"; value: 20; from: 1; to: 80; stepSize: 1 }
    // Here because this is the scene that answers what a chamfer costs, and
    // the answer is the point: it changes verts and leaves draws alone.
    Parameter { id: pRound; name: "roundness"; value: 0; from: 0; to: 0.3 }
    readonly property int count: Math.max(1, Math.round(pCount.value))

    // --- choices ---------------------------------------------------------------
    /*! "auto", "high", "low" or "minimal". */
    property string detail: "auto"
    /*! Whether they walk. An animated character costs CPU a still one does not,
        and this is the only way to tell a scene bound by drawing from one bound
        by animating. */
    property bool walking: true

    readonly property int level: scene.detail === "high" ? Character.Detail.High
                               : scene.detail === "minimal" ? Character.Detail.Minimal
                               : scene.detail === "low" ? Character.Detail.Low
                               : Character.Detail.Auto

    // --- the field -------------------------------------------------------------
    // The bench's grid - ten to a row, nine apart, eleven between rows -
    // recentred on the origin so the lab frames it about its own home pivot.
    readonly property int perRow: 10
    readonly property int cols: Math.min(scene.count, scene.perRow)
    readonly property int rows: Math.ceil(scene.count / scene.perRow)
    readonly property real bodyHeight: 10
    function xOf(i) { return (i % scene.perRow) * 9 - (scene.cols - 1) * 4.5 }
    function zOf(i) { return -Math.floor(i / scene.perRow) * 11 + (scene.rows - 1) * 5.5 }

    function bounds(shotName) {
        const k = shotName === "far" ? 2.0 : 1.0
        const hx = (scene.cols - 1) * 4.5 + 3
        const hz = (scene.rows - 1) * 5.5 + 3
        const top = scene.bodyHeight * 1.05
        return [Qt.vector3d(-hx * k, top * 0.5 * (1 - k), -hz * k),
                Qt.vector3d(hx * k, top * 0.5 * (1 + k), hz * k)]
    }
    readonly property var shots: ({
        "quarter": { yaw: 20, pitch: 18 },
        "front":   { yaw: 0,  pitch: 12 },
        "top":     { yaw: 0,  pitch: 84 },
        "far":     { yaw: 20, pitch: 18 }
    })
    readonly property string defaultShot: "quarter"
    readonly property real nearest: 10
    readonly property real plotWindow: 20

    readonly property bool ready: scene.built >= scene.count
    property int built: 0

    // --- the measurement ----------------------------------------------------------
    // drawCallCount and drawVertexCount are the "extended" half of renderStats
    // and Qt does not collect them unless asked - without this they read zero
    // and the whole scene says nothing. The view arrives after the scene, so
    // this is armed on the property, not in Component.onCompleted.
    onViewChanged: {
        if (scene.view && scene.view.renderStats)
            scene.view.renderStats.extendedDataCollectionEnabled = true
    }
    readonly property var stats: scene.view ? scene.view.renderStats : null

    /*! Draw calls the scene costs with no characters in it: the floor, the
        grid quad and the stage's own passes. MEASURED, not read - a crowd
        cannot hide itself to find out. 1400x900, Low: 69 draws at one
        character and 882 at twenty, which is 42.8 each on an intercept of 26. */
    readonly property int baseline: 26

    readonly property int draws: scene.stats ? scene.stats.drawCallCount : 0
    readonly property int verts: scene.stats ? scene.stats.drawVertexCount : 0
    readonly property real perCharacter: Sheet.drawsPerCharacter(scene.draws, scene.baseline,
                                                                 scene.count)

    // Averaged, and only after a warm-up: the first second and a half is
    // shader compilation and the first upload of every geometry, which is real
    // cost but not the steady state anyone is asking about.
    property real _accFrame: 0
    property real _accRender: 0
    property int samples: 0
    function resetAverage() { scene._accFrame = 0; scene._accRender = 0; scene.samples = 0 }
    onCountChanged: scene.resetAverage()
    onDetailChanged: scene.resetAverage()
    onWalkingChanged: scene.resetAverage()

    Timer { id: _warmup; interval: 1500; running: true }
    Timer {
        interval: 50; repeat: true; running: true
        onTriggered: {
            const s = scene.stats
            if (!s || _warmup.running) return
            scene._accFrame += s.frameTime
            scene._accRender += s.renderTime
            scene.samples++
        }
    }
    readonly property real frameMs: scene.samples > 0 ? scene._accFrame / scene.samples : 0
    readonly property real renderMs: scene.samples > 0 ? scene._accRender / scene.samples : 0

    // A frame time measured while nothing is drawing frames is not a frame
    // time. The lab's clock owns the ticker, so the probe asks it.
    // Through an untyped argument on purpose: Lab.clock is declared QtObject,
    // so a member access on it is a lint error however the member is spelled,
    // and the FrameAnimation that drives a world-less lab is SimClock's own.
    function _tickerOf(c) { return c ? c["_frameTicker"] : null }
    readonly property bool _ticking: {
        const t = scene._tickerOf(Lab.clock)
        return !!(t && t.running)
    }

    Probe { name: "crowd.draws"; expr: () => scene.draws }
    Probe { name: "crowd.verts"; expr: () => scene.verts }
    Probe { name: "crowd.perCharacter"; expr: () => scene.perCharacter }
    Probe { name: "crowd.frameMs"; unit: "ms"; expr: () => scene._ticking ? scene.frameMs : 0 }

    // One character reports its tier, so an "auto" run says which way it went
    // rather than only what it cost.
    property int tier0: -1
    readonly property string effectiveTier:
        scene.tier0 < 0 ? "" : ["minimal", "low", "high"][scene.tier0]

    // --- verbs, state, readout ----------------------------------------------------
    function verbs() {
        return {
            "detail": (d) => {
                scene.detail = (d === "high" || d === "low" || d === "minimal") ? d : "auto"
            },
            // "play" is walking here: there is no transport to start, and the
            // verb vocabulary is shared across the kit's scenes on purpose.
            "play":   (b) => {
                scene.walking = (b === undefined) ? true
                              : (b === true || b === "on" || b === 1)
            }
        }
    }
    readonly property var choices: [
        { verb: "detail", key: "choice.detail", current: scene.detail,
          options: ["auto", "high", "low", "minimal"]
                   .map(v => ({ value: v, key: "detail." + v })) },
        { verb: "play", key: "choice.walking", current: scene.walking ? "on" : "off",
          options: [{ value: "on", key: "walk.on" }, { value: "off", key: "walk.off" }] }
    ]
    function choiceState() { return { detail: detail, walking: walking } }
    function loadChoices(s) {
        if (!s) return
        if (s.detail !== undefined) detail = s.detail
        if (s.walking !== undefined) walking = s.walking === true || s.walking === "on"
    }

    function report() {
        return {
            count: scene.count, detail: scene.detail, effectiveTier: scene.effectiveTier,
            walking: scene.walking, roundness: pRound.value,
            draws: scene.draws, verts: scene.verts,
            perCharacter: scene.perCharacter,
            baseline: scene.baseline,
            expectedDraws: Sheet.expectedDraws(scene.count, scene.effectiveTier),
            renderMs: scene.renderMs, frameMs: scene.frameMs, samples: scene.samples,
            ready: scene.ready
        }
    }
    function readout() {
        return [
            { key: "read.draws", value: LabLang.num(scene.draws, 0) },
            { key: "read.perCharacter", value: LabLang.num(scene.perCharacter, 1) },
            { key: "read.verts", value: LabLang.num(scene.verts, 0) },
            { key: "read.frameMs", value: LabLang.qty(scene.frameMs, "ms", 2) },
            { key: "read.renderMs", value: LabLang.qty(scene.renderMs, "ms", 2) }
        ]
    }
    readonly property var labels: []

    // --- the crowd --------------------------------------------------------------------
    Repeater3D {
        id: _crowd
        model: scene.count

        ParametricCharacter {
            id: figure
            required property int index

            bodyHeight: scene.bodyHeight
            detail: scene.level
            // Auto measures the character against the viewport, so it needs to
            // be told which one. Note the id is NOT `view`: written as
            // `view: view` inside a delegate the right-hand side resolves to
            // this object's own property and quietly assigns null, and an Auto
            // character with no view sits at Low forever.
            view: scene.view
            roundness: pRound.value

            basePos: Qt.vector3d(scene.xOf(figure.index), 0, scene.zOf(figure.index))

            // The one thing a crowd must not do is blink together. The seed is
            // deterministic, so the run is still repeatable - it is shared by
            // default, which is right for one character and exactly wrong for
            // forty of them.
            blinkSeed: figure.index + 1

            activity: scene.walking ? Character.Activity.Walking : Character.Activity.Idle

            skin: scene.silhouette ? LabTheme.ink : "#d38d5f"
            hairTone: scene.silhouette ? LabTheme.ink : "#734120"
            eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"
            topClothing: scene.silhouette ? LabTheme.ink : "#4169e1"
            bottomClothing: scene.silhouette ? LabTheme.ink : "#708090"

            onEffectiveDetailChanged: if (figure.index === 0) scene.tier0 = figure.effectiveDetail
            Component.onCompleted: {
                if (figure.index === 0) scene.tier0 = figure.effectiveDetail
                scene.built++
            }
            Component.onDestruction: scene.built--
        }
    }
}
