// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A slider stops at its ends.
//
// Lab.set() refuses a value outside a parameter's range (#566) - right for an
// agent asking for 12 on a 0.5 to 10 parameter, wrong for a slider: an arrow
// press at the end, or a stepped drag whose step lands past `to`, would be
// refused and leave the value short of the end with a warning per press. The
// panel clamps what it hands Lab.set() instead.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: host
    width: 400; height: 400

    Parameter { id: nudged; name: "tstPanelNudged"; value: 0.95; from: 0; to: 1; stepSize: 0.1 }
    // 0..1 in steps of 0.6: the step nearest the right end is 1.2
    Parameter { id: dragged; name: "tstPanelDragged"; value: 0; from: 0; to: 1; stepSize: 0.6 }

    ParamPanel { id: panel; width: 300 }

    function find(item, name) {
        if (item.objectName === name) return item
        for (let i = 0; i < item.children.length; ++i) {
            const r = find(item.children[i], name)
            if (r) return r
        }
        return null
    }

    TestCase {
        name: "ParamPanel"
        when: windowShown

        function test_anArrowAtTheEndStopsThere() {
            failOnWarning(/Lab: parameter/)
            const slider = find(panel, "paramSlider.tstPanelNudged")
            verify(slider, "the slider of tstPanelNudged")
            slider.forceActiveFocus()
            keyClick(Qt.Key_Up)
            compare(nudged.value, 1)
            keyClick(Qt.Key_Up)
            compare(nudged.value, 1)
            keyClick(Qt.Key_PageDown)
            keyClick(Qt.Key_PageDown)
            compare(nudged.value, 0)
        }

        function test_aSteppedDragPastTheEndStopsThere() {
            failOnWarning(/Lab: parameter/)
            const slider = find(panel, "paramSlider.tstPanelDragged")
            verify(slider, "the slider of tstPanelDragged")
            mouseClick(slider, slider.width - 1, slider.height / 2)
            compare(dragged.value, 1)
        }
    }
}
