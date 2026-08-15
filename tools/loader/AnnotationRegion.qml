// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

// One region marker on the scene: a frame you can grab to move and four
// corners to resize by. The note itself never sits here - it lives in the
// margin panel, and the number badge is what says which card belongs to this
// frame. There is no line between the two: the panel floats and folds, so a
// connector would have to cross it, and it drew nothing but noise when it did.
//
// Three states, told apart by colour AND weight: pink is idle, gold is the
// pairing, and a second gold ring outside the frame is what makes a click
// stick rather than a cursor merely passing over it.
Item {
    id: root

    property string annId: ""
    property bool selected: false
    // The counterpart is under the cursor - the frame previews the pairing
    // without claiming it.
    property bool hovered: false
    property color baseColor: "#ff3366"
    property color highlightColor: "#ffd93d"
    readonly property color frameColor: (selected || hovered) ? highlightColor
                                                              : baseColor
    property int idx: 0
    readonly property int minSize: 24

    // Emitted once the drag or resize ends, so the store sees one write per
    // gesture instead of one per mouse move.
    signal geometryEdited()
    signal selectRequested()
    signal removeRequested()
    signal hoverRequested(bool on)

    // Reports for the whole marker, children included: the number badge and
    // the resize corners are part of "the cursor is on this frame".
    HoverHandler {
        id: hoverProbe
        onHoveredChanged: root.hoverRequested(hoverProbe.hovered)
    }

    function _clamp() {
        width = Math.max(minSize, width);
        height = Math.max(minSize, height);
        x = Math.max(0, Math.min(x, parent.width - width));
        y = Math.max(0, Math.min(y, parent.height - height));
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.frameColor.r, root.frameColor.g, root.frameColor.b,
                       root.selected ? 0.22 : (root.hovered ? 0.14 : 0.08))
        border.color: root.frameColor
        border.width: root.selected ? 3 : 2
        radius: 2
    }

    // The halo is selection alone. Hover recolours; only a click adds a ring,
    // so a cursor drifting across the scene never looks like a choice made.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -5
        color: "transparent"
        border.color: Qt.rgba(root.highlightColor.r, root.highlightColor.g,
                              root.highlightColor.b, 0.5)
        border.width: 2
        radius: 6
        visible: root.selected
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

    // The number badge ties the frame to its card in the margin. With no line
    // between them it is the ONLY static thing that says they belong together,
    // so it is never allowed to be clipped: it sits above the frame when there
    // is room, drops inside the frame when the frame hugs the top edge, and
    // slides along to stay inside the viewport sideways. It also never shrinks
    // with the frame - a 24px frame carries the same readable number as a big
    // one, sticking out of it if it must.
    Rectangle {
        id: badgeChip
        objectName: "annotationRegionBadge"
        width: badge.width + 12
        height: badge.height + 4
        x: {
            var vw = root.parent ? root.parent.width : 0;
            var lo = -root.x + 2;
            var hi = vw - root.x - width - 2;
            return hi < lo ? lo : Math.max(lo, Math.min(-1, hi));
        }
        y: root.y >= height + 5 ? -height - 3 : 3
        radius: 3
        // The chip follows the SELECTION, not the hover - exactly as its twin
        // on the card does. A hover recolours the outline at both ends and
        // leaves the number's own colour alone, so the two numbers always
        // agree about which of them is picked.
        color: root.selected ? root.highlightColor : root.baseColor
        // A dark collar so the number reads over a bright scene as well as a
        // dark one - the frame can be anywhere, the badge cannot pick a
        // background.
        border.color: root.hovered && !root.selected ? root.highlightColor
                                                     : "#801a1010"
        border.width: 1
        Text {
            id: badge
            anchors.centerIn: parent
            text: root.idx + 1
            color: "#1a1010"
            font.pixelSize: root.selected ? 15 : 13
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
