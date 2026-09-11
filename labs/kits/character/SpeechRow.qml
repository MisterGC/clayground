// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SpeechRow - the same line read by all three lip-sync tiers, side by side.
// Three heads, one recording, one transport: loudness, then formants, then a
// script aligned to the recording - so the thing being judged is judged by
// looking at three mouths at once rather than by remembering what the last
// one did.
//
// What it is for:
//
//   * The envelope tier cannot tell "oo" from "ee": both are a slot at
//     whatever size the loudness asks for. Whether the spectral tier's answer
//     is actually the right SHAPE is not something its unit tests can say -
//     they only prove it is a consistent one.
//   * Every recording is a different room, microphone and voice. The two
//     committed wavs are one speaking voice and one singing one, and the
//     singing one is the awkward case on purpose.
//   * Aligned needs a transcript, and neither committed wav has one - what
//     they were recorded saying was never written down. So the right-hand
//     head falls back, and report() says so: `got` is the tier the line
//     actually ran at, which is not always the tier that was asked for.
//   * The `say` verb hands all three the same text through the system voice
//     instead. Measured here, that does not buy the aligned tier its words:
//     all three fall back to envelope on a spoken line, which is the readout
//     doing its job rather than a failure to hide.
//
// COLD-OPEN SILENT. The bench started the recording on load so a one-shot
// render landed mid-line; a lab may not. The determinism gate steps the clock
// with nothing playing, and a scene that starts a sound on load would make
// every record depend on how fast the machine got to the first frame. Say
// `play` to start it.
//
// ABOUT THE PROBES. mouthOpen comes off the engine, which clocks off its own
// audio player on the WALL clock - so these three curves are the plugin's
// playback, not the lab's. A stepped record of this scene is honest zeros
// unless a `play` ran first, and the numbers it then records are a sampling
// of real time that a second run will not reproduce. Watch the plot live;
// quote report(), not a record.
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
    readonly property string aspect: "speech"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings): verbs, chips on the card, carried in state() -------
    /*! Which committed recording the next `play` reads: "hello" or "sing". */
    property string recording: "hello"
    /*! What the last `say` asked for, or "" - carried so a reload says it again. */
    property string lastText: ""

    readonly property var tiers: ["envelope", "spectral", "aligned"]
    readonly property var recordings: ["hello", "sing"]

    // --- layout --------------------------------------------------------------
    readonly property real spread: 2.1
    readonly property real standY: 0
    readonly property real headHeight: 1.7
    readonly property real headHalf: 1.2

    function bounds() {
        const x = scene.spread + scene.headHalf
        return [Qt.vector3d(-x, scene.standY, -scene.headHalf),
                Qt.vector3d(x, scene.standY + scene.headHeight, scene.headHalf)]
    }
    readonly property var shots: ({
        "face":    { yaw: 0,  pitch: 5 },
        "quarter": { yaw: 22, pitch: 5 },
        "profile": { yaw: 90, pitch: 5 }
    })
    readonly property string defaultShot: "face"
    readonly property real nearest: 1.5
    readonly property real plotWindow: 6

    readonly property bool ready: true

    // --- the three engines ------------------------------------------------------
    // Three analyses, not one: the tier is a property of the ANALYSIS, so
    // comparing tiers means three analyses of the same file. They are started
    // in one call and each clocks off its own player's position, which is what
    // keeps the three mouths on the same syllable. Only the first is audible;
    // three copies of one voice is a chorus, not a comparison.
    Speech { id: _env; accuracy: Speech.Envelope; volume: 1.0 }
    Speech { id: _spc; accuracy: Speech.Spectral; volume: 0.0 }
    Speech { id: _alg; accuracy: Speech.Aligned;  volume: 0.0 }

    readonly property var engines: [_env, _spc, _alg]
    function engineOf(tier) {
        const i = scene.tiers.indexOf(tier)
        return i < 0 ? null : scene.engines[i]
    }

    readonly property bool playing: _env.speaking || _spc.speaking || _alg.speaking

    function _urlOf(name) {
        return Qt.resolvedUrl((scene.recordings.indexOf(name) >= 0 ? name : "hello") + ".wav")
    }

    function playRecording(name) {
        if (scene.recordings.indexOf(name) >= 0) scene.recording = name
        const url = scene._urlOf(scene.recording)
        // No transcript exists for either file, which is the point: aligned
        // falls back and the readout says which tier the line really got.
        _env.sayAudio(url)
        _spc.sayAudio(url)
        _alg.sayAudio(url, "")
    }
    function sayLine(text) {
        scene.lastText = (text === undefined || text === null) ? "" : "" + text
        if (scene.lastText === "") return
        _env.sayText(scene.lastText)
        _spc.sayText(scene.lastText)
        _alg.sayText(scene.lastText)
    }
    function stopAll() { _env.stop(); _spc.stop(); _alg.stop() }

    // --- the readings ----------------------------------------------------------------
    Probe { name: "speech.openEnvelope"; expr: () => _env.mouthOpen }
    Probe { name: "speech.openSpectral"; expr: () => _spc.mouthOpen }
    Probe { name: "speech.openAligned"; expr: () => _alg.mouthOpen }

    function _accuracyName(a) {
        return a === Speech.Envelope ? "envelope"
             : a === Speech.Spectral ? "spectral" : "aligned"
    }

    // --- verbs, state, readout ----------------------------------------------------------
    function verbs() {
        return {
            // "stop" and false both stop, so the transport chips below and an
            // agent's stop verb are the same one call.
            "play":      (n) => {
                if (n === false || n === "stop") { scene.stopAll(); return }
                scene.playRecording(n === undefined || n === null || n === "play"
                                    ? scene.recording : n)
            },
            "stop":      () => scene.stopAll(),
            "recording": (n) => { if (scene.recordings.indexOf(n) >= 0) scene.recording = n },
            "say":       (t) => scene.sayLine(t)
        }
    }
    readonly property var choices: [
        { verb: "recording", key: "choice.recording", current: scene.recording,
          options: scene.recordings.map(v => ({ value: v, key: "recording." + v })) },
        { verb: "play", key: "choice.transport", current: scene.playing ? "play" : "stop",
          options: [{ value: "play", key: "transport.play" },
                    { value: "stop", key: "transport.stop" }] }
    ]
    function choiceState() { return { recording: recording, lastText: lastText } }
    function loadChoices(s) {
        if (!s) return
        if (s.recording !== undefined) recording = s.recording
        if (s.lastText !== undefined) lastText = s.lastText
    }

    function report() {
        const out = {}
        for (let i = 0; i < scene.tiers.length; ++i) {
            const e = scene.engines[i]
            out[scene.tiers[i]] = {
                open: e.mouthOpen, wide: e.mouthWide, round: e.mouthRound,
                got: scene._accuracyName(e.effectiveAccuracy),
                speaking: e.speaking, durationMs: e.durationMs
            }
        }
        return { recording: scene.recording, playing: scene.playing,
                 said: scene.lastText, tiers: out, ready: scene.ready }
    }
    function readout() {
        const rows = []
        for (let i = 0; i < scene.tiers.length; ++i)
            rows.push({ key: "read.open." + scene.tiers[i],
                        value: LabLang.num(scene.engines[i].mouthOpen, 2) })
        for (let i = 0; i < scene.tiers.length; ++i)
            rows.push({ key: "read.got." + scene.tiers[i],
                        value: LabLang.t("tier." + scene._accuracyName(
                                             scene.engines[i].effectiveAccuracy)) })
        return rows
    }

    readonly property var labels: {
        LabLang.lang
        const out = []
        for (let i = 0; i < scene.tiers.length; ++i)
            out.push({ at: Qt.vector3d((i - 1) * scene.spread,
                                       scene.standY + scene.headHeight, 0),
                       text: LabLang.t("tier." + scene.tiers[i]), above: true })
        return out
    }

    // --- the heads ----------------------------------------------------------------------
    // basePos, never x. A Head is a BodyPart and BodyPart binds position to
    // basePos - an x set here is overwritten the moment that binding evaluates
    // and all three sit on top of each other.
    component Bust: Head {
        detail: Head.Detail.High
        autoBlink: true
        skinColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        hairColor: scene.silhouette ? LabTheme.ink : "#734120"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"
    }

    Bust { basePos: Qt.vector3d(-scene.spread, scene.standY, 0); speechSource: _env }
    Bust { basePos: Qt.vector3d(0, scene.standY, 0); speechSource: _spc }
    Bust { basePos: Qt.vector3d(scene.spread, scene.standY, 0); speechSource: _alg }
}
