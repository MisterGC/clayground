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
// THE STAGING is the bench's, and it is not decoration. Two people facing
// each other can only ever show ONE face to a camera - which is why film
// shoots a conversation over a shoulder and cuts. The LISTENER is the
// subject: it takes the deep spot, keeps its body pointed at the lens and
// turns only its head, which is what keeps its face readable. The speaker
// stands nearer the lens, squares up to the listener and gives the camera a
// profile, which is enough to see a mouth move. `speaker` swaps the two
// positions with the roles. The aim runs 120 ms after the turn is asked for:
// lookAt solves against where the body is GOING, and asking in the same tick
// solves it against where the body still is.
//
// COLD-OPEN SILENT. The bench spoke its line 700 ms after load so a one-shot
// render landed mid-sentence; a lab may not, because the determinism gate
// steps the clock and nothing may be running. Say `say` or `play`.
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

    readonly property int speakerIndex: scene.speaker === "right" ? 1 : 0
    readonly property string defaultLine:
        "Hello there. This is one phrase, and this is another. Do you follow me so far?"

    // The listener takes the deep spot, so whichever one is speaking stands
    // nearer the lens.
    readonly property vector3d farPos: Qt.vector3d(2.5, 0, -2)
    readonly property vector3d nearPos: Qt.vector3d(-5.0, 0, 8)

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
    function bounds(shotName) {
        const k = shotName === "side" ? 1.35 : 1.0
        const top = _a.headPos.y + _a.headHeight + 0.6
        const cx = (scene.nearPos.x + scene.farPos.x) * 0.5
        const cz = (scene.nearPos.z + scene.farPos.z) * 0.5
        const hx = (scene.farPos.x - scene.nearPos.x) * 0.5 + 2.5
        const hz = (scene.nearPos.z - scene.farPos.z) * 0.5 + 2.5
        return [Qt.vector3d(cx - hx * k, top * 0.5 * (1 - k), cz - hz * k),
                Qt.vector3d(cx + hx * k, top * 0.5 * (1 + k), cz + hz * k)]
    }
    readonly property var shots: ({
        "over": { yaw: 0,  pitch: 12 },
        "side": { yaw: 90, pitch: 6 }
    })
    readonly property string defaultShot: "over"
    readonly property real nearest: 4
    readonly property real plotWindow: 10

    readonly property bool ready: _a.head !== null && _b.head !== null && scene._staged

    // --- the staging ----------------------------------------------------------------
    property bool _staged: false
    function stage() {
        const spk = scene.speakerChar
        const lis = scene.listenerChar
        spk.turnTo(lis.scenePosition)
        // The listener's body stays pointed at the lens; only its head turns.
        if (scene.view && scene.view.camera)
            lis.turnTo(Qt.vector3d(scene.view.camera.scenePosition.x, 0,
                                   scene.view.camera.scenePosition.z))
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
    onSpeakerChanged: scene.stage()
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
    function stopAll() { _a.stopSpeaking(); _b.stopSpeaking() }

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
                    { value: "off", key: "listening.off" }] }
    ]
    function choiceState() { return { speaker: speaker, listening: listening } }
    function loadChoices(s) {
        if (!s) return
        if (s.speaker !== undefined) speaker = s.speaker
        if (s.listening !== undefined) listening = s.listening === true || s.listening === "on"
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
        basePos: scene.speakerIndex === 0 ? scene.nearPos : scene.farPos
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
        basePos: scene.speakerIndex === 0 ? scene.farPos : scene.nearPos
        detail: Character.Detail.High
        blinkSeed: 11
        listeningTo: (scene.listening && scene.speakerIndex === 0) ? _a : null
        skinColor: scene.silhouette ? LabTheme.ink : "#c98a63"
        hairColor: scene.silhouette ? LabTheme.ink : "#734120"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"
        torsoColor: scene.silhouette ? LabTheme.ink : "red"
        hipColor: scene.silhouette ? LabTheme.ink : "darkblue"
        armColor: scene.silhouette ? LabTheme.ink : "#4169e1"
        legColor: scene.silhouette ? LabTheme.ink : "#708090"
        handColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        footColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
    }
}
