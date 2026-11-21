// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The recorder writes the same file for the same run (#532): that is what
// lets a paper's record be checked with a diff. record.test.js pins the
// serialization; this pins the whole route - clock, probes, parameters and
// the file on disk.
//
// The file is read back through XMLHttpRequest, which needs
// QML_XHR_ALLOW_FILE_READ=1 (set for this suite in the plugin's CMakeLists).

import QtCore
import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 50; height: 50

    SimClock { id: clock; seed: 42; timeScale: 0; sampleInterval: 0.1; fixedStep: 0.05 }

    Parameter { id: gain; name: "tstRecGain"; value: 2; from: 0; to: 5; unit: "V" }

    // a model with seeded noise, advanced in fixed steps like a real lab
    property real signal: 0
    Connections {
        target: clock
        function onStepped(dt) { root.signal = gain.value * clock.time + clock.randomGaussian() }
        function onWasReset() { root.signal = 0 }
    }

    Probe { name: "tstRecSignal"; unit: "V"; expr: () => root.signal }
    // only every other tick - its gaps must come out as blanks, both times
    Probe { name: "tstRecHalf"; expr: () => (Math.round(clock.time * 10) % 2) ? NaN : root.signal }

    DataRecorder {
        id: rec
        lab: "tst-lab"
        probes: ["tstRecSignal", "tstRecHalf"]
        command: "ctest -R qml_lab_qml"
        steps: 40
    }

    readonly property string dir: {
        const u = String(StandardPaths.writableLocation(StandardPaths.TempLocation))
        return decodeURIComponent(u.replace(/^file:\/\//, ""))
    }

    function run(seed, path) {
        clock.seed = seed
        clock.reset()
        rec.destination = path
        rec.recording = true
        for (let i = 0; i < 40; ++i) clock._advance(0.05)
        rec.recording = false
        return rec.lastFile
    }

    function readFile(path) {
        const xhr = new XMLHttpRequest()
        xhr.open("GET", "file://" + path, false)
        xhr.send()
        return xhr.responseText
    }

    TestCase {
        name: "DataRecorder"

        function test_sameRunSameFile() {
            const a = root.run(42, root.dir + "/clay-tst-recorder-a.labrec")
            const textA = root.readFile(a)
            const b = root.run(42, root.dir + "/clay-tst-recorder-b.labrec")
            const textB = root.readFile(b)
            verify(textA.length > 0, "the first run was written to " + a)
            verify(textA.indexOf("tstRecGain") !== -1, "the record carries the parameter")
            verify(textA.indexOf("tstRecSignal") !== -1, "and the probe")
            compare(rec.rows, 21, "one row per sample tick, t = 0 .. 2")
            // the ids differ by file name; everything else must not
            compare(textB.replace(/clay-tst-recorder-b/g, "clay-tst-recorder-a"), textA)
        }

        function test_otherSeedOtherFile() {
            const a = root.readFile(root.run(42, root.dir + "/clay-tst-recorder-a.labrec"))
            const c = root.readFile(root.run(43, root.dir + "/clay-tst-recorder-a.labrec"))
            verify(a !== c, "the noise came from the seed, so the record shows it")
        }

        function test_recordMatchesTheFile() {
            const a = root.readFile(root.run(42, root.dir + "/clay-tst-recorder-a.labrec"))
            const r = rec.record()
            compare(r.seed, 42)
            compare(r.lab, "tst-lab")
            verify(a.indexOf('"seed": 42') !== -1 || a.indexOf('"seed":42') !== -1)
        }
    }
}
