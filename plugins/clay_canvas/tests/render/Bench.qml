// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// One item, one pen, one progress - the picture the issue asks for (#272):
//
//   clayrender plugins/clay_canvas/tests/render/Bench.qml --out poly-chalk.png \
//       --set which=poly --set look=chalk --set progress=0.5 --size 600x400
//
// `which` is poly | connector | text | axes, `look` is none | chalk | marker.
// Chalk goes on a slate, the other pens on paper, so each look is seen on
// the surface it is for.

import QtQuick
import Clayground.Canvas as Canv

Rectangle {
    id: root
    anchors.fill: parent

    property string which: "poly"
    property string look: "chalk"
    property real progress: 0.5

    readonly property bool slate: look === "chalk"
    color: slate ? "#2e3d37" : "#f4f1e8"
    readonly property color ink: slate ? "#f1efe6" : "#1f2a44"
    readonly property color accent: slate ? "#ffd93d" : "#c0392b"

    Canv.ClayCanvas {
        id: canvas
        anchors.fill: parent
        interactive: false
        worldXMin: 0; worldXMax: 12
        worldYMin: 0; worldYMax: 8
        // The window gets its size after the scene has loaded, so a fit at
        // completion would frame a canvas of no size.
        onWidthChanged: fit(0, 0, 12, 8)
        onHeightChanged: fit(0, 0, 12, 8)

        Canv.Poly {
            id: poly
            objectName: "poly"
            visible: root.which === "poly"
            canvas: canvas
            vertices: [{x: 1.5, y: 2}, {x: 4, y: 6}, {x: 6.5, y: 2.5}, {x: 9, y: 6}, {x: 10.5, y: 2}]
            strokeColor: root.ink
            strokeWidth: 4
            sketch: root.look
            progress: root.progress
        }

        Canv.Rectangle {
            id: boxA
            objectName: "boxA"
            visible: root.which === "connector"
            canvas: canvas
            xWu: 1; yWu: 6; widthWu: 3; heightWu: 2
            color: "transparent"
            border.color: root.accent
            border.width: 2
        }
        Canv.Rectangle {
            id: boxB
            objectName: "boxB"
            visible: root.which === "connector"
            canvas: canvas
            xWu: 8; yWu: 3.5; widthWu: 3; heightWu: 2
            color: "transparent"
            border.color: root.accent
            border.width: 2
        }
        Canv.Connector {
            id: connector
            objectName: "connector"
            visible: root.which === "connector"
            canvas: canvas
            from: boxA
            to: boxB
            attach: "edge"
            arrow: "both"
            color: root.ink
            strokeWidth: 4
            sketch: root.look
            progress: root.progress
        }

        Canv.Text {
            id: text
            objectName: "text"
            visible: root.which === "text"
            canvas: canvas
            xWu: 0.8; yWu: 5
            fontSizeWu: 1.1
            text: "the base opens the gate"
            color: root.ink
            sketch: root.look
            progress: root.progress
        }

        Canv.Axes {
            id: axes
            objectName: "axes"
            visible: root.which === "axes"
            canvas: canvas
            xWu: 1.5; yWu: 1.5
            widthWu: 9; heightWu: 5.5
            xLabel: "Ib"; yLabel: "Ic"
            fontSizeWu: 0.8
            series: [{x: 1.5, y: 1.5}, {x: 4.5, y: 5.5}, {x: 10, y: 5.5}]
            strokeColor: root.ink
            strokeWidth: 4
            seriesColor: root.accent
            sketch: root.look
            progress: root.progress
        }
    }
}
