// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

// One region marker on the scene: a frame you can grab to move and four
// corners to resize by. The note itself never sits here - it lives in the
// margin panel with a leader line to this frame, so the marker never covers
// the thing it marks.
Item {
    id: root

    property string annId: ""
    property bool selected: false
    property color frameColor: "#ff3366"
    property int idx: 0
    readonly property int minSize: 24

    // Emitted once the drag or resize ends, so the store sees one write per
    // gesture instead of one per mouse move.
    signal geometryEdited()
    signal selectRequested()
    signal removeRequested()

    function _clamp() {
        width = Math.max(minSize, width);
        height = Math.max(minSize, height);
        x = Math.max(0, Math.min(x, parent.width - width));
        y = Math.max(0, Math.min(y, parent.height - height));
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.frameColor.r, root.frameColor.g,
                       root.frameColor.b, root.selected ? 0.16 : 0.08)
        border.color: root.frameColor
        border.width: root.selected ? 3 : 2
        radius: 2
    }

    // Corner ticks - a framed shot, not a form field
    Repeater {
        model: [[0, 0], [1, 0], [0, 1], [1, 1]]
        Item {
            readonly property int cx: modelData[0]
            readonly property int cy: modelData[1]
            x: cx === 0 ? 0 : root.width - 14
            y: cy === 0 ? 0 : root.height - 14
            width: 14
            height: 14
            Rectangle {
                width: 14; height: 3; color: root.frameColor
                y: parent.cy === 0 ? 0 : 11
            }
            Rectangle {
                width: 3; height: 14; color: root.frameColor
                x: parent.cx === 0 ? 0 : 11
            }
        }
    }

    // The number badge ties the frame to its card in the margin
    Rectangle {
        x: -1
        y: -height - 3
        width: badge.width + 12
        height: badge.height + 4
        radius: 3
        color: root.frameColor
        Text {
            id: badge
            anchors.centerIn: parent
            text: root.idx + 1
            color: "#1a1010"
            font.pixelSize: 13
            font.bold: true
        }
    }

    // Body drag - move the frame (and with it the note)
    MouseArea {
        anchors.fill: parent
        anchors.margins: 8
        cursorShape: Qt.SizeAllCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.maximumY: root.parent ? root.parent.height - root.height : 0
        onPressed: root.selectRequested()
        onReleased: { root._clamp(); root.geometryEdited(); }
        onDoubleClicked: root.selectRequested()
    }

    // Resize handles, one per corner
    Repeater {
        model: [[0, 0], [1, 0], [0, 1], [1, 1]]
        MouseArea {
            readonly property int cx: modelData[0]
            readonly property int cy: modelData[1]
            x: cx === 0 ? -8 : root.width - 12
            y: cy === 0 ? -8 : root.height - 12
            width: 20
            height: 20
            cursorShape: (cx === cy) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
            property real lastX: 0
            property real lastY: 0

            onPressed: function(mouse) {
                var p = mapToItem(root.parent, mouse.x, mouse.y);
                lastX = p.x; lastY = p.y;
                root.selectRequested();
            }
            onPositionChanged: function(mouse) {
                if (!pressed) return;
                var p = mapToItem(root.parent, mouse.x, mouse.y);
                var dx = p.x - lastX;
                var dy = p.y - lastY;
                lastX = p.x; lastY = p.y;
                if (cx === 0) {
                    var nw = root.width - dx;
                    if (nw >= root.minSize) { root.x += dx; root.width = nw; }
                } else {
                    root.width = Math.max(root.minSize, root.width + dx);
                }
                if (cy === 0) {
                    var nh = root.height - dy;
                    if (nh >= root.minSize) { root.y += dy; root.height = nh; }
                } else {
                    root.height = Math.max(root.minSize, root.height + dy);
                }
            }
            onReleased: { root._clamp(); root.geometryEdited(); }
        }
    }
}
