// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// GaitSheet - one cycle of one gait, laid out as N frozen figures at
// successive phases, so the whole walk is on one sheet and a flaw that hides
// from a debugger and springs to the eye in motion is on paper.
//
// Every figure is an idle ParametricCharacter with the same Gait object and
// the same build; Character.applyGaitPose(base, t) freezes it at t = i/frames.
// Nothing on the sheet animates. What the lab's clock drives is the PROBES:
// they read the pure pose model at the phase the clock stands in, so a run
// record is the cycle's own curves - hip, knee, arm and lift over time - plus
// the cycle length and the speed the feet ask for. That is the "keyframe
// strip plus cycle timing" a gait record is for.
//
// HOW TO READ IT. t = 0 and t = 0.5 are the CONTACTS: legs furthest apart,
// the leading heel down, the figure at its lowest. t = 0.25 and 0.75 are the
// PASSING positions: legs crossing, the free knee at its highest, the figure
// at its highest if the gait bounces. Between them the arms should oppose the
// legs, the head hold its attitude, and nothing should fold the wrong way.
//
// This is the reference implementation of the kit's scene contract
// (README.md): a Node the lab loads into its View3D, with kernel Parameters
// and Probes as children so the panel, the plot and the record follow the
// scene that is loaded.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "gait"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings): verbs, chips on the card, carried in state() -------
    /*! "walk" or "run". */
    property string base: "walk"
    /*! A gait.js preset for every figure, or empty. */
    property string preset: ""
    /*! An emotion worn on top of the build ("happy", "sad", "angry") or empty. */
    property string emotion: ""

    // --- knobs (numbers): kernel Parameters, live while this scene is loaded ----
    Parameter { id: pFrames; name: "frames"; value: 8; from: 2; to: 16; stepSize: 1 }
    Parameter { id: pMaturity; name: "maturity"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pFemininity; name: "femininity"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pMass; name: "mass"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pMuscle; name: "muscle"; value: 0.5; from: 0; to: 1 }
    readonly property int frames: Math.max(2, Math.round(pFrames.value))
    readonly property real bodyHeight: 10

    Gait { id: sheetGait; preset: scene.preset }
    /*! The shared gait; factors beyond a preset go through it. */
    readonly property Gait gait: sheetGait

    // --- layout: centred on the origin, figures facing +X --------------------------
    readonly property real spacing: scene.bodyHeight * 0.75
    readonly property var row: Sheet.layout(scene.frames, scene.spacing)
    readonly property real facing: 90

    function bounds() {
        return [Qt.vector3d(-row.span * 0.5, 0, -scene.bodyHeight * 0.4),
                Qt.vector3d(row.span * 0.5, scene.bodyHeight * 1.05, scene.bodyHeight * 0.4)]
    }
    // The four views worth checking a gait against. "side" is the classic
    // strip, walking screen-right; "top" is the only angle that shows sway
    // and rock honestly.
    readonly property var shots: ({
        "side":  { yaw: 0,   pitch: 3 },
        "front": { yaw: 90,  pitch: 3 },
        "back":  { yaw: -90, pitch: 3 },
        "top":   { yaw: 0,   pitch: 84 }
    })
    readonly property string defaultShot: "side"
    readonly property real nearest: 6
    readonly property real plotWindow: 3

    // --- the model the probes read ---------------------------------------------------
    // The first figure is the reference: every figure has the same build and
    // the same gait, so its factors are the sheet's.
    property var probeFigure: null
    readonly property var table: {
        // depends on the factors, the base and the figure existing
        if (!scene.probeFigure) return null
        scene.probeFigure.gaitFactors
        return scene.probeFigure.gaitTable(scene.base)
    }
    readonly property real cycleS: table ? table.cycleMs / 1000 : 0
    readonly property real speed: !probeFigure ? 0
                                : scene.base === "run" ? probeFigure.runSpeed : probeFigure.walkSpeed
    readonly property real phase: Sheet.phaseOf(scene.time, scene.cycleS)
    function poseNow() {
        return scene.probeFigure ? scene.probeFigure.gaitPoseAt(scene.base, scene.phase) : null
    }

    Probe { name: "gait.cycle"; unit: "s"; expr: () => scene.cycleS }
    Probe { name: "gait.speed"; unit: "u/s"; expr: () => scene.speed }
    Probe { name: "gait.stride"; unit: "u"; expr: () => scene.speed * scene.cycleS }
    Probe { name: "gait.lift"; unit: "legs"; expr: () => { const p = scene.poseNow(); return p ? p.lift : 0 } }
    Probe { name: "gait.hip"; unit: "deg"; expr: () => { const p = scene.poseNow(); return p ? p.rightLeg.upper : 0 } }
    Probe { name: "gait.knee"; unit: "deg"; expr: () => { const p = scene.poseNow(); return p ? p.rightLeg.lower : 0 } }
    Probe { name: "gait.arm"; unit: "deg"; expr: () => { const p = scene.poseNow(); return p ? p.rightArm.upper : 0 } }

    // --- readiness ----------------------------------------------------------------------
    /*! How many figures have had their first pose put on; wait for \l ready. */
    property int applied: 0
    readonly property bool ready: scene.applied >= scene.frames

    // The first pose has to wait out IdleAnim, which zeroes every joint over
    // its first 200 ms - hence the timer and the counter. Every change after
    // that re-poses SYNCHRONOUSLY in the handler, so a capture on any frame
    // after the change is current.
    property int _generation: 0
    function invalidate() { scene._generation++ }
    onEmotionChanged: scene.invalidate()
    onBaseChanged: scene.invalidate()
    onFramesChanged: scene.applied = 0

    // --- verbs, state, readout ---------------------------------------------------------------
    function verbs() {
        return {
            "base":    (b) => { scene.base = b === "run" ? "run" : "walk" },
            "preset":  (n) => { scene.preset = n === undefined || n === null ? "" : n },
            "emotion": (e) => { scene.emotion = e === undefined || e === null ? "" : e }
        }
    }
    readonly property var choices: [
        { verb: "base", key: "choice.base", current: scene.base,
          options: ["walk", "run"].map(v => ({ value: v, key: "base." + v })) },
        { verb: "preset", key: "choice.preset", current: scene.preset,
          options: [""].concat(sheetGait.presetNames).map(v => ({ value: v, key: "preset." + v })) },
        { verb: "emotion", key: "choice.emotion", current: scene.emotion,
          options: ["", "happy", "sad", "angry"].map(v => ({ value: v, key: "emotion." + v })) }
    ]
    function choiceState() { return { base: base, preset: preset, emotion: emotion } }
    function loadChoices(s) {
        if (!s) return
        if (s.base !== undefined) base = s.base
        if (s.preset !== undefined) preset = s.preset
        if (s.emotion !== undefined) emotion = s.emotion
    }

    /*! The numbers behind the sheet, language-neutral. */
    function report() {
        const c = scene.probeFigure
        const p = c ? c.gaitPoseAt(scene.base, 0) : null
        const off = {}
        if (c) {
            const f = c.gaitFactors
            for (const k in f) {
                const mul = (k === "tempo" || k === "stride" || k === "armSwing"
                             || k === "kneeLift" || k === "handRoll")
                const v = f[k]
                if (mul ? Math.abs(v - 1) > 1e-9 : Math.abs(v) > 1e-9) off[k] = +v.toFixed(3)
            }
        }
        return {
            base: scene.base, preset: scene.preset, presetKnown: sheetGait.presetKnown,
            emotion: scene.emotion, frames: scene.frames,
            build: { maturity: pMaturity.value, femininity: pFemininity.value,
                     mass: pMass.value, muscle: pMuscle.value },
            factors: off,
            cycleS: scene.cycleS, speed: scene.speed, stride: scene.speed * scene.cycleS,
            belly: p ? p.belly[0] : 0, chest: p ? p.chest[0] : 0,
            back: p ? p.chest[0] - p.belly[0] : 0,
            ready: scene.ready
        }
    }
    /*! The card's rows, translated at call time. */
    function readout() {
        const r = scene.report()
        const keys = Object.keys(r.factors)
        return [
            { key: "read.cycle", value: LabLang.qty(r.cycleS, "s", 2) },
            { key: "read.speed", value: LabLang.num(r.speed, 2) + " u/s" },
            { key: "read.stride", value: LabLang.num(r.stride, 2) + " u" },
            { key: "read.back", value: LabLang.qty(r.back, "°", 1) },
            { key: "read.factors", wrap: true, value: keys.length === 0 ? "—"
                                        : keys.map(k => k + " " + r.factors[k]).join("  ") }
        ]
    }

    // Frame labels under each figure: the phase, and what that phase is called.
    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.frames; ++i) {
            const t = i / scene.frames
            const kind = Sheet.phaseKind(t)
            out.push({ at: Qt.vector3d(scene.row.xs[i], 0, 0),
                       text: "t = " + LabLang.num(t, 3)
                             + (kind !== "" ? "\n" + LabLang.t("phase." + kind) : "") })
        }
        return out
    }

    // --- the figures -------------------------------------------------------------------------
    Repeater3D {
        id: _figures
        model: scene.frames

        ParametricCharacter {
            id: figure
            required property int index
            readonly property real phase: index / scene.frames

            position: Qt.vector3d(scene.row.xs[index], 0, 0)
            eulerRotation: Qt.vector3d(0, scene.facing, 0)

            bodyHeight: scene.bodyHeight
            maturity: pMaturity.value
            femininity: pFemininity.value
            mass: pMass.value
            muscle: pMuscle.value
            gait: sheetGait
            realism: 0.3
            roundness: 0.15
            detail: Character.Detail.Low
            autoBlink: false
            gazeBehaviour: false
            activity: Character.Activity.Idle
            skin: scene.silhouette ? LabTheme.ink : "#e8beac"
            topClothing: scene.silhouette ? LabTheme.ink : "#3d6fb4"
            bottomClothing: scene.silhouette ? LabTheme.ink : "#2c3e50"
            footColor: scene.silhouette ? LabTheme.ink : "#4a3728"
            hairTone: scene.silhouette ? LabTheme.ink : "#5c3a21"
            eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"

            function pose() { figure.applyGaitPose(scene.base, figure.phase) }

            Timer {
                id: _first
                interval: 300
                onTriggered: {
                    figure.setEmotion(scene.emotion)
                    figure.pose()
                    scene.applied++
                }
            }
            Component.onCompleted: {
                if (figure.index === 0) scene.probeFigure = figure
                _first.start()
            }
            Component.onDestruction: if (scene.probeFigure === figure) scene.probeFigure = null
            onGaitFactorsChanged: figure.pose()
            Connections {
                target: scene
                function on_GenerationChanged() {
                    figure.setEmotion(scene.emotion)
                    figure.pose()
                }
            }
        }
    }
}
