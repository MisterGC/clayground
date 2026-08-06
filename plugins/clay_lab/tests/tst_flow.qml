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

    Flow {
        id: flow
        lab: fakeLab
        flowId: "tst"
        pacing: "manual"

        FlowStep { key: "intro"; say: "look at the empty board" }
        FlowStep { key: "place"; say: "a battery"; demo: [["let", "bat", "addPart", "battery"]] }
        FlowStep { key: "tag"; say: "mark it"; demo: [["tagPart", "bat"]] }
    }

    TestCase {
        name: "Flow"

        function init() {
            fakeLab.parts = []
            fakeLab.nextId = 1
            fakeLab.tagged = -1
            flow.stop()
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
    }
}
