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

    // A clock nothing drives but the test. SimClock's frame ticker is off
    // whenever it has a world, and a world with no physics connects nothing -
    // so sim time only moves where a test moves it. The alternative,
    // Clayground.paused, is process-global and every tst_*.qml in this
    // directory shares one runner.
    QtObject { id: fakeWorld; property var physics: null }
    SimClock { id: clock; world: fakeWorld; sampleInterval: 0.1 }

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

    // --- the flows Lab.runFlow() is asked to walk --------------------------
    // Short dwells throughout: the run is in sim seconds, and a reading
    // estimate would only make the loop count bigger, never the check better.

    Flow {
        id: goodFlow
        lab: fakeLab
        flowId: "tst-good"

        FlowStep { key: "intro"; dwell: 0.3; say: "nothing yet" }
        FlowStep { key: "place"; dwell: 0.3; demo: [["let", "bat", "addPart", "battery"]] }
        FlowStep {
            key: "tag"
            task: ({ "until": (n) => fakeLab.tagged === n("bat"),
                     "solve": [["tagPart", "bat"]] })
        }
        FlowStep { key: "check"; dwell: 0.3; expect: (n) => fakeLab.tagged === n("bat") }
    }

    Flow {
        id: verblessFlow
        lab: fakeLab
        flowId: "tst-verbless"
        FlowStep { key: "nope"; dwell: 0.2; demo: [["noSuchVerb", 1], ["addPart", "led"]] }
    }

    Flow {
        id: endlessFlow
        lab: fakeLab
        flowId: "tst-endless"
        FlowStep { key: "never"; watch: ({ "until": () => false }) }
    }

    Flow {
        id: wrongFlow
        lab: fakeLab
        flowId: "tst-wrong"
        FlowStep { key: "claims"; dwell: 0.2; expect: () => false }
        FlowStep { key: "throws"; dwell: 0.2; expect: () => nothingHere.atAll }
    }

    Flow {
        id: unsolvableFlow
        lab: fakeLab
        flowId: "tst-unsolvable"
        FlowStep {
            key: "impossible"
            task: ({ "until": () => false, "solve": [["addPart", "led"]] })
        }
    }

    // --- who has the board (#221) -----------------------------------------
    // A lesson explains, hands over exactly the interaction it asked for,
    // takes the board back when that is done, and continues. These two flows
    // are the whole of that contract: one that names its subject, one that
    // names nothing and therefore keeps the pre-#221 behaviour.
    Flow {
        id: gatedFlow
        lab: fakeLab
        flowId: "tst-gated"
        pacing: "manual"

        FlowStep { key: "build"; demo: [["let", "sw", "addPart", "switch"],
                                        ["let", "other", "addPart", "led"]] }
        FlowStep {
            key: "flip"
            task: ({ "until": () => fakeLab.tagged !== -1,
                     "allow": ["sw"],
                     "solve": [["tagPart", "sw"]] })
        }
        FlowStep { key: "after" }
    }

    Flow {
        id: openTaskFlow
        lab: fakeLab
        flowId: "tst-opentask"
        pacing: "manual"

        FlowStep { key: "build"; demo: [["let", "sw", "addPart", "switch"]] }
        FlowStep {
            key: "anything"
            task: ({ "until": () => fakeLab.tagged !== -1,
                     "solve": [["tagPart", "sw"]] })
        }
    }

    TestCase {
        name: "Flow"

        function init() {
            fakeLab.parts = []
            fakeLab.nextId = 1
            fakeLab.tagged = -1
            flow.stop(); viewFlow.stop(); blindFlow.stop()
            goodFlow.stop(); verblessFlow.stop(); endlessFlow.stop()
            wrongFlow.stop(); unsolvableFlow.stop()
            gatedFlow.stop(); openTaskFlow.stop()
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

        // --- Lab.runFlow: a flow walked with nobody watching (#207) ---------

        function test_aHealthyFlowRunsToItsEnd() {
            const r = Lab.runFlow("tst-good")
            verify(r.error === undefined, "it had everything it needed")
            verify(r.finished, "it reached the end rather than the bound")
            compare(r.unresolvedVerbs, [], "every verb resolved")
            compare(r.failedTasks, [], "the task was solved by the runner")
            compare(r.failedExpects, [], "and the expect held")
            compare(fakeLab.tagged, 1, "solve() really ran the lab's verb")
            verify(r.steps > 0, "it advanced the clock")
            verify(!goodFlow.running, "and left nothing running")
        }

        function test_headlessIsSetForTheRunAndRestoredAfter() {
            compare(Lab.headless, false)
            Lab.runFlow("tst-good")
            compare(Lab.headless, false, "the flag does not outlive the run")
        }

        function test_pacingIsRestoredAfterTheRun() {
            compare(goodFlow.pacing, "ready")
            Lab.runFlow("tst-good")
            compare(goodFlow.pacing, "ready", "auto was borrowed, not kept")
        }

        // A lab verb that does not resolve fails silently: the demo runs, the
        // action does nothing, and the flow teaches nothing. The whole point
        // of a headless run is that this is reported rather than warned about.
        function test_anUnresolvedVerbIsReported() {
            const r = Lab.runFlow("tst-verbless")
            compare(r.unresolvedVerbs, ["noSuchVerb"])
            verify(r.finished, "the rest of the step still ran")
            compare(fakeLab.parts.length, 1, "including the verb that did resolve")
        }

        function test_theMaxStepsBoundIsHonoured() {
            const r = Lab.runFlow("tst-endless", { maxSteps: 120 })
            compare(r.steps, 120, "it stopped at the bound")
            compare(r.finished, false, "and says so rather than claiming success")
            verify(!endlessFlow.running, "the bounded flow is left stopped")
        }

        function test_aWrongExpectLandsInFailedExpectsWithItsKey() {
            const r = Lab.runFlow("tst-wrong")
            compare(r.failedExpects.length, 2)
            compare(r.failedExpects[0].step, "claims")
            compare(r.failedExpects[0].index, 0)
            compare(r.failedExpects[1].step, "throws")
            verify(r.failedExpects[1].error !== undefined,
                   "a predicate that throws is a failure with its message")
        }

        function test_aTaskThatSolveCannotSatisfyIsReported() {
            const r = Lab.runFlow("tst-unsolvable", { solveGrace: 0.5 })
            compare(r.failedTasks.length, 1)
            compare(r.failedTasks[0].step, "impossible")
            verify(r.steps < 20000, "it walked on instead of eating the budget")
        }

        function test_anUnknownFlowIsAnErrorNotAnEmptyRun() {
            const r = Lab.runFlow("no-such-flow")
            verify(r.error !== undefined, "it says why")
            compare(r.finished, false)
            compare(r.steps, 0)
        }

        // --- who has the board (#221) ------------------------------------

        function test_theBoardIsTheLearnersUntilAFlowStarts() {
            compare(gatedFlow.control, "learner")
            verify(gatedFlow.grants(1), "with nothing running, everything is live")
            verify(gatedFlow.grants(999), "including a part that does not exist")
        }

        function test_aDemoStepLocksTheWholeBoard() {
            gatedFlow.start()
            compare(gatedFlow.control, "flow")
            verify(!gatedFlow.grants(fakeLab.parts[0].id), "not even the switch")
            verify(!gatedFlow.grants(fakeLab.parts[1].id))
        }

        function test_aTaskOpensWhatItNamedAndNothingElse() {
            gatedFlow.start()
            gatedFlow.next()
            compare(gatedFlow.control, "task")
            compare(gatedFlow.grants(gatedFlow.nameOf("sw")), true,
                    "the part the task named answers")
            compare(gatedFlow.grants(gatedFlow.nameOf("other")), false,
                    "the one beside it does not")
        }

        // The bug this exists for: the task is satisfied, the flow is already
        // narrating the result, and a second click is still landing on the
        // board it was talking about.
        function test_theBoardIsLockedAgainTheInstantTheTaskIsDone() {
            gatedFlow.start()
            gatedFlow.next()
            fakeLab.tagPart(gatedFlow.nameOf("sw"))
            verify(gatedFlow.check(), "check() saw the task was done")
            compare(gatedFlow.index, 2, "and walked on")
            compare(gatedFlow.control, "flow")
            verify(!gatedFlow.grants(gatedFlow.nameOf("sw")),
                   "the part the task lent out is the flow's again")
        }

        function test_checkIsANoOpOutsideAnUnsatisfiedTask() {
            gatedFlow.start()
            compare(gatedFlow.check(), false, "not on a demo step")
            gatedFlow.next()
            compare(gatedFlow.check(), false, "nor on a task nobody has done")
            compare(gatedFlow.index, 1, "and it moved nothing")
        }

        function test_leavingHandsTheWholeBoardBack() {
            gatedFlow.start()
            verify(!gatedFlow.grants(fakeLab.parts[0].id))
            gatedFlow.stop()
            compare(gatedFlow.control, "learner")
            verify(gatedFlow.grants(fakeLab.parts[0].id), "at once, with no step in between")
        }

        // The compatibility story: a task that names nothing is a task that
        // asks for nothing in particular, and the whole board stays live.
        function test_aTaskThatNamesNothingKeepsTheBoardLive() {
            openTaskFlow.start()
            verify(!openTaskFlow.grants(fakeLab.parts[0].id), "its demo step still locks")
            openTaskFlow.next()
            compare(openTaskFlow.control, "task")
            verify(openTaskFlow.grants(fakeLab.parts[0].id))
            verify(openTaskFlow.grants(4242), "anything at all")
        }

        function test_aRefusalIsSaidAndThenForgotten() {
            gatedFlow.start()
            compare(gatedFlow.refusal, "")
            gatedFlow.refuse()
            compare(gatedFlow.refusal, "flow.refuse.busy", "the flow is working")
            gatedFlow.next()
            gatedFlow.refuse()
            compare(gatedFlow.refusal, "flow.refuse.task", "the learner clicked the wrong thing")
            gatedFlow.stop()
            compare(gatedFlow.refusal, "", "leaving clears it")
        }

        // The headless run performs each task through solve(), which drives
        // the lab's verbs and never touches the input layer - so a locked
        // board cannot lock the verification run out.
        function test_theHeadlessRunSolvesAGatedFlowAnyway() {
            const r = Lab.runFlow("tst-gated")
            compare(r.failedTasks, [], "the task was solved")
            verify(r.finished, "and the flow reached its end")
        }
    }
}
