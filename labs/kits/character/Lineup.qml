// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Lineup - six builds, one gait. The parametric character's whole slider
// range standing in a row and walking the same cycle in place, which is the
// claim the plugin makes about itself in one picture: an animation is written
// once and every body wears it. What differs between the figures is what the
// gait model derives from the build - a child's quicker, shorter cycle, a
// heavy figure's slower one - and those are the numbers this scene records.
//
// Every figure is posed by the lab's clock: applyGaitPose(base, phase) each
// step, with each figure's phase taken from ITS OWN cycle length, so the row
// visibly walks at six tempos and a stepped run reproduces every joint.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    readonly property string aspect: "lineup"
    property real time: 0
    property var view: null
    property bool silhouette: false

    /*! "walk" or "run". */
    property string base: "walk"
    /*! An emotion worn by every figure, or empty. */
    property string emotion: ""

    readonly property var builds: Sheet.BUILDS
    readonly property real spacing: 9
    readonly property var row: Sheet.layout(scene.builds.length, scene.spacing)
    readonly property real tallest: 11

    function bounds() {
        return [Qt.vector3d(-row.span * 0.5, 0, -4), Qt.vector3d(row.span * 0.5, scene.tallest * 1.08, 4)]
    }
    readonly property var shots: ({
        "front":   { yaw: 0,  pitch: 6 },
        "quarter": { yaw: 35, pitch: 8 },
        "side":    { yaw: 90, pitch: 3 },
        "top":     { yaw: 0,  pitch: 84 }
    })
    readonly property string defaultShot: "front"
    readonly property real nearest: 6
    readonly property real plotWindow: 4

    // --- posing from the clock ---------------------------------------------------
    // Idle figures, posed by hand every step. IdleAnim zeroes the joints over
    // its first 200 ms; a pose written every step simply wins from then on.
    property var figures: []
    readonly property bool ready: scene.figures.length === scene.builds.length && scene.posed > 0
    property int posed: 0
    function poseAll() {
        for (const f of scene.figures) {
            const c = f.gaitTable(scene.base).cycleMs / 1000
            f.applyGaitPose(scene.base, Sheet.phaseOf(scene.time, c))
        }
        if (scene.figures.length === scene.builds.length) scene.posed++
    }
    onTimeChanged: scene.poseAll()
    onBaseChanged: scene.poseAll()
    // The first pose waits out IdleAnim's 200 ms, so a paused clock still
    // shows a posed row rather than six figures at attention.
    onFiguresChanged: if (scene.figures.length === scene.builds.length) _first.restart()
    Timer { id: _first; interval: 300; onTriggered: scene.poseAll() }
    onEmotionChanged: { for (const f of scene.figures) f.setEmotion(scene.emotion); scene.poseAll() }

    // --- the numbers ------------------------------------------------------------------
    function cycleOf(i) {
        const f = scene.figures[i]
        return f ? f.gaitTable(scene.base).cycleMs / 1000 : 0
    }
    function speedOf(i) {
        const f = scene.figures[i]
        return f ? (scene.base === "run" ? f.runSpeed : f.walkSpeed) : 0
    }
    function hipOf(i) {
        const f = scene.figures[i]
        if (!f) return 0
        return f.gaitPoseAt(scene.base, Sheet.phaseOf(scene.time, scene.cycleOf(i))).rightLeg.upper
    }
    // One cycle length and one hip curve per build: the record says how the
    // same walk paces six bodies, and the plot shows six periods at once.
    Probe { name: "lineup.cycle.player"; unit: "s"; expr: () => scene.cycleOf(0) }
    Probe { name: "lineup.cycle.thinker"; unit: "s"; expr: () => scene.cycleOf(1) }
    Probe { name: "lineup.cycle.eater"; unit: "s"; expr: () => scene.cycleOf(2) }
    Probe { name: "lineup.cycle.hero"; unit: "s"; expr: () => scene.cycleOf(3) }
    Probe { name: "lineup.cycle.child"; unit: "s"; expr: () => scene.cycleOf(4) }
    Probe { name: "lineup.cycle.stylized"; unit: "s"; expr: () => scene.cycleOf(5) }
    Probe { name: "lineup.hip.player"; unit: "deg"; expr: () => scene.hipOf(0) }
    Probe { name: "lineup.hip.thinker"; unit: "deg"; expr: () => scene.hipOf(1) }
    Probe { name: "lineup.hip.eater"; unit: "deg"; expr: () => scene.hipOf(2) }
    Probe { name: "lineup.hip.hero"; unit: "deg"; expr: () => scene.hipOf(3) }
    Probe { name: "lineup.hip.child"; unit: "deg"; expr: () => scene.hipOf(4) }
    Probe { name: "lineup.hip.stylized"; unit: "deg"; expr: () => scene.hipOf(5) }

    function verbs() {
        return {
            "base":    (b) => { scene.base = b === "run" ? "run" : "walk" },
            "emotion": (e) => { scene.emotion = e === undefined || e === null ? "" : e }
        }
    }
    readonly property var choices: [
        { verb: "base", key: "choice.base", current: scene.base,
          options: ["walk", "run"].map(v => ({ value: v, key: "base." + v })) },
        { verb: "emotion", key: "choice.emotion", current: scene.emotion,
          options: ["", "happy", "sad", "angry"].map(v => ({ value: v, key: "emotion." + v })) }
    ]
    function choiceState() { return { base: base, emotion: emotion } }
    function loadChoices(s) {
        if (!s) return
        if (s.base !== undefined) base = s.base
        if (s.emotion !== undefined) emotion = s.emotion
    }
    function report() {
        const out = []
        for (let i = 0; i < scene.builds.length; ++i)
            out.push({ name: scene.builds[i].name, bodyHeight: scene.builds[i].bodyHeight,
                       cycleS: scene.cycleOf(i), speed: scene.speedOf(i),
                       legHeight: scene.figures[i] ? scene.figures[i].legHeight : 0 })
        return { base: scene.base, emotion: scene.emotion, count: out.length, builds: out, ready: scene.ready }
    }
    function readout() {
        const rows = []
        for (let i = 0; i < scene.builds.length; ++i)
            rows.push({ key: "build." + scene.builds[i].name,
                        value: LabLang.qty(scene.cycleOf(i), "s", 2) + "   "
                               + LabLang.num(scene.speedOf(i), 1) + " u/s" })
        return rows
    }
    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.builds.length; ++i)
            out.push({ at: Qt.vector3d(scene.row.xs[i], scene.builds[i].bodyHeight * 1.06, 0),
                       text: LabLang.t("build." + scene.builds[i].name), above: true })
        return out
    }

    Repeater3D {
        id: _figures
        model: scene.builds.length
        ParametricCharacter {
            id: figure
            required property int index
            readonly property var build: scene.builds[index]
            position: Qt.vector3d(scene.row.xs[index], 0, 0)
            bodyHeight: build.bodyHeight
            realism: build.realism
            maturity: build.maturity
            femininity: build.femininity
            mass: build.mass
            muscle: build.muscle
            roundness: 0.15
            detail: Character.Detail.Low
            autoBlink: !scene.silhouette
            gazeBehaviour: false
            activity: Character.Activity.Idle
            skin: scene.silhouette ? LabTheme.ink : build.skin
            hairTone: scene.silhouette ? LabTheme.ink : build.hair
            topClothing: scene.silhouette ? LabTheme.ink : build.top
            bottomClothing: scene.silhouette ? LabTheme.ink : build.bottom
            eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"
            Component.onCompleted: {
                const list = scene.figures.slice()
                list[figure.index] = figure
                scene.figures = list
            }
            Component.onDestruction: {
                const list = scene.figures.slice()
                list[figure.index] = null
                scene.figures = list.filter(f => f !== null)
            }
        }
    }
}
