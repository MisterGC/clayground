// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The grid contract every lab is supposed to share. Its whole value is that it
// is shared: two labs had re-implemented `snapping()` and the rounding beside
// it, and one of them then wired a palette button to a readonly alias, so the
// button did nothing at all. Small type, guarded so it stays the one answer.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    width: 50; height: 50

    GridMode { id: grid; step: 10 }

    TestCase {
        name: "GridMode"

        function init() { grid.snap = true }

        function test_toggleFlipsTheMode() {
            grid.toggle()
            verify(!grid.snap)
            grid.toggle()
            verify(grid.snap)
        }

        function test_altInvertsForOneGesture() {
            verify(grid.snapping(Qt.NoModifier))
            verify(!grid.snapping(Qt.AltModifier))
            grid.snap = false
            verify(!grid.snapping(Qt.NoModifier))
            verify(grid.snapping(Qt.AltModifier))
        }

        function test_quantizeFollowsTheGesture() {
            compare(grid.quantize(13, Qt.NoModifier), 10)
            compare(grid.quantize(-13, Qt.NoModifier), -10)
            compare(grid.quantize(13, Qt.AltModifier), 13)
            grid.snap = false
            compare(grid.quantize(13, Qt.NoModifier), 13)
            compare(grid.quantize(13, Qt.AltModifier), 10)
        }
    }
}
