// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// MoveSheet - a loadable move set the way GestureSheet shows the gestures and
// GaitSheet shows a walk: all of it at once, same figure, same light, same
// angle, labelled, and NOTHING MOVING.
//
// The SET is what is being judged, not any one move. A kick looked at on its
// own is looked at against a memory of the last one, and a memory grades
// generously - which is how a "high" roundhouse that never got the foot past
// the hip survived being watched a dozen times. Side by side against a jab, a
// front kick and a stance, "is this move the thing its name says" is a
// question one frame answers.
//
// TWO SHEETS, one scene. With the move verb empty it draws the SET - one
// column per move, each frozen at the phase it is meant to be read at. Given
// a move's name it draws that one move as a strip of `frames` phases, which
// is how a move's TIMING is judged rather than its peak.
//
// Every pose comes from Character.applyMovePose(), the pure model the set
// itself plays, so the sheet cannot show a stance the shipped move does not
// have. What the set contains is read from a hidden probe character rather
// than from the row: the row's length is the answer, so it cannot be the
// thing that answers - QML calls that a binding loop and clayrender turns it
// into a non-zero exit.
//
// HOW TO READ IT. Two questions, in this order. Can a stranger name each
// column from its SILHOUETTE alone (the lab's S key)? And is every figure ON
// the floor? The lab's paper is at y = 0 and each column stands on it, so a
// crouch that sinks or a stance that floats shows as a gap - and the two foot
// readings are that gap as a number, in leg heights.
import QtQuick
import QtQuick3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "moves"
    property real time: 0
    property var view: null
    property bool silhouette: false

    /*! The set on the sheet. Any name Character.moveSet accepts. */
    readonly property string set: "martial arts"
    /*! One move drawn as a strip of phases, or "" for the whole set. */
    property string move: ""

    // --- knobs (numbers) ----------------------------------------------------------
    Parameter { id: pFrames; name: "frames"; value: 10; from: 2; to: 24; stepSize: 1 }
    Parameter { id: pIntensity; name: "intensity"; value: 0.5; from: 0; to: 1 }
    readonly property int frames: Math.max(2, Math.round(pFrames.value))

    readonly property real bodyHeight: 10

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
    function readAtOf(name) {
        return scene.readAt[name] === undefined ? 0.5 : scene.readAt[name]
    }

    /*! What the set offers, asked of the probe and never of the row. */
    readonly property var names: {
        const out = []
        for (let i = 0; i < _probe.moves.length; ++i) out.push(_probe.moves[i].name)
        return out
    }
    readonly property bool strip: scene.move !== ""
    readonly property int count: scene.strip ? scene.frames : Math.max(1, scene.names.length)

    // --- layout: centred on the origin, figures facing the reader (+Z) ----------
    readonly property real spacing: scene.bodyHeight * 0.9
    readonly property var row: Sheet.layout(scene.count, scene.spacing)

    function bounds() {
        return [Qt.vector3d(-scene.row.span * 0.5, 0, -scene.bodyHeight * 0.5),
                Qt.vector3d(scene.row.span * 0.5, scene.bodyHeight * 1.3, scene.bodyHeight * 0.5)]
    }
    readonly property var shots: ({
        "quarter": { yaw: 35,  pitch: 4 },
        "front":   { yaw: 0,   pitch: 4 },
        "side":    { yaw: 90,  pitch: 4 },
        "back":    { yaw: 180, pitch: 4 },
        "top":     { yaw: 0,   pitch: 84 }
    })
    readonly property string defaultShot: "quarter"
    readonly property real nearest: 5
    readonly property real plotWindow: 6

    // --- the model the probes read -------------------------------------------------
    // A character that is never drawn, so the sheet can ask the set what it
    // contains - and answer its probes - without asking the row.
    ParametricCharacter {
        id: _probe
        visible: false
        moveSet: scene.set
        bodyHeight: scene.bodyHeight
        actionIntensity: pIntensity.value
        activity: Character.Activity.Idle
        autoBlink: false
        gazeBehaviour: false
    }

    // A move's own cycle length is not reachable through Character's API -
    // MoveSet.tableFor() is the set's, and the character does not forward it -
    // so the probes walk one move per SECOND of sim time. It is a clock for
    // the probes and nothing else: every pose on the sheet is frozen, and the
    // phase below only says which frame of the shown move the record carries.
    readonly property real cycleS: 1
    readonly property string probeMove: scene.strip ? scene.move : "stance"
    readonly property real phase: Sheet.phaseOf(scene.time, scene.cycleS)
    function poseNow() { return _probe.movePoseAt(scene.probeMove, scene.phase) }

    /*!
        Where a foot is, in LEG HEIGHTS above the floor: forward kinematics of
        the two-segment leg, the same idea as gait.js's ankleZ turned through
        ninety degrees. The thigh and the shin are half a leg each, so a
        straight leg puts the ankle at 0 and a fully folded one at 1; the
        pose's own lift raises the whole body with it. Roll and toe are left
        out - what the two readings are about is how high the knee takes the
        foot and whether anything sinks.
    */
    function footHeight(leg, lift) {
        const r = Math.PI / 180
        const hip = leg.upper[0]
        const knee = leg.lower[0]
        return lift + 1 - (0.5 * Math.cos(hip * r) + 0.5 * Math.cos((hip + knee) * r))
    }
    function feet() {
        const p = scene.poseNow()
        if (!p) return { low: 0, high: 0 }
        const a = scene.footHeight(p.rightLeg, p.lift)
        const b = scene.footHeight(p.leftLeg, p.lift)
        return { low: Math.min(a, b), high: Math.max(a, b) }
    }

    Probe { name: "moves.count"; expr: () => scene.names.length }
    Probe { name: "moves.footLow"; unit: "legs"; expr: () => scene.feet().low }
    Probe { name: "moves.footHigh"; unit: "legs"; expr: () => scene.feet().high }

    // --- readiness ---------------------------------------------------------------------
    property int applied: 0
    readonly property bool ready: scene.count > 0 && scene.applied >= scene.count

    property int _generation: 0
    function invalidate() { scene._generation++ }
    function restart() {
        scene.applied = 0
        for (let i = 0; i < _figures.count; ++i) {
            const f = _figures.objectAt(i)
            if (f) f.counted = false
        }
        scene.invalidate()
    }
    onMoveChanged: scene.restart()
    onFramesChanged: scene.restart()
    onNamesChanged: scene.restart()
    Connections {
        target: pIntensity
        function onValueChanged() { scene.invalidate() }
    }

    // --- verbs, state, readout ---------------------------------------------------------------
    function verbs() {
        return { "move": (n) => { scene.move = n === undefined || n === null ? "" : n } }
    }
    readonly property var choices: [
        { verb: "move", key: "choice.move", current: scene.move,
          options: [{ value: "", key: "move.set" }].concat(
                       scene.names.map(n => ({ value: n, key: "move." + n }))) }
    ]
    function choiceState() { return { move: move } }
    function loadChoices(s) {
        if (!s) return
        if (s.move !== undefined) move = s.move
    }

    /*! The numbers behind the sheet, language-neutral. */
    function report() {
        const f = scene.feet()
        return {
            set: _probe.moveSetName, count: scene.names.length,
            move: scene.move, shown: scene.probeMove, frames: scene.frames,
            intensity: pIntensity.value, phase: scene.phase,
            footLow: f.low, footHigh: f.high, ready: scene.ready
        }
    }
    /*! The card's rows, translated at call time. */
    function readout() {
        const r = scene.report()
        return [
            { key: "read.count", value: LabLang.num(r.count, 0) },
            { key: "read.floor", value: LabLang.num(r.footLow, 3) + " " + LabLang.t("unit.legHeights") },
            { key: "read.footHigh", value: LabLang.num(r.footHigh, 3) + " " + LabLang.t("unit.legHeights") },
            { key: "read.phase", value: LabLang.num(r.phase, 3) }
        ]
    }

    // The move's name under each column, or the phase under each strip frame.
    // Fourteen names across one frame collide at any size worth reading, so
    // they hang at two depths and alternate.
    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.count; ++i) {
            const text = scene.strip
                       ? "t = " + LabLang.num(i / Math.max(1, scene.frames - 1), 2)
                       : (scene.names.length > i ? LabLang.t("move." + scene.names[i]) : "")
            out.push({ at: Qt.vector3d(scene.row.xs[i],
                                       i % 2 === 0 ? 0 : -scene.bodyHeight * 0.62, 0),
                       text: text })
        }
        return out
    }

    // --- the figures ---------------------------------------------------------------------------
    Repeater3D {
        id: _figures
        model: scene.count

        ParametricCharacter {
            id: figure
            required property int index
            readonly property string what: scene.strip
                ? scene.move : (scene.names.length > index ? scene.names[index] : "")
            readonly property real at: scene.strip
                ? figure.index / Math.max(1, scene.frames - 1) : scene.readAtOf(figure.what)

            position: Qt.vector3d(scene.row.xs[index], 0, 0)

            moveSet: scene.set
            bodyHeight: scene.bodyHeight
            realism: 0.3
            roundness: 0.15
            detail: Character.Detail.High
            autoBlink: false
            gazeBehaviour: false
            activity: Character.Activity.Idle
            actionIntensity: pIntensity.value

            skin: scene.silhouette ? LabTheme.ink : "#e8beac"
            topClothing: scene.silhouette ? LabTheme.ink : "#b8453a"
            bottomClothing: scene.silhouette ? LabTheme.ink : "#2f3d52"
            footColor: scene.silhouette ? LabTheme.ink : "#4a3728"
            hairTone: scene.silhouette ? LabTheme.ink : "#2b2119"
            eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"

            // The hands are not written by applyMovePose - they are handPose's
            // - so the sheet asks the model what the move wants and sets it,
            // exactly as the gesture sheet does for an action. Without it a
            // sweep plants a fist on the floor.
            function pose() {
                if (figure.what === "") return
                const p = figure.movePoseAt(figure.what, figure.at)
                if (p === null) return
                figure.handPose = p.hand
                figure.applyMovePose(figure.what, figure.at)
            }

            property bool counted: false
            function take() {
                figure.pose()
                if (figure.counted) return
                figure.counted = true
                scene.applied++
            }

            // The first pose waits out IdleAnim's 200 ms: it zeroes what it
            // does not own, and a pose written inside that window is animated
            // away under the capture. Later changes re-pose synchronously.
            Timer {
                id: _first
                interval: 300
                onTriggered: figure.take()
            }
            Component.onCompleted: _first.start()
            Connections {
                target: scene
                function on_GenerationChanged() { figure.take() }
            }
        }
    }
}
