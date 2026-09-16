// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The *mark ...* cue, end to end through the sequencer.
//
// The parser suite next door pins the grammar; what cannot be checked without
// a running Performance is the LIFETIME, and that is the whole of the feature:
// a mark is raised by its cue, lives for the line that follows it, and is gone
// by the time the next cue starts. Getting that wrong leaves a ring on a part
// the lesson has moved past - which reads as a bug in the lesson, not in the
// sequencer, and is why it is stated here rather than left to a screenshot.
//
// `import "../.."` picks up the plugin's QML directly: no built module, no
// window, no GPU. The performer is a stub, as everywhere else in this suite.

import QtQuick
import QtTest
import "../.."

Item {
    id: root
    width: 50; height: 50

    // Speaks by being told to, and stops when the sequencer's time hint runs
    // out. Nothing here has to do anything with a mark - a mark is not an act
    // of the performer's.
    component Stub: QtObject {
        property bool talking: false
        property var lines: []
        function tell(text, clip) { lines = lines.concat([text]); talking = true }
        function quiet() { talking = false }
        function stopGesture() {}
        function pointAt(p) {}
    }

    Stub { id: stub }

    Performance {
        id: perf
        performer: stub
        spoken: false
        // The same seam a lab uses: names are the scene's business, not the
        // sequencer's. "nowhere" is deliberately unplaceable.
        resolveTarget: (name) => name === "alpha" ? Qt.vector3d(1, 0, 0)
                              : name === "beta"  ? Qt.vector3d(2, 0, 0)
                              : name === "gamma" ? Qt.vector3d(3, 0, 0)
                              : null
    }

    TestCase {
        name: "PerformanceMarks"
        when: windowShown

        function init() {
            perf.stop()
            stub.lines = []
        }

        function test_nothing_is_marked_before_a_script() {
            compare(perf.marks.length, 0)
            compare(perf.markNames.length, 0)
        }

        function test_a_cue_raises_its_targets_resolved() {
            verify(perf.play("*mark alpha, beta* One. (2s) *rest* Two. (60ms)"))
            tryCompare(perf, "currentCue", "say 'One.' (2000ms)")
            compare(perf.markNames.join(","), "alpha,beta")
            compare(perf.marks.length, 2)
            compare(perf.marks[0].x, 1)
            compare(perf.marks[1].x, 2)
        }

        // The lifetime rule, stated: up for that line, down for the next cue.
        function test_marks_last_exactly_one_line() {
            verify(perf.play("*mark alpha* One. (600ms) *mark beta* Two. (600ms)"))
            tryCompare(perf, "currentCue", "say 'One.' (600ms)")
            compare(perf.markNames.join(","), "alpha")
            tryCompare(perf, "currentCue", "say 'Two.' (600ms)", 4000)
            compare(perf.markNames.join(","), "beta",
                    "the second cue replaced the first line's mark")
            tryCompare(perf, "done", true, 4000)
            compare(perf.marks.length, 0, "and the last line's mark went with it")
        }

        function test_a_script_that_ends_marked_still_clears() {
            verify(perf.play("*mark alpha*"))
            tryCompare(perf, "done", true, 4000)
            compare(perf.marks.length, 0)
        }

        function test_stop_clears_the_marks() {
            verify(perf.play("*mark alpha, beta* One. (4s)"))
            tryCompare(perf, "currentCue", "say 'One.' (4000ms)")
            compare(perf.marks.length, 2)
            perf.stop()
            compare(perf.marks.length, 0)
            compare(perf.markNames.length, 0)
        }

        // A name the scene cannot place must not take the rest of the list
        // with it, and must not be drawn at the origin.
        function test_an_unresolved_name_is_skipped_not_fatal() {
            verify(perf.play("*mark alpha, nowhere, gamma* One. (2s)"))
            tryCompare(perf, "currentCue", "say 'One.' (2000ms)")
            compare(perf.markNames.join(","), "alpha,gamma")
            compare(perf.marks.length, 2)
            compare(perf.skipped.length, 1)
            compare(perf.skipped[0].cue, "mark nowhere")
        }

        function test_a_mark_of_nothing_placeable_marks_nothing() {
            verify(perf.play("*mark nowhere* One. (600ms)"))
            tryCompare(perf, "done", true, 4000)
            compare(perf.marks.length, 0)
            compare(perf.skipped.length, 1)
        }

        // The cue reaches a listener the same way every other one does, which
        // is what lets a guide react to it without polling.
        function test_the_cue_is_reported_like_any_other() {
            let seen = ""
            const c = (type, arg) => { if (type === "mark") seen = arg }
            perf.cueFired.connect(c)
            verify(perf.play("*mark alpha, beta* One. (600ms)"))
            tryCompare(perf, "done", true, 4000)
            perf.cueFired.disconnect(c)
            compare(seen, "alpha, beta")
        }

        // Marks are not an act of the performer's: a stub with no mark method
        // of any kind is not recorded as unable to do one.
        function test_the_performer_is_never_asked_to_mark() {
            verify(perf.play("*mark alpha* One. (600ms)"))
            tryCompare(perf, "done", true, 4000)
            compare(perf.skipped.length, 0)
            compare(stub.lines.join("|"), "One.")
        }
    }
}
