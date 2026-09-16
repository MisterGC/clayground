// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// HeadRow - the head at all three levels of detail, side by side. Three heads
// identical but for their detail level, so the thing being judged - whether a
// level swap is visible - can be judged by looking at two of them at once
// rather than by remembering what the last one looked like.
//
// What it is for:
//
//   * The face is drawn in a shader, not built out of boxes. That buys the
//     eyes their lids, their irises and a gaze direction for nothing, and it
//     means the cheap levels can THIN the face instead of deleting it.
//     Whether that actually reads at size is not something the change itself
//     can prove.
//   * A blink, a glance and a talking mouth are all one uniform each. They
//     are also the three things most likely to look wrong, because they move,
//     so they run here - on the plugin's own animators, not on the lab clock.
//   * report() carries the head's height in pixels and the eye's, so "still
//     readable at ninety pixels" is a claim that can be checked rather than
//     an impression. The `work` and `far` shots are those distances.
//
// Whether the six expressions are distinguishable FROM EACH OTHER is a
// different question, and the faces scene answers it: this one shows one face
// at a time and one face is always judged against a memory of the last.
//
// NO PROBES. Everything that moves here is wall-clock - the blink timer, the
// talk loop, an emotion settling - and a probe has to be pure enough that two
// stepped runs of one seed reproduce it byte for byte. The two numbers worth
// having, headPx and eyePx, depend on where the camera happens to be, which
// is the viewer's business and not the record's. So this scene registers
// none and the lab's plot stays empty while it is loaded. That is correct,
// not missing.
//
// SHOTS ARE ANGLES, so `work` and `far` cannot ask for a distance. They ask
// for a bigger BOX instead: bounds() takes the shot name and returns the row
// grown about its centre, which is what the lab's framing turns into a
// distance. Measured at 1400x900, all three heads in frame: face 170 px of
// head at 12.7 units out, work 83 px at 25.5, far 34 px at 63.7. The bench
// stood at 5.6, 11 and 26 for the same three - it framed one head against
// the WIDTH of its tile, where the lab fits the whole row inside the
// vertical field of view, so the distances differ and the pixels are what
// carries.
//
// The row stands on the paper; the lab's rig keeps its home on the floor.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "heads"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings): verbs, chips on the card, carried in state() -------
    /*! Which head the readout measures: "high", "low" or "minimal". */
    property string subject: "high"
    /*! What the face does: idle, talk, or one of the five emotions. */
    property string activity: "idle"
    /*! Draw the subject on its own, without a neighbour to compare it to. */
    property bool solo: false
    /*! Where the eyes point, -1..1 in each axis. */
    property vector2d gaze: Qt.vector2d(0, 0)
    /*! The blink timer, which is the plugin's and not the lab clock's. */
    property bool blinking: true

    // --- the three tiers ------------------------------------------------------
    readonly property var tiers: ["high", "low", "minimal"]
    readonly property var levels: ({
        "high": Head.Detail.High, "low": Head.Detail.Low, "minimal": Head.Detail.Minimal
    })
    readonly property var activities: ({
        "idle":      Head.Activity.Idle,
        "talk":      Head.Activity.Talk,
        "joy":       Head.Activity.ShowJoy,
        "anger":     Head.Activity.ShowAnger,
        "sad":       Head.Activity.ShowSadness,
        "disgust":   Head.Activity.ShowDisgust,
        "surprised": Head.Activity.ShowSurprise
    })
    readonly property int subjectIndex: Math.max(0, scene.tiers.indexOf(scene.subject))

    // --- layout ------------------------------------------------------------------
    readonly property real spread: 1.85
    readonly property real standY: 0
    readonly property real headHeight: 1.7
    readonly property real headHalf: 1.2
    function xOf(i) { return scene.solo ? 0 : (i - 1) * scene.spread }

    // The shot's own box. "work" and "far" are distances, and a shot cannot
    // carry one - so they are the same row in a box grown about its centre,
    // which is the only handle a scene has on how far the lab stands back.
    function bounds(shotName) {
        const k = shotName === "work" ? 2.0 : shotName === "far" ? 5.0 : 1.0
        const x = (scene.solo ? 0 : scene.spread) + scene.headHalf
        const cy = scene.standY + scene.headHeight * 0.5
        const hy = scene.headHeight * 0.5
        return [Qt.vector3d(-x * k, cy - hy * k, -scene.headHalf * k),
                Qt.vector3d(x * k, cy + hy * k, scene.headHalf * k)]
    }
    readonly property var shots: ({
        "face":    { yaw: 0,  pitch: 5 },
        "quarter": { yaw: 22, pitch: 5 },
        "profile": { yaw: 90, pitch: 5 },
        "work":    { yaw: 20, pitch: 5 },
        "far":     { yaw: 15, pitch: 5 }
    })
    readonly property string defaultShot: "face"
    readonly property real nearest: 1.2
    readonly property real plotWindow: 10

    // --- readiness -----------------------------------------------------------------
    property var heads: []
    readonly property bool ready: scene.heads.length === scene.tiers.length

    // --- the numbers ------------------------------------------------------------------
    /*! Height of the subject's head on screen, in pixels; 0 before the view. */
    function headPx() {
        // mapFrom3DScene warns rather than returning nothing when the View3D
        // has not adopted its camera yet, and a warning makes clayrender exit 2.
        if (!scene.view || !scene.view.camera) return 0
        const h = scene.heads[scene.subjectIndex]
        if (!h) return 0
        const base = h.scenePosition
        const top = base.plus(Qt.vector3d(0, h.height, 0))
        const a = scene.view.mapFrom3DScene(base)
        const b = scene.view.mapFrom3DScene(top)
        if (a.z <= 0 || b.z <= 0) return 0
        return Math.abs(b.y - a.y)
    }
    /*! Width of one eye on screen, the number a tier swap is really judged at. */
    function eyePx() {
        const h = scene.heads[scene.subjectIndex]
        if (!h) return 0
        return scene.headPx() * (h.eyeWidth / Math.max(1e-6, h.height))
    }

    // --- verbs, state, readout ---------------------------------------------------------
    function verbs() {
        return {
            "subject":  (s) => { if (scene.tiers.indexOf(s) >= 0) scene.subject = s },
            "activity": (a) => {
                scene.activity = (a !== undefined && a !== null
                                  && scene.activities[a] !== undefined) ? a : "idle"
            },
            "solo":     (b) => { scene.solo = (b === undefined) ? true : (b === true || b === "on") },
            "gaze":     (x, y) => { scene.gaze = Qt.vector2d(Number(x) || 0, Number(y) || 0) }
        }
    }
    readonly property var choices: [
        { verb: "subject", key: "choice.subject", current: scene.subject,
          options: scene.tiers.map(v => ({ value: v, key: "detail." + v })) },
        { verb: "activity", key: "choice.activity", current: scene.activity,
          options: ["idle", "talk", "joy", "anger", "sad", "disgust", "surprised"]
                   .map(v => ({ value: v, key: "activity." + v })) },
        { verb: "solo", key: "choice.solo", current: scene.solo ? "on" : "off",
          options: ["off", "on"].map(v => ({ value: v, key: "solo." + v })) }
    ]
    function choiceState() {
        return { subject: subject, activity: activity, solo: solo,
                 gazeX: gaze.x, gazeY: gaze.y }
    }
    function loadChoices(s) {
        if (!s) return
        if (s.subject !== undefined) subject = s.subject
        if (s.activity !== undefined) activity = s.activity
        if (s.solo !== undefined) solo = s.solo === true || s.solo === "on"
        if (s.gazeX !== undefined || s.gazeY !== undefined)
            gaze = Qt.vector2d(s.gazeX || 0, s.gazeY || 0)
    }

    function report() {
        return {
            subject: scene.subject,
            tiers: scene.tiers,
            headPx: scene.headPx(), eyePx: scene.eyePx(),
            activity: scene.activity,
            gaze: { x: scene.gaze.x, y: scene.gaze.y },
            blinking: scene.blinking,
            solo: scene.solo,
            ready: scene.ready
        }
    }
    function readout() {
        return [
            { key: "read.headPx", value: LabLang.num(scene.headPx(), 0) + " px" },
            { key: "read.eyePx", value: LabLang.num(scene.eyePx(), 1) + " px" }
        ]
    }

    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.tiers.length; ++i) {
            if (scene.solo && i !== scene.subjectIndex) continue
            out.push({ at: Qt.vector3d(scene.xOf(i), scene.standY + scene.headHeight, 0),
                       text: LabLang.t("detail." + scene.tiers[i]), above: true })
        }
        return out
    }

    // --- the heads ----------------------------------------------------------------------
    // One component so the three cannot differ by accident: detail is the only
    // thing passed in, which is the whole experiment.
    component Bust: Head {
        id: bust
        required property int index
        // basePos, never x. A Head is a BodyPart and BodyPart binds position
        // to basePos - an x set here is overwritten the moment that binding
        // evaluates and all three sit on top of each other.
        basePos: Qt.vector3d(scene.xOf(bust.index), scene.standY, 0)
        visible: !scene.solo || scene.subjectIndex === bust.index
        detail: scene.levels[scene.tiers[bust.index]]
        activity: scene.activities[scene.activity]
        autoBlink: scene.blinking
        gaze: scene.gaze
        skinColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        hairColor: scene.silhouette ? LabTheme.ink : "#734120"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"

        Component.onCompleted: {
            const list = scene.heads.slice()
            list[bust.index] = bust
            scene.heads = list
        }
    }

    Bust { index: 0 }
    Bust { index: 1 }
    Bust { index: 2 }
}
