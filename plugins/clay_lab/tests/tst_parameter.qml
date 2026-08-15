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

        Component.onCompleted: labRoot.seenAtCompletion = Lab.p("tstDemand")

        Parameter { name: "tstDemand"; value: 0.75; from: 0; to: 3 }
        Parameter { id: renamed; name: "tstBefore"; value: 4; from: 0; to: 10 }
    }

    TestCase {
        name: "Parameter"

        function test_readableFromTheRootsOwnCompletion() {
            compare(labRoot.seenAtCompletion, 0.75,
                    "the root read the declared value, not the 0 of an unknown name")
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

        // A rename moves the entry rather than leaving a ghost behind.
        function test_renameMovesTheEntry() {
            renamed.name = "tstAfter"
            compare(Lab.paramNames.indexOf("tstBefore"), -1)
            compare(Lab.p("tstAfter"), 4)
            renamed.name = "tstBefore"
        }
    }
}
