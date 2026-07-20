// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief LineBatch3D style gallery: dots, chevrons, flow, glow, pulse, arrows
// @tags 3D, Canvas3D, Lines, Styles
// @category Plugin Demos
//
// Living reference and verification page for the LineBatch3D style extensions.
// Each row is one styleId; the labels on the left name the style. Standalone:
//   clayliveloader --sbx LineStylesShowcase.qml
// Drive the animation clock with the Flow toggle, or set root.flowTime via the
// inspector for deterministic, frame-exact snapshots.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent

    // Shared animation clock. Kept off self-ticking so snapshots are
    // deterministic; the Flow switch or an inspector eval advances it.
    property real flowTime: 0
    property bool playing: false

    // One entry per showcase row (top to bottom). style is the LineBatch3D
    // style dict; label documents it. Row i uses styleId i.
    readonly property var rows: [
        { label: "solid (legacy)",       color: "#00d9ff", style: { dash: [0, 0], capRound: true, opacity: 1.0 } },
        { label: "dashed (legacy)",      color: "#eaeaea", style: { dash: [40, 30], capRound: false, opacity: 1.0 } },
        { label: "dots (round)",         color: "#00d9ff", style: { dash: [12, 44], pattern: "dot" } },
        { label: "dots (screen units)",  color: "#0f9d9a", style: { dash: [26, 26], pattern: "dot", patternUnits: "screen" } },
        { label: "chevrons",             color: "#ffd93d", style: { dash: [22, 44], pattern: "chevron" } },
        { label: "chevrons + flow",      color: "#ffd93d", style: { dash: [22, 44], pattern: "chevron", flow: 70 } },
        { label: "dashed + flow",        color: "#ff3366", style: { dash: [40, 30], pattern: "dash", flow: 90 } },
        { label: "glow (soft edge)",     color: "#ff3366", style: { dash: [0, 0], glow: 0.85 } },
        { label: "glow dots",            color: "#00d9ff", style: { dash: [10, 55], pattern: "dot", glow: 0.7 } },
        { label: "pulse",                color: "#ffd93d", style: { dash: [0, 0], pulse: 0.9 } },
        { label: "arrow head (P2)",      color: "#0f9d9a", style: { dash: [0, 0], glow: 0.3, head: [3.0, 2.5] } }
    ]

    readonly property real rowGap: 105
    readonly property real lineX: 620
    readonly property real lineWidth: 20
    // Mirrors the View3D height so the 2D labels can map world y to screen y
    // without reaching into a nested component scope.
    property real viewH: 0

    function rowY(i) { return (root.rows.length - 1) * 0.5 * root.rowGap - i * root.rowGap }

    function buildLines() {
        var arr = []
        for (var i = 0; i < root.rows.length; ++i) {
            var y = root.rowY(i)
            arr.push({
                points: [Qt.vector3d(-root.lineX, y, 0), Qt.vector3d(root.lineX, y, 0)],
                color: root.rows[i].color,
                width: root.lineWidth,
                styleId: i
            })
        }
        return arr
    }

    function stylesList() {
        var arr = []
        for (var i = 0; i < root.rows.length; ++i)
            arr.push(root.rows[i].style)
        return arr
    }

    // Inspector helpers.
    function flagInfo() {
        return {
            flowTime: root.flowTime,
            playing: root.playing,
            rows: root.rows.length,
            pathLength0: batch.pathLength(0),
            midOfRow0: batch.positionAt(0, batch.pathLength(0) * 0.5)
        }
    }

    FrameAnimation {
        running: root.playing
        onTriggered: root.flowTime = elapsedTime
    }

    View3D {
        id: view3D
        anchors.fill: parent
        camera: cam
        onHeightChanged: root.viewH = height

        environment: SceneEnvironment {
            clearColor: "#12121c"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: cam
            position: Qt.vector3d(0, 0, 1650)
            clipFar: 12000
        }

        DirectionalLight {
            eulerRotation.x: -35
        }

        LineBatch3D {
            id: batch
            viewportSize: Qt.vector2d(view3D.width, view3D.height)
            widthUnits: LineBatch3D.World
            flowTime: root.flowTime
            styles: root.stylesList()
            Component.onCompleted: lines = root.buildLines()
        }
    }

    // Row labels, aligned to the 3D rows via the same rowY() mapping. The
    // View3D is near-orthographic head-on, so a linear pixel mapping matches.
    Item {
        anchors.fill: parent
        Repeater {
            model: root.rows
            Text {
                required property int index
                required property var modelData
                // World y -> screen y: origin at view centre, world +y is up.
                // Divisor is the visible world height at the camera distance
                // (2 * z * tan(fovV/2), fovV = 60 deg default).
                readonly property real worldToPx: root.viewH / 1905.0
                x: 24
                y: root.viewH * 0.5 - root.rowY(index) * worldToPx - height * 0.5
                text: index + "  " + modelData.label
                color: modelData.color
                font.family: root.monoFont
                font.pixelSize: 14
            }
        }
    }

    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Control panel.
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        width: panelCol.implicitWidth + 24
        height: panelCol.implicitHeight + 24
        radius: 8
        color: "#cc16213e"
        border.color: "#0f9d9a"
        border.width: 1

        Column {
            id: panelCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "LineBatch3D styles"
                color: "#00d9ff"
                font.pixelSize: 15
                font.bold: true
                font.family: root.monoFont
            }

            Row {
                spacing: 8
                Switch {
                    id: flowSwitch
                    checked: false
                    onCheckedChanged: root.playing = checked
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Flow (flowTime = " + root.flowTime.toFixed(1) + ")"
                    color: "#eaeaea"
                    font.pixelSize: 12
                    font.family: root.monoFont
                }
            }
        }
    }
}
