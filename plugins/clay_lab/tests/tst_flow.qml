// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Flow's checkpoints, and the part of them that is easy to get wrong: a step
// is entered from a stored state, and the LET-BINDINGS a step was written
// against are part of that state.
//
// A flow names things as it builds them ("let bat, addPart battery") and later
// steps refer to those names. The name table used to be flow-wide while the
// checkpoints held only the lab's viewState, so scrubbing back and forward
// re-entered a step with whatever names happened to be current - which is not
// what the step was recorded with. Nothing throws when that goes wrong: a lab
// verb handed an unresolved name simply operates on the literal string and
// does nothing, so the demo runs and teaches nothing.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // A lab just real enough to be driven: it hands out ids, it can be asked
    // what it looks like, and it can be put back.
    Item {
        id: fakeLab

        property var parts: []
        property int nextId: 1
        property int tagged: -1        // what the last tag verb actually hit

        function addPart(kind) {
            const id = nextId++
            parts = parts.concat([{ id: id, kind: kind }])
            return id
        }
        function tagPart(id) {
            for (const p of parts) if (p.id === id) { tagged = id; return true }
            tagged = -1                // asked to tag something not on the board
            return false
        }
        function viewState() { return { parts: parts, nextId: nextId } }
        function applyViewState(s) { parts = s.parts; nextId = s.nextId }
        function flowActions() {
            return { "addPart": (k) => fakeLab.addPart(k),
                     "tagPart": (id) => fakeLab.tagPart(id) }
        }
    }

    // A camera just real enough to be aimed: it records what it was asked for
    // and in which order, which is the only thing FlowStep.view promises.
    Item {
        id: fakeCam

        property string lastCall: ""
        property var lastArg: null
        property int calls: 0
        property int partsWhenAimed: -1     // proof the view is applied AFTER the demo

        function goTo(name, ms) {
            lastCall = "goTo"; lastArg = name; calls += 1
            partsWhenAimed = fakeLab.parts.length
            return true
        }
        function focusOn(what, pad, ms) {
            lastCall = "focusOn"; lastArg = what; calls += 1
            partsWhenAimed = fakeLab.parts.length
        }
        function applyState(s) {
            lastCall = "applyState"; lastArg = s; calls += 1
            partsWhenAimed = fakeLab.parts.length
        }
    }

    Flow {
        id: flow
        lab: fakeLab
        flowId: "tst"
        pacing: "manual"

        FlowStep { key: "intro"; say: "look at the empty board" }
        FlowStep { key: "place"; say: "a battery"; demo: [["let", "bat", "addPart", "battery"]] }
        FlowStep { key: "tag"; say: "mark it"; demo: [["tagPart", "bat"]] }
    }

    // The camera-carrying flow. Separate from the one above so the checkpoint
    // cases keep proving that a flow WITHOUT a camera is untouched.
    Flow {
        id: viewFlow
        lab: fakeLab
        flowId: "tstview"
        pacing: "manual"
        camera: fakeCam

        FlowStep { key: "plain"; say: "no view of its own" }
        FlowStep { key: "named"; say: "from above"; view: ({ viewpoint: "top", ms: 0 }) }
        FlowStep {
            key: "framed"
            say: "look at what we built"
            demo: [["addPart", "led"]]
            view: ({ focus: [Qt.vector3d(0, 0, 0), Qt.vector3d(10, 0, 10)], pad: 1.2, ms: 0 })
        }
        FlowStep { key: "posed"; say: "exactly here"; view: ({ pose: { yaw: 30, distance: 90 } }) }
    }

    // The same steps with no camera wired: nothing may throw, nothing may move.
    Flow {
        id: blindFlow
        lab: fakeLab
        flowId: "tstblind"
        pacing: "manual"

        FlowStep { key: "named"; view: ({ viewpoint: "top" }) }
        FlowStep { key: "posed"; view: ({ pose: { yaw: 30 } }) }
    }

    TestCase {
        name: "Flow"

        function init() {
            fakeLab.parts = []
            fakeLab.nextId = 1
            fakeLab.tagged = -1
            flow.stop(); viewFlow.stop(); blindFlow.stop()
            fakeCam.lastCall = ""; fakeCam.lastArg = null
            fakeCam.calls = 0; fakeCam.partsWhenAimed = -1
        }

        // The plain forward run: the name bound in one step resolves in the next.
        function test_letBindingResolvesInLaterStep() {
            flow.start()
            flow.next()
            compare(flow.nameOf("bat"), 1, "the battery's id is bound to 'bat'")
            flow.next()
            compare(fakeLab.tagged, 1, "the tag verb hit the part the flow made")
        }

        // The regression: a checkpoint carries the bindings of the step it was
        // taken at, so re-entering a step never sees a later step's names.
        function test_checkpointCarriesItsNames() {
            flow.start()
            flow.next(); flow.next()
            compare(flow.index, 2)
            compare(flow.nameOf("bat"), 1)

            flow.goTo(0)
            compare(flow.nameOf("bat"), "bat",
                    "step 0 was recorded before anything was named")

            flow.goTo(2)
            compare(flow.nameOf("bat"), 1,
                    "step 2 was recorded with 'bat' bound, and gets it back")
            compare(fakeLab.tagged, 1, "so its demo still hits a real part")
        }

        // Scrubbing back and forth must not leave a name pointing at an object
        // the restore took away.
        function test_replayKeepsTheDemoHonest() {
            flow.start()
            flow.next(); flow.next()
            flow.goTo(1)
            compare(fakeLab.parts.length, 1, "step 1's demo made exactly one part")
            flow.goTo(2)
            compare(fakeLab.tagged, fakeLab.parts[0].id,
                    "the tag lands on the part that is actually there")
        }

        // start() is the one place a flow forgets everything.
        function test_startForgetsNames() {
            flow.start()
            flow.next()
            compare(flow.nameOf("bat"), 1)
            flow.start()
            compare(flow.nameOf("bat"), "bat")
        }

        // --- FlowStep.view ---------------------------------------------------

        // A step with no view of its own leaves the camera exactly where the
        // learner left it. This is the property that makes the feature
        // non-breaking: every existing step is a step without a view.
        function test_a_stepWithoutAViewNeverTouchesTheCamera() {
            viewFlow.start()
            compare(fakeCam.calls, 0, "the first step names no view")
            viewFlow.next()
            compare(fakeCam.calls, 1, "the second one does")
            viewFlow.prev()
            compare(fakeCam.calls, 1, "and stepping back onto the first moves nothing")
        }

        function test_aNamedViewpointIsRequested() {
            viewFlow.start()
            viewFlow.next()
            compare(fakeCam.lastCall, "goTo")
            compare(fakeCam.lastArg, "top")
        }

        // The order that matters: a step that builds something and then frames
        // it has to be framed around what it built, not around what was there
        // when it was entered.
        function test_theViewIsAppliedAfterTheDemo() {
            viewFlow.start()
            viewFlow.next(); viewFlow.next()
            compare(fakeCam.lastCall, "focusOn")
            compare(fakeCam.lastArg.length, 2, "the points it named")
            compare(fakeCam.partsWhenAimed, 1, "the demo's part existed by then")
        }

        function test_aLiteralPoseIsApplied() {
            viewFlow.start()
            viewFlow.next(); viewFlow.next(); viewFlow.next()
            compare(fakeCam.lastCall, "applyState")
            compare(fakeCam.lastArg.yaw, 30)
            compare(fakeCam.lastArg.distance, 90)
        }

        // A flow with no camera runs its view-carrying steps and simply does
        // not aim - it must not throw, and it must still advance.
        function test_aFlowWithoutACameraIgnoresTheView() {
            blindFlow.start()
            blindFlow.next()
            compare(blindFlow.index, 1, "it walked the steps")
            compare(fakeCam.calls, 0, "and aimed nothing")
        }
    }
}
