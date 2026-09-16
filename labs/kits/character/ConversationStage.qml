// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ConversationStage - the half of a conversation nobody was animating. One
// character says a line; the other either listens or does not, and the
// `listening` verb swaps between the two so the difference can be seen rather
// than remembered.
//
// What it is for:
//
//   * A listener is mostly its eyes. Whether holding a face, breaking away
//     and marking phrase endings actually reads as attention - rather than as
//     a character with a twitch - is not something the change can prove about
//     itself.
//   * The phrase boundaries come off the SPEAKER'S MOUTH, not its script, so
//     this has to look right on a line that was never written down. `play`
//     reads the recording nobody has a transcript of.
//   * Both characters are the same component with one property different.
//     Anything that looks wrong on the listener and right on the speaker is
//     this scene's fault, not the feature's.
//
// THE STAGING. Two people facing each other can only ever show ONE face to
// a camera - which is why film shoots a conversation over a shoulder and
// cuts. The two stand squared up to each other and never move; the camera
// stands behind whoever is speaking, so the LISTENER - the subject - faces
// the lens and the speaker's shoulder fills the edge of the frame. When the
// roles swap the shot flips to the reverse angle. The aim runs 120 ms after
// the turn is asked for: lookAt solves against where the body is GOING, and
// asking in the same tick solves it against where the body still is.
//
// THE DIALOGUE. While the lab's clock runs on its own (`live`) the two take
// turns: one says a line, a pause, the other answers, the roles and the
// staging swap with each turn - so the scene IS a conversation to look at
// rather than two figures waiting for a verb. While the clock is being
// stepped (a record, the gate, --paused) nothing starts, so a stepped run
// stays a run of nothing moving. `dialogue` off holds them silent; `say` and
// `play` say one thing on the current speaker.
//
// ABOUT THE PROBES. The listener's gaze, brow and nod are ListenAnim's, which
// runs on the WALL clock - the lab's clock cannot see it and cannot reproduce
// it. The four curves are worth watching live while a line plays; a stepped
// record of this scene is honest zeros, and a record taken while something
// IS playing is a sampling of real time that a second run will not repeat.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "conversation"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings): verbs, chips on the card, carried in state() -------
    /*! Who is talking: "left" is the first character, "right" the second. */
    property string speaker: "left"
    /*! Off pins the listener to what it was before any of this: a body that
        happens to be standing there while someone talks at it. */
    property bool listening: true
    /*! The last thing the speaker was asked to say, for report(). */
    property string lastLine: ""
    /*! Bound by the lab: true while its clock runs on its own. */
    property bool live: false
    /*! Whether the two keep talking by themselves while live. */
    property bool dialogue: true
    /*! Asks the lab to frame again: the roles swapped, the shot flips. */
    signal reframe()

    // The turn-taking. A line is said, the speaker falls silent, a beat of
    // sim time passes, the other one takes over. The lines are the kit's own
    // strings so the loop reads in both languages; what a TTS voice makes of
    // a German line is the platform's business.
    readonly property int lineCount: 4
    property int turn: 0
    property real _quietSince: -1
    onTimeChanged: {
        if (!scene.live || !scene.dialogue || !scene._staged) { scene._quietSince = -1; return }
        if (scene.speakerChar.speaking) { scene._quietSince = scene.time; return }
        if (scene._quietSince < 0) { scene._quietSince = scene.time; return }
        if (scene.time - scene._quietSince < 1.6) return
        if (scene.turn > 0) scene.speaker = scene.speaker === "left" ? "right" : "left"
        scene.turn++
        scene.speak(LabLang.t("line." + (1 + (scene.turn - 1) % scene.lineCount)))
        scene._quietSince = scene.time
    }

    readonly property int speakerIndex: scene.speaker === "right" ? 1 : 0
    readonly property string defaultLine:
        "Hello there. This is one phrase, and this is another. Do you follow me so far?"

    // The two spots. Nobody moves when the roles swap: the CAMERA swaps sides
    // instead, the way a film cuts to the reverse angle, so the listener is
    // always the one whose face the lens has.
    readonly property vector3d posA: Qt.vector3d(-4.0, 0, 5)
    readonly property vector3d posB: Qt.vector3d(3.0, 0, -3)

    readonly property Character speakerChar: scene.speakerIndex === 0 ? _a : _b
    readonly property Character listenerChar: scene.speakerIndex === 0 ? _b : _a

    // --- framing -----------------------------------------------------------------
    // Over the shoulder, and from the side so the depth the staging buys is
    // visible as depth. The bench had one fixed camera at (0, 11.5, 26); here
    // the lab frames whatever box covers both figures from the angle a shot
    // names.
    // The side shot asks for a bigger box, and it has to: the two figures are
    // ten units apart in DEPTH, so from the side the near one is a third
    // closer to the camera than the box's centre and grows out of a frame that
    // fits the centre exactly - it loses its feet off the bottom edge.
    // The over-the-shoulder shot: the camera stands behind the SPEAKER, so
    // the listener - the subject - faces the lens and the speaker's shoulder
    // enters the frame from the edge, near and large. The yaw is computed
    // from where the two stand, and flips to the reverse angle when the
    // roles swap.
    // Thirty degrees off the line between them, or the speaker's back would
    // sit square in front of the face it is talking to.
    readonly property real overYaw: {
        const l = scene.listenerChar.basePos, k = scene.speakerChar.basePos
        return Math.atan2(k.x - l.x, k.z - l.z) * 180 / Math.PI + 32
    }
    function bounds(shotName) {
        const top = _a.headPos.y + _a.headHeight + 0.6
        if (shotName === "over") {
            const l = scene.listenerChar.basePos, k = scene.speakerChar.basePos
            // the listener, and the near half of the way to the speaker
            const mx = l.x + (k.x - l.x) * 0.4, mz = l.z + (k.z - l.z) * 0.4
            return [Qt.vector3d(Math.min(l.x, mx) - 2.5, 0, Math.min(l.z, mz) - 2.5),
                    Qt.vector3d(Math.max(l.x, mx) + 2.5, top, Math.max(l.z, mz) + 2.5)]
        }
        const k = 1.35
        const cx = (scene.posA.x + scene.posB.x) * 0.5
        const cz = (scene.posA.z + scene.posB.z) * 0.5
        const hx = Math.abs(scene.posB.x - scene.posA.x) * 0.5 + 2.5
        const hz = Math.abs(scene.posA.z - scene.posB.z) * 0.5 + 2.5
        return [Qt.vector3d(cx - hx * k, top * 0.5 * (1 - k), cz - hz * k),
                Qt.vector3d(cx + hx * k, top * 0.5 * (1 + k), cz + hz * k)]
    }
    readonly property var shots: ({
        "over": { yaw: scene.overYaw, pitch: 12 },
        "side": { yaw: scene.overYaw + 90, pitch: 6 }
    })
    readonly property string defaultShot: "over"
    readonly property real nearest: 4
    readonly property real plotWindow: 10

    readonly property bool ready: _a.head !== null && _b.head !== null && scene._staged

    // --- the staging ----------------------------------------------------------------
    property bool _staged: false
    function stage() {
        // Both squared up to each other; the camera, behind the speaker, gets
        // the listener's face and the speaker's back - which is what an
        // over-the-shoulder shot is.
        _a.turnTo(_b.scenePosition)
        _b.turnTo(_a.scenePosition)
        _aimLater.restart()
    }
    // A speaker looks at the person it is speaking to. ListenAnim only
    // animates the listening half - the other half is staging, and a stage
    // that leaves the speaker staring into the middle distance is testing the
    // listener against a wall.
    function aim() {
        const spk = scene.speakerChar
        const to = scene.listenerChar
        if (!to.head) return
        const p = to.head.scenePosition
        spk.lookAt(Qt.vector3d(p.x, p.y + to.head.eyeLine, p.z))
        scene._staged = true
    }
    Timer { id: _aimLater; interval: 120; onTriggered: scene.aim() }
    onSpeakerChanged: { scene.stage(); scene.reframe() }
    onViewChanged: scene.stage()
    Component.onCompleted: scene.stage()

    // --- what it says -------------------------------------------------------------------
    function speak(what) {
        const line = (what === undefined || what === null || what === "")
                   ? scene.defaultLine : ("" + what)
        scene.lastLine = line
        scene.speakerChar.say(line)
    }
    function playRecording() {
        // No transcript exists for this one, which is the point: the phrase
        // boundaries are read off the mouth either way.
        const url = Qt.resolvedUrl("hello.wav").toString()
        scene.lastLine = url
        scene.speakerChar.say(url)
    }
    function stopAll() { scene.dialogue = false; _a.stopSpeaking(); _b.stopSpeaking() }

    // --- the readings ---------------------------------------------------------------------
    Probe { name: "conversation.gazeX"; expr: () => scene.listenerChar.head
                                                 ? scene.listenerChar.head.gaze.x : 0 }
    Probe { name: "conversation.gazeY"; expr: () => scene.listenerChar.head
                                                 ? scene.listenerChar.head.gaze.y : 0 }
    Probe { name: "conversation.nod"; unit: "deg"
            expr: () => scene.listenerChar.head ? scene.listenerChar.head.nodAmount : 0 }
    Probe { name: "conversation.brow"
            expr: () => scene.listenerChar.head ? scene.listenerChar.head.browFlash : 0 }

    // --- verbs, state, readout ----------------------------------------------------------------
    function verbs() {
        return {
            "say":       (t) => scene.speak(t),
            "play":      () => scene.playRecording(),
            "stop":      () => scene.stopAll(),
            "dialogue":  (b) => { scene.dialogue = b === undefined || b === true || b === "on" },
            "speaker":   (s) => { scene.speaker = s === "right" ? "right" : "left" },
            "listening": (b) => {
                scene.listening = (b === undefined) ? true
                                : (b === true || b === "on" || b === 1)
            }
        }
    }
    readonly property var choices: [
        { verb: "speaker", key: "choice.speaker", current: scene.speaker,
          options: ["left", "right"].map(v => ({ value: v, key: "speaker." + v })) },
        { verb: "listening", key: "choice.listening", current: scene.listening ? "on" : "off",
          options: [{ value: "on", key: "listening.on" },
                    { value: "off", key: "listening.off" }] },
        { verb: "dialogue", key: "choice.dialogue", current: scene.dialogue ? "on" : "off",
          options: [{ value: "on", key: "dialogue.on" }, { value: "off", key: "dialogue.off" }] }
    ]
    function choiceState() { return { speaker: speaker, listening: listening, dialogue: dialogue } }
    function loadChoices(s) {
        if (!s) return
        if (s.speaker !== undefined) speaker = s.speaker
        if (s.listening !== undefined) listening = s.listening === true || s.listening === "on"
        if (s.dialogue !== undefined) dialogue = s.dialogue === true || s.dialogue === "on"
    }

    function _headOf(c) {
        const h = c.head
        return h ? { gazeX: h.gaze.x, gazeY: h.gaze.y, brow: h.browFlash, nod: h.nodAmount }
                 : { gazeX: 0, gazeY: 0, brow: 0, nod: 0 }
    }
    function report() {
        return {
            listening: scene.listening, speaker: scene.speaker,
            left: scene._headOf(_a), right: scene._headOf(_b),
            leftSpeaking: _a.speaking, rightSpeaking: _b.speaking,
            leftListening: _a.listening, rightListening: _b.listening,
            lastLine: scene.lastLine, ready: scene.ready
        }
    }
    function readout() {
        const l = scene._headOf(scene.listenerChar)
        return [
            { key: "read.gaze", value: LabLang.num(l.gazeX, 2) + "  " + LabLang.num(l.gazeY, 2) },
            { key: "read.nod", value: LabLang.qty(l.nod, "°", 1) },
            { key: "read.brow", value: LabLang.num(l.brow, 3) },
            { key: "read.speaking",
              value: LabLang.t(scene.speakerChar.speaking ? "listening.on" : "listening.off") }
        ]
    }

    // Which of the two is which, over their heads - the one thing a still of
    // this scene cannot say for itself.
    readonly property var labels: {
        LabLang.lang
        const out = []
        const pair = [_a, _b]
        for (let i = 0; i < 2; ++i) {
            const c = pair[i]
            if (!c) continue
            out.push({ at: Qt.vector3d(c.basePos.x, c.headPos.y + c.headHeight + 0.3, c.basePos.z),
                       text: LabLang.t(i === scene.speakerIndex ? "role.speaker" : "role.listener"),
                       above: true })
        }
        return out
    }

    // --- the two of them --------------------------------------------------------------------
    Character {
        id: _a
        basePos: scene.posA
        detail: Character.Detail.High
        blinkSeed: 3
        // Whoever is not speaking listens - and only while the scene says
        // listening is on, which is the whole comparison.
        listeningTo: (scene.listening && scene.speakerIndex === 1) ? _b : null
        skinColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        hairColor: scene.silhouette ? LabTheme.ink : "#734120"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"
        torsoColor: scene.silhouette ? LabTheme.ink : "red"
        hipColor: scene.silhouette ? LabTheme.ink : "darkblue"
        armColor: scene.silhouette ? LabTheme.ink : "#4169e1"
        legColor: scene.silhouette ? LabTheme.ink : "#708090"
        handColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        footColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
    }
    Character {
        id: _b
        basePos: scene.posB
        detail: Character.Detail.High
        blinkSeed: 11
        listeningTo: (scene.listening && scene.speakerIndex === 0) ? _a : null
        // Dressed differently on purpose: two identical figures swapping
        // roles cannot be told apart from one shot to the reverse.
        skinColor: scene.silhouette ? LabTheme.ink : "#c98a63"
        hairColor: scene.silhouette ? LabTheme.ink : "#2b1d14"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"
        torsoColor: scene.silhouette ? LabTheme.ink : "#2e9e6b"
        hipColor: scene.silhouette ? LabTheme.ink : "#4a3b2a"
        armColor: scene.silhouette ? LabTheme.ink : "#f0c94a"
        legColor: scene.silhouette ? LabTheme.ink : "#8a6a4a"
        handColor: scene.silhouette ? LabTheme.ink : "#c98a63"
        footColor: scene.silhouette ? LabTheme.ink : "#c98a63"
    }
}
