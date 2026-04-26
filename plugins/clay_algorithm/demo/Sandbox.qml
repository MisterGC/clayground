// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Algorithm

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property int cols: 30
    property int rows: 20
    property var grid: []
    property int startX: 1
    property int startY: 1
    property int endX: cols - 2
    property int endY: rows - 2
    property var path: []
    property string clickMode: "wall" // "wall", "start", "end"

    GridPathfinder {
        id: pathfinder
        columns: root.cols
        rows: root.rows
        diagonal: true
    }

    Component.onCompleted: resetGrid()

    function resetGrid() {
        let g = new Array(cols * rows).fill(0);
        // Border walls
        for (let x = 0; x < cols; ++x) {
            g[x] = 1;
            g[(rows - 1) * cols + x] = 1;
        }
        for (let y = 0; y < rows; ++y) {
            g[y * cols] = 1;
            g[y * cols + cols - 1] = 1;
        }
        // Random interior walls (~20%)
        for (let y = 1; y < rows - 1; ++y) {
            for (let x = 1; x < cols - 1; ++x) {
                if ((x === startX && y === startY) ||
                    (x === endX && y === endY)) continue;
                if (Math.random() < 0.2) g[y * cols + x] = 1;
            }
        }
        grid = g;
        pathfinder.walkableData = g;
        recalcPath();
    }

    function recalcPath() {
        path = pathfinder.findPath(startX, startY, endX, endY);
    }

    function isPath(x, y) {
        for (let i = 0; i < path.length; ++i)
            if (path[i].x === x && path[i].y === y) return true;
        return false;
    }

    // Header
    Row {
        id: header
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 4
        spacing: 8
        z: 10

        Button {
            text: "Reset"
            onClicked: resetGrid()
            palette.buttonText: "#e0e0e0"
            palette.button: "#333355"
        }
        Button {
            text: "Set Start"
            highlighted: clickMode === "start"
            onClicked: clickMode = "start"
            palette.buttonText: "#e0e0e0"
            palette.button: clickMode === "start" ? "#00d9ff" : "#333355"
        }
        Button {
            text: "Set End"
            highlighted: clickMode === "end"
            onClicked: clickMode = "end"
            palette.buttonText: "#e0e0e0"
            palette.button: clickMode === "end" ? "#ff3366" : "#333355"
        }
        Button {
            text: "Toggle Walls"
            highlighted: clickMode === "wall"
            onClicked: clickMode = "wall"
            palette.buttonText: "#e0e0e0"
            palette.button: clickMode === "wall" ? "#ffd93d" : "#333355"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: path.length > 0 ? "Path: " + path.length + " steps" : "No path found"
            color: path.length > 0 ? "#00d9ff" : "#ff3366"
            font.bold: true
            font.pixelSize: 14
        }
    }

    // Grid
    Item {
        id: gridArea
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8

        property real cellW: width / cols
        property real cellH: height / rows

        Repeater {
            model: root.cols * root.rows
            Rectangle {
                required property int index
                property int cellX: index % root.cols
                property int cellY: Math.floor(index / root.cols)
                property bool isWall: root.grid.length > index && root.grid[index] !== 0
                property bool isStart: cellX === root.startX && cellY === root.startY
                property bool isEnd: cellX === root.endX && cellY === root.endY
                property bool onPath: !isWall && !isStart && !isEnd && root.isPath(cellX, cellY)

                x: cellX * gridArea.cellW
                y: cellY * gridArea.cellH
                width: gridArea.cellW - 1
                height: gridArea.cellH - 1

                color: {
                    if (isStart) return "#00d9ff";
                    if (isEnd) return "#ff3366";
                    if (isWall) return "#333355";
                    if (onPath) return "#0f9d9a";
                    return "#16213e";
                }
                radius: (isStart || isEnd) ? width * 0.3 : 2

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.clickMode === "start") {
                            if (!isWall) {
                                root.startX = cellX;
                                root.startY = cellY;
                                root.recalcPath();
                            }
                        } else if (root.clickMode === "end") {
                            if (!isWall) {
                                root.endX = cellX;
                                root.endY = cellY;
                                root.recalcPath();
                            }
                        } else {
                            if (isStart || isEnd) return;
                            let g = Array.from(root.grid);
                            g[index] = g[index] === 0 ? 1 : 0;
                            root.grid = g;
                            pathfinder.setWalkable(cellX, cellY, g[index] === 0);
                            root.recalcPath();
                        }
                    }
                }
            }
        }
    }
}
