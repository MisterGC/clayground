// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The board store and the mouse gesture on it, with no domain and no GPU: a
// stub spec with one operable part, a fake stage whose worldAt maps window
// pixels straight onto board units, and no camera at all. What used to be
// checkable only by clicking in a running lab.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 400; height: 300

    readonly property var spec: ({
        block: { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }], half: { x: 4.6, y: 3.4 },
                 actuator: null, keepOut: 2, fields: { value: 1, on: false }, rows: ["value"] },
        lever: { terminals: [{ x: -3.5, y: 0 }, { x: 3.5, y: 0 }], half: { x: 4.6, y: 3.4 },
                 actuator: { x: 2.6, y: 2.0 }, keepOut: 2, fields: { value: 0, on: false }, rows: ["state"] }
    })

    Board {
        id: board
        cols: 20; rows: 12; cell: 5
        spec: root.spec
        onChanged: (kind) => { root.log.push(kind) }
        onRemoved: (id) => { root.removedIds.push(id) }
    }
    property var log: []
    property var removedIds: []
    property var operated: []

    // A stage whose window coordinates ARE board coordinates.
    QtObject {
        id: fakeStage
        function worldAt(view, mx, my) { return Qt.vector3d(mx, 0, my) }
    }
    // A camera controller that never wants the left button and never cancels.
    QtObject {
        id: fakeNav
        property bool active: false
        property int cursorShape: Qt.ArrowCursor
        signal cancelled()
        function begin(x, y, button, mods) { return button === Qt.RightButton ? "orbit" : "" }
        function cancel() {}
        function move(x, y) {}
        function end() {}
        function hoverAt(x, y) {}
        function wheel(d, x, y) {}
        function recenterAt(x, y) {}
    }

    GridMode { id: grid; step: board.cell }

    BoardInput {
        id: input
        board: board; nav: fakeNav; stage: fakeStage; view: null; grid: grid
        onOperate: (id) => { root.operated.push(id) }
    }

    TestCase {
        name: "Board"
        when: windowShown

        function init() {
            board.clear()
            board.eraser = false   // clear() keeps the tool, as a lab's C key does
            board.hoverHit = null
            root.log = []; root.removedIds = []; root.operated = []
            grid.snap = true
        }

        function test_addPlacesOnTheNearestFreeCell() {
            const a = board.addPart("block", 5, 5)
            const b = board.addPart("block", 5, 5)
            verify(a !== b)
            const pa = board.partAt(a), pb = board.partAt(b)
            compare(pa.col, 5); compare(pa.row, 5)
            verify(Math.abs(pb.col - 5) >= 2 || Math.abs(pb.row - 5) >= 2)
            compare(pa.value, 1); compare(pa.on, false); compare(pa.rot, 0)
            compare(root.log.length, 2)
            compare(root.log[0], "solve")
        }

        function test_batchPublishesOnce() {
            board.beginBatch()
            board.addPart("block", 2, 2)
            board.addPart("block", 8, 2)
            board.addWire([1, 1], [2, 0])
            compare(root.log.length, 0)
            board.endBatch()
            compare(root.log.length, 1)
            compare(board.parts.length, 2)
            compare(board.wires.length, 1)
        }

        function test_moveIsViewOnlyAndSnapRefusesATakenCell() {
            const a = board.addPart("block", 2, 2)
            const b = board.addPart("block", 8, 2)
            root.log = []
            board.movePart(b, 2.2, 2.1, true)          // onto a's cell: refused
            compare(board.partAt(b).col, 8)
            board.movePart(b, 8.4, 4.4, true)          // snaps
            compare(board.partAt(b).col, 8); compare(board.partAt(b).row, 4)
            board.movePart(b, 8.4, 4.4, false)         // free placement keeps fractions
            compare(board.partAt(b).col, 8.4)
            verify(root.log.every(k => k === "view"))
        }

        function test_rotateTurnsThePads() {
            const a = board.addPart("block", 4, 4)
            const before = board.terminalPos(a, 0)
            board.rotatePart(a)
            const after = board.terminalPos(a, 0)
            compare(board.partAt(a).rot, 90)
            fuzzyCompare(after.x, board.cellX(4), 1e-9)
            fuzzyCompare(after.z, board.cellZ(4) + 3.5, 1e-9)
            verify(Math.abs(before.x - after.x) > 1)
        }

        function test_removeTakesItsWiresAndSaysSo() {
            const a = board.addPart("block", 2, 2)
            const b = board.addPart("block", 8, 2)
            board.addWire([a, 1], [b, 0])
            board.selectedId = a
            board.removePart(a)
            compare(board.parts.length, 1)
            compare(board.wires.length, 0)
            compare(board.selectedId, -1)
            compare(root.removedIds.length, 1)
            compare(root.removedIds[0], a)
        }

        function test_wiresRefuseDuplicatesAndSelfLoops() {
            const a = board.addPart("block", 2, 2)
            const b = board.addPart("block", 8, 2)
            board.addWire([a, 1], [b, 0])
            board.addWire([b, 0], [a, 1])
            board.addWire([a, 0], [a, 0])
            compare(board.wires.length, 1)
        }

        function test_tapSplitsAWire() {
            const a = board.addPart("block", 2, 2)
            const b = board.addPart("block", 12, 2)
            board.addWire([a, 1], [b, 0])
            const mid = board.wireMid(board.wires[0])
            const j = board.splitWireAt(board.wires[0].id, mid.x, mid.z)
            verify(j !== -1)
            compare(board.partAt(j).type, "junction")
            compare(board.wires.length, 2)
            compare(board.terminalCount("junction"), 1)
        }

        function test_setFieldPublishesOnlyOnChange() {
            const a = board.addPart("block", 2, 2)
            root.log = []
            verify(board.setField(a, "value", 5))
            verify(!board.setField(a, "value", 5))
            compare(root.log.length, 1)
            compare(board.partAt(a).value, 5)
        }

        function test_stateRoundTrips() {
            const a = board.addPart("block", 2, 2)
            const b = board.addPart("lever", 8, 2)
            board.addWire([a, 1], [b, 0])
            board.setField(b, "on", true)
            const s = board.state()
            board.clear()
            compare(board.parts.length, 0)
            board.load(s)
            compare(board.parts.length, 2)
            compare(board.wires.length, 1)
            compare(board.partAt(b).on, true)
            compare(board.nextId, s.nextId)
        }

        function test_hitOrderActuatorTerminalBodyWire() {
            const a = board.addPart("lever", 4, 4)
            const b = board.addPart("block", 12, 4)
            board.addWire([a, 1], [b, 0])
            const cx = board.cellX(4), cz = board.cellZ(4)
            compare(board.hitAt(cx, cz).kind, "actuator")
            compare(board.hitAt(cx - 3.5, cz).kind, "terminal")
            compare(board.hitAt(board.cellX(12) + 1, board.cellZ(4)).kind, "element")
            compare(board.hitAt(board.cellX(8), cz).kind, "wire")
            compare(board.hitAt(board.cellX(8), cz + 3), null)
        }

        // --- the gesture, through the same named functions a hand drives ---
        function test_clickTwoPadsMakesAWire() {
            const a = board.addPart("block", 4, 4)
            const b = board.addPart("block", 12, 4)
            const pa = board.terminalPos(a, 1), pb = board.terminalPos(b, 0)
            input.clickAt(pa.x, pa.z)
            verify(board.wiringFrom !== null)
            compare(board.wiringFrom.el, a)
            input.clickAt(pb.x, pb.z)
            compare(board.wiringFrom, null)
            compare(board.wires.length, 1)
        }

        function test_clickSelectsAndDragMoves() {
            const a = board.addPart("block", 4, 4)
            const cx = board.cellX(4) + 1, cz = board.cellZ(4)
            input.clickAt(cx, cz)
            compare(board.selectedId, a)
            input.dragFrom(cx, cz, board.cellX(8) + 1, board.cellZ(6), 0)
            compare(board.partAt(a).col, 8)
            compare(board.partAt(a).row, 6)
            input.clickAt(board.cellX(1), board.cellZ(11))   // bare board clears
            compare(board.selectedId, -1)
        }

        function test_actuatorIsATwoStep() {
            const a = board.addPart("lever", 4, 4)
            const cx = board.cellX(4), cz = board.cellZ(4)
            input.moveAt(cx, cz, 0, false)
            verify(input.hoverActuatorIdle)
            verify(!input.hoverActuator)
            input.clickAt(cx, cz)
            compare(board.selectedId, a)
            compare(root.operated.length, 0)
            input.moveAt(cx, cz, 0, false)
            verify(input.hoverActuator)
            input.clickAt(cx, cz)
            compare(root.operated.length, 1)
            compare(root.operated[0], a)
        }

        function test_eraserRemovesWhatItClicks() {
            const a = board.addPart("block", 4, 4)
            const b = board.addPart("block", 12, 4)
            board.addWire([a, 1], [b, 0])
            board.eraser = true
            input.clickAt(board.cellX(8), board.cellZ(4))
            compare(board.wires.length, 0)
            input.clickAt(board.cellX(12) + 1, board.cellZ(4))
            compare(board.parts.length, 1)
        }

        function test_rightClickWalksBackOneStep() {
            const a = board.addPart("block", 4, 4)
            board.eraser = true
            board.selectedId = a
            board.wiringFrom = { el: a, ti: 0 }
            fakeNav.cancelled()
            compare(board.wiringFrom, null)
            verify(board.eraser)
            fakeNav.cancelled()
            verify(!board.eraser)
            compare(board.selectedId, a)
            fakeNav.cancelled()
            compare(board.selectedId, -1)
        }

        function test_hintFollowsTheState() {
            const a = board.addPart("lever", 4, 4)
            compare(input.hint, LabLang.t("hint.idle"))
            board.eraser = true
            compare(input.hint, LabLang.t("hint.eraser"))
            board.eraser = false
            board.selectedId = a
            verify(input.hint.indexOf(LabLang.t("hint.selected")) === 0)
            board.wiringFrom = { el: a, ti: 0 }
            compare(input.hint, LabLang.t("hint.wiring"))
        }

        function test_keysAndJumpTargets() {
            const a = board.addPart("block", 4, 4)
            const ks = board.keys(grid, null).concat(board.selectionKeys(null, grid))
            const letters = ks.map(k => k.key)
            verify(letters.indexOf("C") !== -1 && letters.indexOf("E") !== -1
                   && letters.indexOf("R") !== -1 && letters.indexOf("#") !== -1
                   && letters.indexOf("Del") !== -1)
            const t = board.jumpTargets((id) => "B" + id, (el) => el.type)
            compare(t.length, 1)
            compare(t[0].name, "B" + a)
            compare(t[0].group, "block")
            const b = board.bounds([a], 7)
            compare(b.length, 2)
            fuzzyCompare(b[1].x - b[0].x, 14, 1e-9)
        }
    }
}
