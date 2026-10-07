// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Regression page for MisterGC/clayground#262 - overlaid onto the starter
// bundle by wasm_smoke_test.py. In the deployed sound demo the effects went
// silent for the rest of the session, and nothing about that is visible in
// QML state: the engine keeps scheduling, the voices keep draining, only
// the audio graph has stopped carrying samples. So the page walks the same
// sequence a hammering user walks and prints a PHASE marker per step;
// wasm_smoke_test.py --audio-probe taps the page's AudioContext and
// compares how loud the page is before and after the hammering.
//
// Two details of the demo are load-bearing here, not decoration:
//   * a Music object, whose construction makes Qt enumerate the browser's
//     audio devices - which decides which device the shared sink opens on,
//     and only one of them can be opened at all;
//   * a first press that comes seconds after the load, i.e. after that
//     enumeration has landed.

import QtQuick
import Clayground.Sound

Rectangle {
    id: root
    anchors.fill: parent
    color: "#101018"

    // 500 ticks x 3 presses of each button in ~8 s - more than a human
    // manages, and enough to reach the state the report describes.
    readonly property int hammerIntervalMs: 16
    readonly property int hammerTicks: 500
    readonly property int pressesPerTick: 3

    property string phase: "loading"
    property int triggered: 0

    // Never played - it is here for its constructor, which is what the demo
    // does too (a background-music track next to the effects).
    Music { id: music }

    Sound {
        id: effect
        source: "effect.wav"
        onErrorOccurred: (msg) => console.log("clay-sound: effect error: " + msg)
    }

    SynthInstrument {
        id: procedural
        waveform: "square"
        attack: 0.005; decay: 0.05; sustain: 0.6; release: 0.1
    }

    Text {
        anchors.centerIn: parent
        color: "#00d9ff"
        font.pixelSize: 24
        text: root.phase + " - " + root.triggered + " presses"
    }

    function setPhase(name) {
        phase = name;
        console.log("PHASE:" + name);
    }

    function report(tag) {
        console.log("clay-sound: " + tag
                    + " presses=" + triggered
                    + " effectVoices=" + effect.activeVoices
                    + " proceduralVoices=" + procedural.activeVoices);
    }

    function press() {
        effect.play();
        procedural.triggerNote(72, 0.9, 0.15);
        triggered += 2;
    }

    // --- the sequence ---------------------------------------------------
    // One timer, one step per firing, so every phase boundary is a marker
    // the harness can attribute its audio samples to.
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

    function advance() {
        step++;
        switch (step) {
        case 1:
            // effect.wav arrives over http on the web - wait for it.
            if (!effect.loaded) { step--; next(100); return; }
            setPhase("baseline");
            press();
            next(1500);
            break;
        case 2:
            report("baseline done");
            setPhase("hammer");
            hammer.start();          // calls advance() when it runs out
            break;
        case 3:
            report("hammer done");
            setPhase("cooldown");
            next(2500);              // long enough for every voice to drain
            break;
        case 4:
            report("cooldown done");
            setPhase("after-hammer");
            probe.start();           // calls advance() when it runs out
            break;
        case 5:
            report("after-hammer done");
            console.log("clay-sound: hammer probe finished");
            break;
        }
    }

    Timer {
        id: hammer
        interval: root.hammerIntervalMs
        repeat: true
        property int ticks: 0
        onTriggered: {
            for (let i = 0; i < root.pressesPerTick; ++i) root.press();
            if (++ticks >= root.hammerTicks) { stop(); root.advance(); }
        }
    }

    Timer {
        id: probe
        interval: 400
        repeat: true
        property int ticks: 0
        onTriggered: {
            root.press();
            if (++ticks >= 8) { stop(); root.advance(); }
        }
    }

    // Heartbeat: a frozen voice count in the log means the engine stopped
    // being pulled, a draining one means the engine is fine and the
    // silence (if any) is downstream of it.
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.report("tick")
    }

    // 3 s, not 300 ms: the browser's device enumeration is asynchronous and
    // the first press has to land after it, the way a user's does.
    Component.onCompleted: next(3000)
}
