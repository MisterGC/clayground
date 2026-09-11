// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// GestureSheet - every hand and arm gesture side by side, one frozen figure
// each, the way GaitSheet shows a walk: same figure, same light, same angle,
// labelled, and NOTHING MOVING.
//
// The SET is what is being judged, not any one pose. A gesture looked at on
// its own is looked at against a memory of the last one, and a memory grades
// generously - which is how a fist that never closed and a guard with its
// elbows out at shoulder height both survived for as long as they were only
// ever seen one at a time. Side by side, "clearly recognisable at a glance"
// is a question the sheet answers in one frame.
//
// The columns are Sheet.GESTURES and each kind is driven differently: "rest"
// leaves the idle pose, "hand" shapes the fingers and holds the arm out the
// way somebody shows you their hand, "gesture" runs the real GestureAnim
// solver with its settle cut to a frame, and "action" freezes a cycle of
// action.js at the phase the column is named for. Pick one column with the
// gesture verb and the sheet shows that one alone, centred.
//
// HOW TO READ IT. Ask each column one question and no other: can a stranger
// name the gesture from the SILHOUETTE alone? The lab's S key takes the
// lighting and the colours away and leaves exactly that. Then ask it at the
// distance the character is actually seen from - the scale knob shrinks every
// figure in place, and a gesture that stops reading around a third of the
// frame's height is a gesture that will not survive a wide shot.
//
// The four shots are the four views worth checking a change against: the
// three-quarter one most of these are seen at, plus front, side and back. A
// shot is the CAMERA's angle, and the row lies along X, so front, quarter and
// back look across the sheet while side looks down it - one column in front
// of the next, which is a view of one gesture rather than of the set. Pick
// the column first and side becomes its profile.
import QtQuick
import QtQuick3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "gestures"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings and flags): verbs, chips on the card ------------------
    /*! One gesture of Sheet.GESTURES, or "" for the whole set. */
    property string gesture: ""
    /*! Fingers or a single box: the two levels of detail a hand ships at. */
    property bool fingers: true
    /*! Cartoon hands - gloved and oversized, the way a comic draws them. */
    property bool gloves: false

    // --- knobs (numbers): kernel Parameters, live while this scene is loaded ----
    Parameter { id: pIntensity; name: "intensity"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pWorkHeight; name: "workHeight"; value: 0.35; from: 0; to: 1 }
    Parameter { id: pScale; name: "scale"; value: 1.0; from: 0.15; to: 1 }

    readonly property real bodyHeight: 10

    /*! The columns on show: the whole set, or the one the verb named. */
    readonly property var columns: {
        if (scene.gesture === "") return Sheet.GESTURES
        const one = Sheet.gestureNamed(scene.gesture)
        return one === null ? Sheet.GESTURES : [one]
    }

    // --- layout: centred on the origin, figures facing the reader (+Z) ----------
    readonly property real spacing: scene.bodyHeight * 0.82
    readonly property var row: Sheet.layout(scene.columns.length, scene.spacing)

    // The figures, never the aim markers: a marker sits nine units in front of
    // its column and framing it would push the whole sheet into the distance.
    // The height allows for the overhead point, which is the tallest column.
    function bounds() {
        return [Qt.vector3d(-scene.row.span * 0.5, 0, -scene.bodyHeight * 0.4),
                Qt.vector3d(scene.row.span * 0.5, scene.bodyHeight * 1.25, scene.bodyHeight * 0.4)]
    }
    readonly property var shots: ({
        "quarter": { yaw: 35,  pitch: 4 },
        "front":   { yaw: 0,   pitch: 4 },
        "side":    { yaw: 90,  pitch: 4 },
        "back":    { yaw: 180, pitch: 4 }
    })
    readonly property string defaultShot: "quarter"
    readonly property real nearest: 5
    readonly property real plotWindow: 6

    // --- where an aimed gesture aims -------------------------------------------
    // As an offset from the figure's OWN feet rather than a place in the room.
    // The columns stand apart, and one shared target would turn each of them by
    // a different amount and pose their arms differently - which is the one
    // thing a side-by-side comparison must not do.
    readonly property vector3d pointAtOffset: Qt.vector3d(-5, 7, 9)
    readonly property vector3d pointHighAtOffset: Qt.vector3d(-3, 15, 7)
    readonly property vector3d presentAtOffset: Qt.vector3d(-4, 5, 9)
    function markerFor(name) {
        return name === "point" ? scene.pointAtOffset
             : name === "pointHigh" ? scene.pointHighAtOffset
             : scene.presentAtOffset
    }

    // --- the model the probes read ----------------------------------------------
    // The first figure is the reference: every figure has the same build and
    // the same knobs, so its pose model is the sheet's. actionPoseAt() is the
    // pure model action.js answers with - no clock, no solver, no settle.
    property var probeFigure: null
    function actionPose(name, at) {
        return scene.probeFigure ? scene.probeFigure.actionPoseAt(name, at) : null
    }
    readonly property real guardElbow: {
        pIntensity.value
        const p = scene.actionPose("fight", 0)
        return p ? p.rightArm.lower[0] : 0
    }
    readonly property real workElbow: {
        pIntensity.value; pWorkHeight.value
        const p = scene.actionPose("use", 0.5)
        return p ? p.rightArm.lower[0] : 0
    }
    readonly property real workLean: {
        pIntensity.value; pWorkHeight.value
        const p = scene.actionPose("use", 0.5)
        return p ? p.belly[0] + p.chest[0] : 0
    }

    Probe { name: "gestures.count"; expr: () => scene.columns.length }
    Probe { name: "gestures.guardElbow"; unit: "deg"; expr: () => scene.guardElbow }
    Probe { name: "gestures.workElbow"; unit: "deg"; expr: () => scene.workElbow }
    Probe { name: "gestures.workLean"; unit: "deg"; expr: () => scene.workLean }

    // --- readiness ----------------------------------------------------------------
    // A column counts once it HOLDS the pose it is labelled with, which is not
    // the same moment for the two kinds: a frozen action is there as soon as it
    // is written, an aimed gesture only when its solver says it has arrived.
    property int applied: 0
    readonly property bool ready: scene.applied >= scene.columns.length

    // A re-pose is synchronous, so a --set or a chip landing after ready was
    // already true still shows the new pose under the capture. Only a change
    // of WHAT IS ON THE SHEET clears the tally: a knob that re-poses thirteen
    // frozen columns leaves every one of them holding its own gesture, and
    // clearing the tally there would hang `ready` on an aimed column whose
    // solver has nothing new to arrive at.
    property int _generation: 0
    function invalidate() { scene._generation++ }
    onGestureChanged: {
        scene.applied = 0
        for (let i = 0; i < _figures.count; ++i) {
            const f = _figures.objectAt(i)
            if (f) f.counted = false
        }
        scene.invalidate()
    }
    onFingersChanged: scene.invalidate()
    onGlovesChanged: scene.invalidate()
    Connections {
        target: pIntensity
        function onValueChanged() { scene.invalidate() }
    }
    Connections {
        target: pWorkHeight
        function onValueChanged() { scene.invalidate() }
    }

    // --- verbs, state, readout ------------------------------------------------------
    function verbs() {
        return {
            "gesture": (n) => { scene.gesture = n === undefined || n === null ? "" : n },
            "fingers": (on) => { scene.fingers = on === undefined ? true : !!on },
            "gloves":  (on) => { scene.gloves = on === undefined ? true : !!on }
        }
    }
    readonly property var choices: [
        { verb: "gesture", key: "choice.gesture", current: scene.gesture,
          options: [{ value: "", key: "gesture.set" }].concat(
                       Sheet.GESTURES.map(g => ({ value: g.name, key: "gesture." + g.name }))) },
        { verb: "fingers", key: "choice.detail", current: scene.fingers,
          options: [{ value: true, key: "detail.high" }, { value: false, key: "detail.low" }] },
        { verb: "gloves", key: "choice.gloves", current: scene.gloves,
          options: [{ value: false, key: "gloves.off" }, { value: true, key: "gloves.on" }] }
    ]
    function choiceState() { return { gesture: gesture, fingers: fingers, gloves: gloves } }
    function loadChoices(s) {
        if (!s) return
        if (s.gesture !== undefined) gesture = s.gesture
        if (s.fingers !== undefined) fingers = !!s.fingers
        if (s.gloves !== undefined) gloves = !!s.gloves
    }

    /*! The numbers behind the sheet, language-neutral. */
    function report() {
        return {
            gesture: scene.gesture, count: scene.columns.length,
            fingers: scene.fingers, gloves: scene.gloves,
            scale: pScale.value, intensity: pIntensity.value, workHeight: pWorkHeight.value,
            guardElbow: scene.guardElbow, workElbow: scene.workElbow,
            workLean: scene.workLean, ready: scene.ready
        }
    }
    /*! The card's rows, translated at call time. */
    function readout() {
        const r = scene.report()
        return [
            { key: "read.count", value: LabLang.num(r.count, 0) },
            { key: "read.guardElbow", value: LabLang.qty(r.guardElbow, "°", 0) },
            { key: "read.workElbow", value: LabLang.qty(r.workElbow, "°", 0) },
            { key: "read.workLean", value: LabLang.qty(r.workLean, "°", 1) }
        ]
    }

    // The column's own name under each figure. Thirteen names across one frame
    // collide at any font size a label is worth reading at, so they are hung
    // at two depths and alternate - two rows of captions, each name still
    // under its own figure.
    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.columns.length; ++i)
            out.push({ at: Qt.vector3d(scene.row.xs[i],
                                       i % 2 === 0 ? 0 : -scene.bodyHeight * 0.62, 0),
                       text: LabLang.t("gesture." + scene.columns[i].name) })
        return out
    }

    // --- the figures -------------------------------------------------------------------
    Repeater3D {
        id: _figures
        model: scene.columns.length

        ParametricCharacter {
            id: figure
            required property int index
            readonly property var spec: scene.columns[index]

            position: Qt.vector3d(scene.row.xs[index], 0, 0)
            scale: Qt.vector3d(pScale.value, pScale.value, pScale.value)

            bodyHeight: scene.bodyHeight
            realism: 0.3
            roundness: 0.15
            // Fixed, never Auto: a sheet whose columns decided for themselves
            // how much hand to draw would be comparing two things at once.
            detail: scene.fingers ? Character.Detail.High : Character.Detail.Low
            gloves: scene.gloves
            handScale: scene.gloves ? 1.35 : 1.0
            autoBlink: false
            gazeBehaviour: false
            activity: Character.Activity.Idle
            actionIntensity: pIntensity.value
            workHeight: pWorkHeight.value
            // The solver's ease is the one thing on this sheet that is time:
            // cut to a frame, a pose is simply there.
            gestureSettleMs: 16

            skin: scene.silhouette ? LabTheme.ink : "#e8beac"
            topClothing: scene.silhouette ? LabTheme.ink : "#3d6fb4"
            bottomClothing: scene.silhouette ? LabTheme.ink : "#2c3e50"
            footColor: scene.silhouette ? LabTheme.ink : "#4a3728"
            hairTone: scene.silhouette ? LabTheme.ink : "#5c3a21"
            eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"

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
                    // "auto", never a named arm: which hand a character reaches
                    // with is part of what is being judged, and forcing the far
                    // one produces an arm across the chest that nothing in
                    // normal use would ever ask for.
                    else if (s.name === "present")
                        figure.presentAt(figure.scenePosition.plus(scene.presentAtOffset))
                    else
                        figure.pointAt(figure.scenePosition.plus(scene.markerFor(s.name)))
                } else if (s.kind === "action") {
                    // The hands are not written by applyActionPose - they are
                    // handPose's - so the sheet asks the model what the action
                    // wants and sets it.
                    figure.handPose = figure.actionPoseAt(s.action, s.at).hand
                    figure.applyActionPose(s.action, s.at)
                }
            }

            // The hand columns hold the right arm OUT, forearm level and clear
            // of the torso, the way somebody shows you their hand. Left down at
            // the character's side, the whole column is one figure standing
            // still with a lump at its hip and the shape under judgement is the
            // one thing nobody can see. Written straight onto the joints:
            // IdleAnim owns them and has stopped by the time this is called.
            function showHand() {
                figure.rightArm.upperArm.eulerRotation = Qt.vector3d(-30, 0, 34)
                figure.rightArm.lowerArm.eulerRotation = Qt.vector3d(-80, 0, 0)
                // A quarter turn, so the back of the hand faces the camera at
                // the three-quarter view the sheet defaults to: the fingers
                // read against the background rather than against the palm.
                figure.rightArm.hand.eulerRotation = Qt.vector3d(0, 45, 0)
            }

            property bool counted: false
            function count() {
                if (figure.counted) return
                figure.counted = true
                scene.applied++
            }
            function take() {
                figure.pose()
                if (figure.spec.kind !== "gesture") figure.count()
            }

            // The first pose waits out IdleAnim's 200 ms: it zeroes what it does
            // not own, and a pose written inside that window is animated away
            // under the capture. Every later change re-poses SYNCHRONOUSLY.
            Timer {
                id: _first
                interval: 300
                onTriggered: figure.take()
            }
            Component.onCompleted: {
                if (figure.index === 0) scene.probeFigure = figure
                _first.start()
            }
            Component.onDestruction: if (scene.probeFigure === figure) scene.probeFigure = null
            Connections {
                target: scene
                function on_GenerationChanged() { figure.take() }
            }
            onGestureSettledChanged: if (figure.gestureSettled) figure.count()
        }
    }

    // What a point is aimed at. Visible because "the finger is on it" is the
    // half of an aim that no number shows: the marker says which way it missed.
    Repeater3D {
        id: _markers
        model: scene.columns.length
        Model {
            required property int index
            readonly property var spec: scene.columns[index]
            source: "#Sphere"
            visible: !scene.silhouette && spec.kind === "gesture" && spec.name !== "thumbsUp"
            position: Qt.vector3d(scene.row.xs[index], 0, 0).plus(scene.markerFor(spec.name))
            scale: Qt.vector3d(0.008, 0.008, 0.008)
            materials: PrincipledMaterial {
                baseColor: "#c0392b"
                lighting: PrincipledMaterial.NoLighting
            }
        }
    }
}
