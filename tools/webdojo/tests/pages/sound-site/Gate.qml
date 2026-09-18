// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Site-route sound gate for MisterGC/clayground#263. wasm_smoke_test.py
// --site-example copies this file next to the published sound example and
// loads it the way the dojo page loads a gallery entry: the runtime boots in
// demo/webdojo/, the QML comes from webdojo-examples/sound/ by absolute URL.
//
// It plays that example's own files, by the relative URLs the example uses -
// so every fetch crosses from the page's directory into the example's, which
// is what the starter layout (your Main.qml next to index.html) never does.
//
// Two things are checked, and neither is visible in QML state:
//
//   * music.mp3 really plays - Music goes through a media element on the web,
//     so the audio probe cannot hear it; a position that advances is the
//     evidence, and a page that froze never reports one (#216, #261);
//   * the notes phase really reaches the shared sink - Sound and
//     SynthInstrument go through it, and a sink that was opened on a device
//     that cannot play swallows every sample silently (#262). Music is
//     stopped first, so nothing but the sink can make the phase audible.

import QtQuick
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    // 12 x 250 ms - long enough for the probe's ~370 ms window to land on
    // sound several times, short enough to keep the CI step under a minute.
    readonly property int noteIntervalMs: 250
    readonly property int noteTicks: 12
    // A position this far in is playback, not a media element reporting the
    // start of a track it never decoded.
    readonly property int musicProgressMs: 800
    // How long a step waits for something it cannot do anything about (the
    // sample arriving, the track starting) before it says so and stops. The
    // marker never comes then, so the run fails - with a line naming what was
    // waited for instead of a silent timeout.
    readonly property int assetWaitMs: 20000
    readonly property int musicWaitMs: 45000

    property string phase: "loading"
    property int notes: 0

    Music {
        id: music
        source: "music.mp3"
        volume: 0.4
        onStatusChanged: if (music.status === 3)
            console.log("clay-sound: site music failed to load")
    }

    Sound {
        id: effect
        source: "sound.wav"
        onErrorOccurred: (msg) => console.log("clay-sound: site effect error: " + msg)
    }

    SynthInstrument {
        id: synth
        waveform: "square"
        attack: 0.005; decay: 0.05; sustain: 0.6; release: 0.1
    }

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.phase + " - " + music.position + "/" + music.duration
              + " ms, " + root.notes + " notes"
    }

    function setPhase(name) {
        phase = name;
        console.log("PHASE:" + name);
    }

    // --- the sequence ---------------------------------------------------
    // One timer, one step per firing, so every phase boundary is a marker the
    // harness can attribute its audio samples to.
    property int step: 0

    Timer {
        id: seq
        repeat: false
        onTriggered: root.advance()
    }

    function next(ms) {
        seq.interval = ms;
        seq.start();
    }

    // Waits inside a step: come back in 200 ms until the limit is up, then
    // report what was missing and leave the sequence standing.
    property int waited: 0

    function retry(limit, what) {
        waited += 200;
        if (waited <= limit) { step--; next(200); return; }
        console.log("clay-sound: site gate gave up waiting for " + what
                    + " - status=" + music.status + " playing=" + music.playing
                    + " position=" + music.position
                    + " effectLoaded=" + effect.loaded);
    }

    function advance() {
        step++;
        switch (step) {
        case 1:
            // Both files arrive over http from the example's directory.
            if (!effect.loaded) { retry(root.assetWaitMs, "sound.wav"); return; }
            waited = 0;
            setPhase("music");
            music.play();
            next(200);
            break;
        case 2:
            if (music.position < root.musicProgressMs) {
                retry(root.musicWaitMs, "music.mp3 to advance");
                return;
            }
            waited = 0;
            console.log("clay-sound: site music advanced position=" + music.position
                        + " duration=" + music.duration);
            music.stop();
            setPhase("notes");
            notesTimer.start();      // calls advance() when it runs out
            break;
        case 3:
            console.log("clay-sound: site notes triggered=" + notes
                        + " effectVoices=" + effect.activeVoices
                        + " synthVoices=" + synth.activeVoices);
            console.log("clay-sound: site gate finished");
            break;
        }
    }

    Timer {
        id: notesTimer
        interval: root.noteIntervalMs
        repeat: true
        property int ticks: 0
        onTriggered: {
            effect.play();
            synth.triggerNote(72, 0.9, 0.2);
            root.notes += 2;
            if (++ticks >= root.noteTicks) { stop(); root.advance(); }
        }
    }

    // Heartbeat: tells a frozen page apart from one that is merely waiting for
    // the track, and carries the numbers a failing run is diagnosed from.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: console.log("clay-sound: site alive phase=" + root.phase
                                 + " status=" + music.status
                                 + " playing=" + music.playing
                                 + " position=" + music.position)
    }

    // 3 s, not 300 ms: the browser's device enumeration is asynchronous and
    // the first sound has to land after it, the way a user's does.
    Component.onCompleted: next(3000)
}
