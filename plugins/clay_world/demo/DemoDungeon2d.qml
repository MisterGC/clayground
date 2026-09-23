// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World

// A small grid dungeon made of flat shapes, shared by the lighting and the
// screen-effect demos: walls on a grid (isWall(cx, cy), cell (0,0) bottom-left),
// torch spots on wall faces and a walker that loops through the rooms.
ClayWorld2d {
    id: dungeon

    components: new Map()
    gravity: Qt.point(0, 0)
    running: false
    xWuMax: cols * cellSize
    yWuMax: rows * cellSize

    readonly property int cellSize: 2
    readonly property var map: [
        "########################",
        "#......#.......#.......#",
        "#......#.......#.......#",
        "#..............#.......#",
        "#......#.......#.......#",
        "####.#####..####...#####",
        "#.........#............#",
        "#..##.....#....##......#",
        "#..##.....#....##......#",
        "#.........#............#",
        "#....................#.#",
        "######.######.####.###.#",
        "#.......#..............#",
        "#.......#......#.......#",
        "#..............#.......#",
        "########################"
    ]
    readonly property int cols: map[0].length
    readonly property int rows: map.length

    function isWall(cx, cy) {
        if (cx < 0 || cy < 0 || cx >= cols || cy >= rows) return true;
        return map[rows - 1 - cy].charAt(cx) === "#";
    }

    // Wall-mounted torches: each sits 0.4 wu in front of a wall face.
    readonly property var torches: [
        {x: 7, y: 29.6, color: "#ffb050"},
        {x: 23, y: 29.6, color: "#ffa848"},
        {x: 45.6, y: 25, color: "#ff9a40"},
        {x: 5, y: 19.6, color: "#ffb050"},
        {x: 27, y: 19.6, color: "#70a0ff"},
        {x: 9, y: 2.4, color: "#ffa848"},
        {x: 39, y: 2.4, color: "#70ff90"}
    ]

    // The walker: loops through the rooms along a fixed path, driven by t.
    property real walkT: 0
    property bool walking: true
    NumberAnimation on walkT {
        // paused, not stopped: a stopped animation restarts from 0.
        running: true
        paused: !dungeon.walking
        from: 0; to: 1; duration: 60000; loops: Animation.Infinite
    }
    readonly property var path: [
        [5, 27], [13, 27], [13, 25], [23, 25], [23, 19], [37, 19], [37, 23],
        [41, 23], [41, 17], [35, 17], [35, 13], [23, 13], [23, 11], [17, 11],
        [17, 13], [13, 13], [13, 7], [7, 7], [15, 7], [15, 3], [29, 3],
        [29, 7], [37, 7], [37, 5], [45, 5], [45, 13], [25, 13], [25, 19],
        [23, 19], [23, 21], [21, 21], [21, 23], [17, 23], [17, 25], [5, 25],
        [5, 27]
    ]
    readonly property var _cum: {
        var c = [0];
        for (var i = 1; i < path.length; ++i)
            c.push(c[i - 1] + Math.hypot(path[i][0] - path[i - 1][0],
                                         path[i][1] - path[i - 1][1]));
        return c;
    }
    // Constant speed along the path: t is a fraction of its length.
    function pathPoint(t) {
        var len = _cum[_cum.length - 1];
        var d = (t - Math.floor(t)) * len;
        var i = 1;
        while (i < _cum.length - 1 && _cum[i] < d) ++i;
        var seg = _cum[i] - _cum[i - 1];
        var u = seg > 0 ? (d - _cum[i - 1]) / seg : 0;
        var a = path[i - 1], b = path[i];
        return Qt.point(a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u);
    }

    property alias walker: _walker

    Item {
        id: _floor
        parent: dungeon.room
        anchors.fill: parent
        z: -10
        Rectangle { anchors.fill: parent; color: "#15130f" }
        Repeater {
            model: dungeon.cols * dungeon.rows
            Rectangle {
                readonly property int cx: index % dungeon.cols
                readonly property int cy: Math.floor(index / dungeon.cols)
                readonly property bool wall: dungeon.isWall(cx, cy)
                readonly property real s: dungeon.cellSize * dungeon.pixelPerUnit
                x: cx * s
                y: parent.height - (cy + 1) * s
                width: s
                height: s
                color: wall ? "#58524b"
                            : ((cx + cy) % 2 === 0 ? "#37332e" : "#34302b")
                border.width: wall ? 0 : 1
                border.color: "#2b2824"
                Rectangle {
                    visible: parent.wall && !dungeon.isWall(parent.cx, parent.cy - 1)
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * 0.25
                    color: "#3f3a34"
                }
            }
        }
        Repeater {
            model: dungeon.torches
            Rectangle {
                readonly property real ppu: dungeon.pixelPerUnit
                width: 0.5 * ppu
                height: 0.5 * ppu
                radius: width / 2
                x: modelData.x * ppu - width / 2
                y: parent.height - modelData.y * ppu - height / 2
                color: modelData.color
                border.color: "#fff2c0"
                border.width: 2
            }
        }
    }

    Item {
        id: _walker
        parent: dungeon.room
        z: 10
        readonly property point p: dungeon.pathPoint(dungeon.walkT)
        property real xWu: p.x
        property real yWu: p.y
        readonly property real ppu: dungeon.pixelPerUnit
        width: 1.2 * ppu
        height: width
        x: xWu * ppu - width / 2
        y: parent.height - yWu * ppu - height / 2
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "#4a90a4"
            border.color: "#d8f0ff"
            border.width: 2
        }
    }
}
