// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Lab.snapshot() and Lab.restore() (#568): a restored run goes on exactly as
// the uninterrupted one - same samples, same random numbers, same model
// state - and it does so after a JSON round trip and from a file. A lab whose
// model offers no state says so, and its replay applies a parameter change at
// the time it was made.

import QtCore
import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 50; height: 50

    SimClock { id: clock; seed: 11; timeScale: 0; sampleInterval: 0.1; fixedStep: 1 / 60 }

    Parameter { id: pGain; name: "tstSnapGain"; value: 2; from: 0; to: 10 }

    // the model: a sum that random steps build up, and a short history -
    // nothing a clock reset or a replay of time alone could bring back
    QtObject {
        id: model
        property real sum: 0
        property var hist: []
        property real odd: 0
    }
    Connections {
        target: clock
        function onStepped(dt) {
            model.sum += pGain.value * (clock.random() - 0.5)
            model.hist.push(model.sum)
            if (model.hist.length > 5) model.hist.shift()
            model.hist = model.hist
        }
        function onWasReset() { model.sum = 0; model.hist = []; model.odd = 0 }
    }

    Probe { name: "tstSnapSum"; expr: () => model.sum }
    Probe { name: "tstSnapGainP"; expr: () => pGain.value }

    Component {
        id: hookComp
        ModelState { name: "tstSnapModel"; target: model; properties: ["sum", "hist", "odd"] }
    }
    Component {
        id: extraComp
        ModelState { name: "tstSnapExtra"; save: () => ({}); load: (s) => {} }
    }

    DataRecorder { id: rec; lab: "tst-lab"; probes: ["tstSnapSum"]; command: "ctest -R qml_lab_qml" }

    readonly property string dir: {
        const u = String(StandardPaths.writableLocation(StandardPaths.TempLocation))
        return decodeURIComponent(u.replace(/^file:\/\//, ""))
    }

    TestCase {
        name: "LabSnapshot"

        property var wasClock: null
        property var hook: null

        function init() {
            wasClock = Lab.clock
            Lab.clock = clock
            Lab.resetParameters()
            clock.reset()
        }
        function cleanup() {
            if (rec.recording) { rec.destination = root.dir + "/tst_snapshot_cleanup.labrec"; rec.recording = false }
            if (hook) { hook.destroy(); hook = null }
            Lab.clock = wasClock
        }
        function withHook() {
            hook = hookComp.createObject(root)
            verify(Lab.modelStateNames.indexOf("tstSnapModel") !== -1)
        }

        function steps(n) { for (let i = 0; i < n; ++i) clock._advance(1 / 60) }
        function series(name) { return JSON.stringify(Lab.probe(name).samples) }
        function fingerprint() {
            return JSON.stringify({ sum: model.sum, hist: model.hist, t: clock.time,
                                    sumS: Lab.probe("tstSnapSum").samples,
                                    gainS: Lab.probe("tstSnapGainP").samples,
                                    next: clock.random() })
        }

        function test_noModelStateSaysSo() {
            compare(Lab.modelStateNames.length, 0)
            const s = Lab.snapshot()
            verify(s.error !== undefined, "a lab without ModelState gets no snapshot")
            verify(s.error.indexOf("offers no state") !== -1, s.error)
            compare(Lab.schema().modelStates.length, 0)
            compare(Lab.viewState().snapshot, undefined)
        }

        function test_restoreContinuesExactly() {
            withHook()
            compare(Lab.schema().modelStates, ["tstSnapModel"])
            steps(90)
            const snap = Lab.snapshot()
            verify(snap.error === undefined, snap.error)
            compare(snap.clock.time, clock.time)
            steps(60)
            const straight = fingerprint()

            // wander off: another gain, another seed, more time
            Lab.set("tstSnapGain", 7)
            clock.seed = 99
            steps(200)
            verify(fingerprint() !== straight)

            const r = Lab.restore(snap)
            verify(r.restored, JSON.stringify(r))
            compare(pGain.value, 2)
            compare(clock.seed, 11)
            steps(60)
            compare(fingerprint(), straight)
        }

        function test_restoreTwiceFromOneSnapshot() {
            withHook()
            steps(30)
            const snap = Lab.snapshot()
            steps(30)
            const straight = fingerprint()
            Lab.restore(snap); steps(30)
            compare(fingerprint(), straight)
            Lab.restore(snap); steps(30)
            compare(fingerprint(), straight, "restoring must not hand the snapshot's own objects to the model")
        }

        function test_jsonRoundTrip() {
            withHook()
            steps(45)
            const snap = JSON.parse(JSON.stringify(Lab.snapshot()))
            steps(45)
            const straight = fingerprint()
            steps(10)
            verify(Lab.restore(snap).restored)
            steps(45)
            compare(fingerprint(), straight)
        }

        function test_nonFiniteNumbersSurvive() {
            withHook()
            model.odd = NaN
            const snap = JSON.parse(JSON.stringify(Lab.snapshot()))
            model.odd = 3
            Lab.restore(snap)
            verify(isNaN(model.odd), "NaN came back as " + model.odd)
            compare(Lab._unpack(Lab._pack([Infinity, -Infinity, -0, 1.5])).map(String),
                    ["Infinity", "-Infinity", "0", "1.5"])
            verify(1 / Lab._unpack(JSON.parse(JSON.stringify(Lab._pack(-0)))) < 0, "-0 kept its sign")
        }

        function test_fileRoundTrip() {
            withHook()
            steps(60)
            const path = root.dir + "/tst_snapshot.snap.json"
            const w = Lab.writeSnapshot(path)
            verify(w.written === path, JSON.stringify(w))
            steps(60)
            const straight = fingerprint()
            steps(5)
            const r = Lab.restore(path)        // a path reads the file
            verify(r.restored, JSON.stringify(r))
            steps(60)
            compare(fingerprint(), straight)

            const missing = Lab.readSnapshot(root.dir + "/tst_snapshot_none.json")
            verify(missing.error !== undefined && missing.error.indexOf("cannot read") !== -1,
                   JSON.stringify(missing))
        }

        function test_mismatchedModelStateIsRefused() {
            withHook()
            steps(20)
            const snap = Lab.snapshot()
            const extra = extraComp.createObject(root)
            steps(20)
            const before = JSON.stringify({ sum: model.sum, t: clock.time, rng: clock._rngState,
                                            n: Lab.probe("tstSnapSum").samples.length })
            const r = Lab.restore(snap)
            verify(r.error !== undefined && r.error.indexOf("tstSnapExtra") !== -1, JSON.stringify(r))
            compare(JSON.stringify({ sum: model.sum, t: clock.time, rng: clock._rngState,
                                     n: Lab.probe("tstSnapSum").samples.length }), before,
                    "a refused restore changes nothing")
            extra.destroy()
            verify(Lab.restore({ format: "other" }).error.indexOf("format") !== -1)
            verify(Lab.restore("not a file.json").error !== undefined)
        }

        function test_recordingIsCarried() {
            withHook()
            const straightPath = root.dir + "/tst_snapshot_straight.labrec"
            const resumedPath = root.dir + "/tst_snapshot_resumed.labrec"

            rec.recordId = "snap"; rec.steps = 120
            rec.destination = straightPath
            rec.recording = true
            steps(60)
            const snap = JSON.parse(JSON.stringify(Lab.snapshot()))
            steps(60)
            const straight = JSON.stringify(rec.record())
            rec.recording = false

            Lab.restore(snap)
            verify(rec.recording, "the recording came back with the snapshot")
            compare(rec.destination, straightPath)
            rec.destination = resumedPath
            steps(60)
            compare(JSON.stringify(rec.record()), straight)
            rec.recording = false
        }

        function test_recordingStartedAfterTheSnapshotStartsAgain() {
            withHook()
            steps(30)
            const snap = Lab.snapshot()
            rec.destination = root.dir + "/tst_snapshot_late.labrec"
            rec.recording = true
            steps(30)
            verify(rec.rows > 0)
            const r = Lab.restore(snap)
            verify(rec.recording)
            compare(rec.rows, 0)
            verify(r.notes && r.notes.join(" ").indexOf("starts its record again") !== -1,
                   JSON.stringify(r))
            rec.recording = false
        }

        function test_viewStateCarriesTheSnapshot() {
            withHook()
            steps(50)
            const vs = JSON.parse(JSON.stringify(Lab.viewState()))
            verify(vs.snapshot !== undefined)
            steps(50)
            const straight = fingerprint()

            // what a reload does: the scenario resets the clock, then the view state
            clock.reset()
            Lab.set("tstSnapGain", 9)
            Lab.applyViewState(vs)
            compare(clock.time, vs.time)
            steps(50)
            compare(fingerprint(), straight)
        }

        function test_snapshotThatDoesNotRestoreIsReplayed() {
            withHook()
            steps(40)
            const vs = JSON.parse(JSON.stringify(Lab.viewState()))
            vs.snapshot.model = { renamed: {} }
            clock.reset()
            ignoreWarning(/the view state's snapshot was not restored/)
            Lab.applyViewState(vs)
            verify(Math.abs(clock.time - vs.time) < 1e-9, "replayed to " + clock.time)
        }

        // The replay of a lab without model state (#568): before, it set the
        // parameters' last values and re-stepped from 0, so a gain changed
        // half-way ran at the new gain from the start.
        function test_replayAppliesChangesAtTheirTime() {
            steps(60)
            Lab.set("tstSnapGain", 5)
            steps(60)
            Lab.set("tstSnapGain", 1)
            steps(30)
            const live = series("tstSnapSum")
            const liveGain = series("tstSnapGainP")
            const vs = JSON.parse(JSON.stringify(Lab.viewState()))
            compare(vs.paramLog.changes.length, 2)
            compare(vs.paramLog.start.tstSnapGain, 2)

            clock.reset()
            Lab.resetParameters()
            Lab.applyViewState(vs)
            compare(series("tstSnapSum"), live)
            compare(series("tstSnapGainP"), liveGain)
            compare(pGain.value, 1)

            // and the old replay would not have: the last gain from the start
            clock.reset()
            Lab.applyViewState({ time: vs.time, params: vs.params })
            verify(series("tstSnapSum") !== live)
        }

        function test_changesAtOneTimeCollapse() {
            steps(10)
            for (let v = 3; v <= 6; ++v) Lab.set("tstSnapGain", v)
            const log = Lab.viewState().paramLog.changes
            compare(log.length, 1)
            compare(log[0][2], 6)
            clock.reset()
            compare(Lab.viewState().paramLog.changes.length, 0)
            compare(Lab.viewState().paramLog.start.tstSnapGain, 6)
        }
    }
}
