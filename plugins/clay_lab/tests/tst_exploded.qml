// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ExplodedView3D against a subject nobody has heard of: a box with a lid and
// two pins in the lid, one row handed in as a table row. No View3D, no GPU -
// a Node tree answers scene positions on its own, and everything the block
// promises is a number: where a part is, where it is going, what dims, which
// labels there are, where an assembly line runs.
//
// Two claims are worth a suite of their own. A nested part travels WITH its
// parent in the parent's stage and on its own in its own, and its assembly
// line runs from where it sat in the moved parent - the classic drawing's
// rule for a sub-assembly. And goal and interpolant are two properties, so a
// flow walked headless by Lab.runFlow asserts what it asked for and never
// what a frame would have drawn.

import QtQuick
import QtQuick3D
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    // A clock nothing drives but the runner (the tst_flow.qml pattern).
    QtObject { id: fakeWorld; property var physics: null }
    SimClock { id: clock; world: fakeWorld; sampleInterval: 0.1 }

    // A lab just real enough to be driven: the three verbs a lesson about a
    // subject needs, each setting a goal.
    Item {
        id: fakeLab
        function flowActions() {
            return {
                "explode": (v) => { asm.spread = v === undefined ? 1 : v },
                "focus":   (id) => { asm.focus = id === undefined || id === null ? "" : id },
                "label":   (w) => { asm.labelled = w === "none" ? [] : w }
            }
        }
        function viewState() { return {} }
        function applyViewState(s) {}
    }

    ExplodedView3D {
        id: asm
        glideMs: 0
        labels: ({ box: "Box", lid: "Lid", "pin.a": "Pin A" })

        ExplodePart {
            partId: "box"; order: 1
            position: Qt.vector3d(0, 0, 0); anchor: Qt.vector3d(0, 1, 1.5)
        }
        ExplodePart {
            partId: "lid"; order: 2; stage: 1; offset: Qt.vector3d(0, 4, 0)
            position: Qt.vector3d(0, 2, 0); anchor: Qt.vector3d(0, 0.4, 1.5)
            ExplodePart {
                partId: "pin.a"; order: 3; stage: 2; offset: Qt.vector3d(-2.5, 0, 0)
                position: Qt.vector3d(-1.5, 0.4, 0); anchor: Qt.vector3d(0, 0.6, 0)
            }
            ExplodePart {
                partId: "pin.b"; order: 4; stage: 2; offset: Qt.vector3d(2.5, 0, 0)
                position: Qt.vector3d(1.5, 0.4, 0); anchor: Qt.vector3d(0, 0.6, 0)
            }
        }
        // A row as a kit's table would hand it over: plain numbers, no
        // vector3d, and nothing else declared on the part.
        ExplodePart {
            row: ({ id: "print", role: "print", order: 0, stage: 1,
                    offset: { x: 0, y: 0, z: 0 }, anchor: { x: 0, y: 0.01, z: 1.4 } })
            position: Qt.vector3d(0, 0.02, 0)
        }
    }

    // The same block with a glide, for the one claim the instant one cannot
    // make: that the interpolant lags the goal.
    ExplodedView3D {
        id: gliding
        glideMs: 400
        ExplodePart { partId: "a"; order: 1; offset: Qt.vector3d(0, 1, 0) }
    }

    Flow {
        id: lesson
        lab: fakeLab
        flowId: "tst-exploded"

        FlowStep { key: "meet";   dwell: 0.2; demo: [["explode", 0], ["focus", ""], ["label", "none"]]
                   expect: () => asm.spread === 0 && asm.focus === "" && asm.marks.length === 0 }
        FlowStep { key: "shell";  dwell: 0.2; demo: [["explode", 1]]; mark: ["lid"]
                   expect: () => asm.spread === 1 }
        FlowStep { key: "inside"; dwell: 0.2; demo: [["explode", 2], ["focus", "pin.a"]]
                   expect: () => asm.spread === 2 && asm.focus === "pin.a" }
        FlowStep { key: "named";  dwell: 0.2; demo: [["label", "all"]]
                   expect: () => asm.marks.length === 4 && asm.marks[2].id === "pin.a" }
        FlowStep { key: "close";  dwell: 0.2; demo: [["focus", ""], ["label", "none"], ["explode", 0]]
                   expect: () => asm.spread === 0 && asm.focus === "" && asm.marks.length === 0 }
    }

    TestCase {
        name: "ExplodedView3D"
        when: windowShown

        function init() {
            asm.spread = 0
            asm.focus = ""
            asm.labelled = []
        }

        function near(v, x, y, z, what) {
            fuzzyCompare(v.x, x, 1e-4, what + " x")
            fuzzyCompare(v.y, y, 1e-4, what + " y")
            fuzzyCompare(v.z, z, 1e-4, what + " z")
        }

        // --- the table -------------------------------------------------------

        function test_thePartsAreTheTable() {
            compare(asm.partIds, ["box", "lid", "pin.a", "pin.b", "print"], "document order, nested included")
            compare(asm.stages, 2)
            compare(asm.idsInOrder(), ["box", "lid", "pin.a", "pin.b"], "the print is never explained")
            compare(asm.table[2].parent, "lid", "a nested part names the part it sits in")
            compare(asm.table[0].parent, "", "a top-level part names none")
            compare(asm.table[2].stage, 2)
            fuzzyCompare(asm.table[1].offset.y, 4, 1e-6)
        }

        function test_aRowFillsThePart() {
            const p = asm.partOf("print")
            verify(p !== null, "the part declared by row was found by its row's id")
            compare(p.order, 0)
            compare(p.role, "print")
            compare(p.stage, 1)
            fuzzyCompare(p.anchor.z, 1.4, 1e-5)
            compare(asm.partOf("nope"), null)
        }

        function test_aStrangerAnswersNaN() {
            const p = asm.partAt("nope")
            verify(p.x !== p.x && p.y !== p.y && p.z !== p.z, "NaN, not a throw and not the origin")
        }

        // --- where things are ------------------------------------------------

        function test_assembledIsWhereItWasAuthored() {
            near(asm.partAt("box"), 0, 1, 1.5, "the box's anchor")
            near(asm.partAt("lid"), 0, 2.4, 1.5, "the lid's anchor on the lid")
            near(asm.partAt("pin.a"), -1.5, 3, 0, "a pin in the lid: lid pose + pin pose + anchor")
            compare(asm.lines.length, 0, "nothing has left its place")
        }

        function test_stagesComeApartInOrder() {
            asm.spread = 1
            compare(asm.spreadNow, 1, "instant with glideMs 0")
            near(asm.partAt("lid"), 0, 6.4, 1.5, "the lid is off at spread 1")
            near(asm.partAt("pin.a"), -1.5, 7, 0, "the pin went WITH the lid and not on its own")
            asm.spread = 1.5
            near(asm.partAt("pin.a"), -2.75, 7, 0, "half way through stage 2")
            asm.spread = 2
            near(asm.partAt("pin.a"), -4, 7, 0, "and out at spread 2")
            near(asm.partAt("pin.b"), 4, 7, 0)
            near(asm.partAt("box"), 0, 1, 1.5, "a part with no offset never moves")
            asm.spread = 0
            near(asm.partAt("pin.a"), -1.5, 3, 0, "and everything comes back")
        }

        function test_theGoalPositionIsWhereItIsGoing() {
            near(asm.partAt("pin.a", 2), -4, 7, 0, "from assembled: the lid's lift plus the pin's slide")
            near(asm.partAt("pin.a", 1), -1.5, 7, 0, "at spread 1 only the lid has moved")
            asm.spread = 2
            near(asm.partAt("pin.a", 0), -1.5, 3, 0, "from exploded: back to the assembled place")
            near(asm.partAt("pin.a"), -4, 7, 0, "and without a spread, where it is now")
        }

        function test_assemblyLinesRunFromTheAssembledPlace() {
            asm.spread = 2
            compare(asm.lines.length, 3, "the box never moved, the other three did")
            const lid = asm.lines[0]
            compare(lid.id, "lid")
            near(lid.from, 0, 2.4, 1.5, "from where the lid sat")
            near(lid.to, 0, 6.4, 1.5, "to where it is")
            const pin = asm.lines[1]
            compare(pin.id, "pin.a")
            near(pin.from, -1.5, 7, 0, "a pin's line starts where it sat in the MOVED lid")
            near(pin.to, -4, 7, 0)
            asm.assemblyLines = false
            compare(asm.lines.length, 3, "the numbers stay; only the drawing is switched off")
            asm.assemblyLines = true
            asm.spread = 0
            compare(asm.lines.length, 0)
        }

        // --- focus -----------------------------------------------------------

        function test_focusKeepsTheChainLit() {
            asm.focus = "pin.a"
            compare(asm.focusNow, 1, "instant with glideMs 0")
            compare(asm.partOf("pin.a").dimmed, false, "the part itself")
            compare(asm.partOf("lid").dimmed, false, "the part it sits in (opacity inherits)")
            compare(asm.partOf("pin.b").dimmed, true, "its sibling")
            compare(asm.partOf("box").dimmed, true)
            compare(asm.partOf("print").dimmed, true)
            fuzzyCompare(asm.partOf("box").opacity, asm.dimOpacity, 1e-6, "dimmed all the way")
            fuzzyCompare(asm.partOf("lid").opacity, 1, 1e-6)
            asm.focus = "lid"
            compare(asm.partOf("pin.b").dimmed, false, "focusing a sub-assembly shows all of it")
            compare(asm.partOf("box").dimmed, true)
            asm.focus = ""
            compare(asm.focusNow, 0)
            compare(asm.partOf("box").dimmed, false)
            fuzzyCompare(asm.partOf("box").opacity, 1, 1e-6)
        }

        // --- labels ----------------------------------------------------------

        function test_labelsComeFromTheTable() {
            asm.labelled = "all"
            compare(asm.marks.map(m => m.id), ["box", "lid", "pin.a", "pin.b"], "teaching order")
            compare(asm.marks.map(m => m.label), ["Box", "Lid", "Pin A", "pin.b"], "the dictionary, else the id")
            near(asm.marks[1].at, 0, 2.4, 1.5, "a mark sits on the part's anchor")
            asm.spread = 1
            near(asm.marks[1].at, 0, 6.4, 1.5, "and follows it")
            asm.labelled = ["pin.b", "nope", "box"]
            compare(asm.marks.map(m => m.id), ["pin.b", "box"], "a list keeps its order and drops strangers")
            asm.labelled = []
            compare(asm.marks.length, 0)
        }

        // --- goal and interpolant --------------------------------------------

        function test_goalAndInterpolantAreTwoProperties() {
            compare(gliding.spreadNow, 0)
            gliding.spread = 1
            compare(gliding.spread, 1, "the goal is what was asked for")
            verify(gliding.spreadNow < 1, "the interpolant has not arrived")
            verify(gliding.animating)
            tryCompare(gliding, "spreadNow", 1, 3000)
            tryCompare(gliding, "animating", false, 3000)
            near(gliding.partAt("a"), 0, 1, 0)
            gliding.spread = 0
            tryCompare(gliding, "spreadNow", 0, 3000)
        }

        function test_runFlowAssertsTheGoalsHeadless() {
            const r = Lab.runFlow("tst-exploded")
            verify(r.error === undefined, "the flow had everything it needed")
            verify(r.finished, "it reached the end rather than the bound")
            compare(r.unresolvedVerbs, [], "explode, focus and label all resolved")
            compare(r.failedTasks, [])
            compare(r.failedExpects, [], "every expect on a goal held with no frame ever drawn")
            verify(r.steps > 0)
            compare(asm.spread, 0, "the lesson put the subject back together")
        }

        // --- a part added later ----------------------------------------------

        function test_refreshFindsAPartAddedLater() {
            const late = Qt.createQmlObject(
                'import QtQuick; import QtQuick3D; import Clayground.Lab; ' +
                'ExplodePart { partId: "late"; order: 5; offset: Qt.vector3d(0, 0, 3) }', asm)
            late.parent = asm
            compare(asm.partIds.length, 5, "not seen until asked")
            asm.refresh()
            compare(asm.partIds.length, 6)
            compare(asm.idsInOrder()[4], "late")
            late.parent = null
            asm.refresh()
            compare(asm.partIds.length, 5)
            late.destroy()
        }
    }
}
