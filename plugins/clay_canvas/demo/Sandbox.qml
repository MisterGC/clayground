// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Canvas as Canv

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        text: "Clayground.Canvas"
        font.family: root.monoFont
        font.pixelSize: 16
        font.bold: true
        color: root.accentColor
        z: 1
    }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        text: "Use arrow keys to navigate"
        font.family: root.monoFont
        font.pixelSize: 11
        color: root.dimTextColor
        z: 1
    }

    Canv.ClayCanvas {
        id: theCanvas
        anchors.fill: parent
        anchors.topMargin: 35
        pixelPerUnit: 50
        worldXMin: 0; worldXMax: 10
        worldYMin: 0; worldYMax: 10
        keyBoardNavigationEnabled: true

        Component { id: polyFactory; Canv.Poly { canvas: theCanvas } }
        Component { id: txtFactory; Canv.Text { canvas: theCanvas; fontSizeWu: .25 } }
        Component { id: imgFactory; Canv.Image { canvas: theCanvas; source: "image.svg" } }
        Component { id: rectFactory; Canv.Rectangle { color: "#0f9d9a"; canvas: theCanvas; xWu: 5; yWu: 4; widthWu: 2; heightWu: 3 } }

        Component.onCompleted: {
            let line = [{x:3, y:3}, {x:5, y:5}]
            polyFactory.createObject(theCanvas, {vertices: line})

            let triangle = [{x:6, y:6}, {x:7, y:6}, {x: 6.5, y:7}, {x:6, y:6}]
            polyFactory.createObject(theCanvas, {vertices: triangle, fillColor: "#0f9d9a"})

            let txt = "A triangle"
            txtFactory.createObject(theCanvas, {xWu:5.9, yWu:5.9, text:txt})

            imgFactory.createObject(theCanvas, {xWu:1.0, yWu:8.0, widthWu: 2.5, heightWu: 2.5})

            rectFactory.createObject(theCanvas);
        }
    }
}
