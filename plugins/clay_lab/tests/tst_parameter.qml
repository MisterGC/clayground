// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// When a Parameter becomes readable.
//
// Component.onCompleted runs in creation order, so a sandbox root's own
// handler - the one that cold-opens a scenario - fires BEFORE its children's.
// A Parameter that waited for completion was therefore still unknown to Lab
// while the lab was setting itself up: street-network booted with twenty
// "Lab: unknown parameter" warnings and derived its traffic from 0 instead of
// from the declared demand. Registration happens when the name arrives.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // Stands in for a sandbox root: reads its own parameters from the handler
    // that a lab uses to apply its opening scenario.
    Item {
        id: labRoot

        property real seenAtCompletion: -1
        property real earlyAfterSet: -1

        // ...and, like a scenario opened there, changes one of them before
        // that parameter has completed.
        Component.onCompleted: {
            labRoot.seenAtCompletion = Lab.p("tstDemand")
            Lab.set("tstEarly", 7)
            labRoot.earlyAfterSet = Lab.p("tstEarly")
        }

        Parameter { name: "tstDemand"; value: 0.75; from: 0; to: 3 }
        Parameter { id: renamed; name: "tstBefore"; value: 4; from: 0; to: 10 }
        Parameter { id: early; name: "tstEarly"; value: 2; from: 0; to: 10 }
        Parameter { id: chosen; name: "tstChosen"; value: 5; defaultValue: 1; from: 0; to: 10 }
        Parameter { id: open; name: "tstOpen"; value: 0; from: 0; to: 0 }
    }

    TestCase {
        name: "Parameter"

        function test_readableFromTheRootsOwnCompletion() {
            compare(labRoot.seenAtCompletion, 0.75,
                    "the root read the declared value, not the 0 of an unknown name")
        }

        function test_aSetFromTheRootsOwnCompletionIsApplied() {
            compare(labRoot.earlyAfterSet, 7)
        }

        function test_registeredUnderItsName() {
            verify(Lab.paramNames.indexOf("tstDemand") !== -1)
            compare(Lab.p("tstDemand"), 0.75)
        }

        function test_setIsClampedToTheRange() {
            verify(Lab.set("tstDemand", 99))
            compare(Lab.p("tstDemand"), 3)
            verify(Lab.set("tstDemand", 0.75))
        }

        // to <= from declares no range, so there is nothing to refuse.
        function test_aParameterWithoutARangeTakesAnyValue() {
            verify(Lab.set("tstOpen", 1234))
            compare(open.value, 1234)
            open.reset()
        }

        function test_theDeclaredValueIsRemembered() {
            compare(renamed.defaultValue, 4)
            verify(Lab.set("tstBefore", 9))
            compare(renamed.defaultValue, 4)
            renamed.reset()
            compare(renamed.value, 4)
        }

        // The root set tstEarly to 7 before tstEarly completed; what it was
        // declared with is still 2.
        function test_aSetBeforeCompletionKeepsTheDeclaredValue() {
            compare(early.defaultValue, 2)
            early.reset()
            compare(early.value, 2)
        }

        function test_anExplicitDefaultValueWins() {
            compare(chosen.defaultValue, 1)
            chosen.reset()
            compare(chosen.value, 1)
            chosen.value = 5
        }

        function test_resetParametersPutsEveryParameterBack() {
            verify(Lab.set("tstDemand", 2.5))
            verify(Lab.set("tstBefore", 8))
            verify(Lab.set("tstEarly", 9))
            Lab.resetParameters()
            compare(Lab.p("tstDemand"), 0.75)
            compare(Lab.p("tstBefore"), 4)
            compare(Lab.p("tstEarly"), 2)
            compare(Lab.p("tstChosen"), 1)
            chosen.value = 5
        }

        // A rename moves the entry rather than leaving a ghost behind.
        function test_renameMovesTheEntry() {
            renamed.name = "tstAfter"
            compare(Lab.paramNames.indexOf("tstBefore"), -1)
            compare(Lab.p("tstAfter"), 4)
            renamed.name = "tstBefore"
        }
    }
}
