// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// FaceSheet - the six expressions side by side, one head each, and the reason
// it is a sheet rather than one head with a verb to press: "these six are
// distinguishable" is a claim about the SET, not about any one of them. A face
// judged on its own is judged against a memory of the last one, and a memory
// grades generously - neutral and sadness looked fine one at a time for as
// long as they were only ever seen one at a time.
//
// What it is for:
//
//   * All six at once, same head, same light, same angle, labelled. The only
//     thing that differs between them is Head.activity.
//   * The verb `expression` blows one up to fill the frame, for judging a
//     single face at the size it will actually be read at; "" puts the sheet
//     back.
//   * The face is a shader, so an expression is nothing but its uniforms.
//     report() prints all sixty of them, which is what makes "distinct" a
//     number rather than an impression - the plugin's suite in tests/qml_head
//     asserts on the same ten values per face.
//
// The bench this was ported from gave every face its own View3D tile so each
// sat dead centre of its own frame. One lab has one camera, so the six stand
// in a row 2.2 units apart instead and the outer ones are seen slightly from
// the side. That is the price of the shared rig; the readings are unaffected,
// and the `expression` verb is how a face is judged without a neighbour.
//
// ABOUT THE PROBE. The expression uniforms a head WEARS are written by
// Head.activity's own animations, which run on the wall clock - not pure. The
// probe therefore reads Head.expressionTargets(activity), the table those
// animations ease toward, so `faces.distinct` (1.206 on the committed table)
// is the same number from the first stepped sample, cold or warm. report()
// carries both: `faces` is what each head wears right now, `distinct` is the
// table's. Every head still gets toEmotionDuration 1, so the picture agrees
// with the table one frame after the row exists.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "faces"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings): verbs, chips on the card, carried in state() -------
    /*! One expression by name, alone and centred - or "" for the whole sheet. */
    property string expression: ""

    // --- the six ----------------------------------------------------------------
    readonly property var names: Sheet.EXPRESSIONS
    /*! Head.Activity per expression name, in the sheet's reading order. */
    readonly property var activities: ({
        "neutral":   Head.Activity.Idle,
        "happy":     Head.Activity.ShowJoy,
        "sad":       Head.Activity.ShowSadness,
        "angry":     Head.Activity.ShowAnger,
        "disgust":   Head.Activity.ShowDisgust,
        "surprised": Head.Activity.ShowSurprise
    })

    readonly property int soloIndex: scene.names.indexOf(scene.expression)
    readonly property bool solo: scene.soloIndex >= 0

    // --- layout: centred on the origin, every face towards +Z --------------------
    // A head is about 1.5 units tall with its hair on, and it is NOT scaled up:
    // the lab's one rig frames whatever bounds() says.
    //
    // The row stands on the paper. The lab's rig keeps its home pivot on the
    // floor too, so a head can be approached to a hand's breadth.
    readonly property real spacing: 2.2
    readonly property real standY: 0
    readonly property var row: Sheet.layout(scene.names.length, scene.spacing)
    // A little larger than the head really is (1.54 with the hair, about
    // 1.2 across): the rig fits a SPHERE around the box against the vertical
    // field of view, and a box measured to the pixel leaves a solo face with
    // its chin on the bottom edge.
    readonly property real headHeight: 1.7
    readonly property real headHalf: 1.2

    function bounds() {
        const top = scene.standY + scene.headHeight
        if (scene.solo)
            return [Qt.vector3d(-scene.headHalf, scene.standY, -scene.headHalf),
                    Qt.vector3d(scene.headHalf, top, scene.headHalf)]
        const x = scene.row.xs[scene.names.length - 1] + scene.headHalf
        return [Qt.vector3d(-x, scene.standY, -scene.headHalf),
                Qt.vector3d(x, top, scene.headHalf)]
    }
    // Face on, twenty degrees off axis (where the old box eye showed its own
    // side wall), and full profile.
    //
    // Five degrees rather than the two a face wants, and the two degrees are
    // not a rounding: below about three, OrbitCamera3D's height floor stops
    // honouring a close framing at all. It divides by max(0.08, sin(pitch)),
    // so under 4.6 degrees it answers a distance of its own - 3.1 units here,
    // where a solo head loses its chin off the bottom of the frame - instead
    // of the 4.4 the framing asked for. Five clears it with margin at every
    // bounds() this scene returns.
    readonly property var shots: ({
        "face":    { yaw: 0,  pitch: 5 },
        "quarter": { yaw: 22, pitch: 5 },
        "profile": { yaw: 90, pitch: 5 }
    })
    readonly property string defaultShot: "face"
    readonly property real nearest: 1.5
    readonly property real plotWindow: 10

    // --- the numbers -------------------------------------------------------------
    property var heads: []
    property bool _settled: false
    onHeadsChanged: if (scene.heads.length === scene.names.length) _settle.restart()
    Timer { id: _settle; interval: 300; onTriggered: scene._settled = true }
    readonly property bool ready: scene.heads.length === scene.names.length && scene._settled

    /*! The ten shader uniforms one face is wearing, language-neutral. */
    function faceOf(name) {
        const i = scene.names.indexOf(name)
        const h = i < 0 ? null : scene.heads[i]
        if (!h) return null
        return {
            expression: name,
            cornerLift: h.mouthCornerLift, skew: h.mouthSkew,
            open: h.mouthOpen, wide: h.mouthWide, round: h.mouthRound,
            hood: h.eyeHood, squint: h.eyeSquint,
            browAngle: h.browAngle, browRise: h.browRise, browSkew: h.browSkew
        }
    }

    function _allFaces() {
        const out = []
        for (const n of scene.names) {
            const f = scene.faceOf(n)
            if (f) out.push(f)
        }
        return out
    }

    // The one number that is about the SET: how far apart its closest pair is
    // in uniform space. Zero would mean two of the six are the same face.
    // Pure: the targets of the table, not the uniforms mid-ramp.
    function targetOf(name) {
        const i = scene.names.indexOf(name)
        const h = i < 0 ? null : scene.heads[i]
        return h ? h.expressionTargets(scene.activities[name]) : null
    }
    function _allTargets() {
        const out = []
        for (const n of scene.names) {
            const f = scene.targetOf(n)
            if (f) out.push(f)
        }
        return out
    }
    Probe {
        name: "faces.distinct"
        expr: () => {
            const f = scene._allTargets()
            return f.length === scene.names.length ? Sheet.distinctness(f) : 0
        }
    }

    // --- verbs, state, readout ----------------------------------------------------
    function verbs() {
        return {
            "expression": (n) => {
                scene.expression = (n === undefined || n === null) ? "" : n
            }
        }
    }
    readonly property var choices: [
        { verb: "expression", key: "choice.expression", current: scene.expression,
          options: [""].concat(scene.names).map(v => ({ value: v, key: "face." + v })) }
    ]
    function choiceState() { return { expression: expression } }
    function loadChoices(s) {
        if (!s) return
        if (s.expression !== undefined) expression = s.expression
    }

    function report() {
        const faces = {}
        for (const n of scene.names) faces[n] = scene.faceOf(n)
        return {
            shown: scene.expression,
            count: scene.names.length,
            distinct: scene.heads.length === scene.names.length
                    ? Sheet.distinctness(scene._allTargets()) : 0,
            faces: faces,
            ready: scene.ready
        }
    }

    function readout() {
        const rows = [{ key: "read.distinct", value: LabLang.num(scene.report().distinct, 3) }]
        const f = scene.solo ? scene.faceOf(scene.expression) : null
        if (f) {
            rows.push({ key: "read.mouth",
                        value: "lift " + LabLang.num(f.cornerLift, 2)
                             + "  skew " + LabLang.num(f.skew, 2)
                             + "  open " + LabLang.num(f.open, 2) })
            rows.push({ key: "read.lips",
                        value: "wide " + LabLang.num(f.wide, 2)
                             + "  round " + LabLang.num(f.round, 2) })
            rows.push({ key: "read.eyes",
                        value: "hood " + LabLang.num(f.hood, 2)
                             + "  squint " + LabLang.num(f.squint, 2) })
            rows.push({ key: "read.brows",
                        value: LabLang.qty(f.browAngle, "°", 0)
                             + "  rise " + LabLang.num(f.browRise, 3)
                             + "  skew " + LabLang.num(f.browSkew, 3) })
        }
        return rows
    }

    readonly property var labels: {
        LabLang.lang
        const out = []
        if (scene.solo) {
            out.push({ at: Qt.vector3d(0, scene.standY + scene.headHeight, 0),
                       text: LabLang.t("face." + scene.expression), above: true })
            return out
        }
        for (let i = 0; i < scene.names.length; ++i)
            out.push({ at: Qt.vector3d(scene.row.xs[i], scene.standY + scene.headHeight, 0),
                       text: LabLang.t("face." + scene.names[i]), above: true })
        return out
    }

    // --- the heads ------------------------------------------------------------------
    Repeater3D {
        id: _row
        model: scene.names.length

        Head {
            id: bust
            required property int index
            readonly property string name: scene.names[bust.index]

            // basePos, never x. A Head is a BodyPart and BodyPart binds
            // position to basePos - an x set here is overwritten the moment
            // that binding evaluates and all six sit on top of each other.
            basePos: Qt.vector3d(scene.solo ? 0 : scene.row.xs[bust.index], scene.standY, 0)
            visible: !scene.solo || scene.soloIndex === bust.index

            activity: scene.activities[bust.name]
            // One frame, not one second: the emotion's ramp is wall-clock and
            // the lab's clock cannot see it, so it is collapsed to nothing and
            // the ten uniforms stand still for the probe to read.
            toEmotionDuration: 1
            // Off: a blink lands on top of an expression, and a sheet caught
            // mid-blink says the wrong thing about a face.
            autoBlink: false

            skinColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
            hairColor: scene.silhouette ? LabTheme.ink : "#734120"
            eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"

            Component.onCompleted: {
                const list = scene.heads.slice()
                list[bust.index] = bust
                scene.heads = list
            }
            Component.onDestruction: {
                const list = scene.heads.slice()
                list[bust.index] = null
                scene.heads = list.filter(h => h !== null)
            }
        }
    }
}
