// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief 2D shapes, images, connectors and polygons
// @tags 2D, Canvas, Shapes
// @category Plugin Demos

import QtQuick
import QtQuick.Shapes
import Clayground.Canvas as Canv

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color cyan: "#00d9ff"
    property color teal: "#0f9d9a"
    property color pink: "#ff3366"
    property color gold: "#ffd93d"
    property color dimText: "#8a8a8a"
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
        color: root.cyan
        z: 1
    }

    Text {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        text: "Use arrow keys to navigate!"
        font.family: root.monoFont
        font.pixelSize: 11
        color: root.dimText
        z: 1
    }

    Canv.ClayCanvas {
        id: theCanvas
        anchors.fill: parent
        anchors.topMargin: 35
        pixelPerUnit: 50
        worldXMin: 0; worldXMax: 14
        worldYMin: 0; worldYMax: 10
        keyBoardNavigationEnabled: true

        // Factories for dynamic creation
        Component { id: polyFactory; Canv.Poly { canvas: theCanvas } }
        Component { id: txtFactory; Canv.Text { canvas: theCanvas; fontSizeWu: .3 } }
        Component { id: imgFactory; Canv.Image { canvas: theCanvas; source: "image.svg" } }
        Component { id: rectFactory; Canv.Rectangle { canvas: theCanvas } }
        Component { id: connFactory; Canv.Connector { } }

        Component.onCompleted: {
            // --- Left: Polygons showcase ---

            // Star polygon (gold, filled)
            let star = [];
            for (let i = 0; i < 10; i++) {
                let angle = (i * 36 - 90) * Math.PI / 180;
                let r = i % 2 === 0 ? 1.2 : 0.5;
                star.push({x: 2.5 + r * Math.cos(angle), y: 7.5 + r * Math.sin(angle)});
            }
            star.push(star[0]);
            polyFactory.createObject(theCanvas, {
                vertices: star, fillColor: root.gold, strokeColor: root.pink
            });
            txtFactory.createObject(theCanvas, {
                xWu: 1.6, yWu: 6.0, text: "Star", color: root.gold
            });

            // Triangle (pink, filled)
            let tri = [{x:0.5, y:3.5}, {x:2.5, y:3.5}, {x:1.5, y:5.0}, {x:0.5, y:3.5}];
            polyFactory.createObject(theCanvas, {
                vertices: tri, fillColor: root.pink, strokeColor: root.pink
            });
            txtFactory.createObject(theCanvas, {
                xWu: 0.7, yWu: 3.1, text: "Triangle", color: root.pink
            });

            // Dashed zigzag path (cyan)
            let zigzag = [];
            for (let i = 0; i < 6; i++)
                zigzag.push({x: 0.5 + i * 0.8, y: i % 2 === 0 ? 1.5 : 2.2});
            polyFactory.createObject(theCanvas, {
                vertices: zigzag,
                strokeColor: root.cyan,
                strokeWidth: 2,
                strokeStyle: ShapePath.DashLine
            });
            txtFactory.createObject(theCanvas, {
                xWu: 0.5, yWu: 1.0, text: "Dashed path", color: root.cyan
            });

            // --- Center: Rectangles & connectors ---

            // Connected graph
            txtFactory.createObject(theCanvas, {
                xWu: 5.5, yWu: 9.5, text: "Connected graph",
                color: root.dimText, fontSizeWu: 0.3
            });

            let r1 = rectFactory.createObject(theCanvas, {
                xWu: 5.5, yWu: 8.5, widthWu: 2.0, heightWu: 1.2,
                color: root.teal, radius: 4
            });

            let r2 = rectFactory.createObject(theCanvas, {
                xWu: 5.5, yWu: 5.5, widthWu: 2.0, heightWu: 1.2,
                color: root.cyan, radius: 4
            });

            let r3 = rectFactory.createObject(theCanvas, {
                xWu: 9.0, yWu: 7.0, widthWu: 2.0, heightWu: 1.2,
                color: root.pink, radius: 4
            });

            // Connectors between nodes
            connFactory.createObject(theCanvas, {
                from: r1, to: r2, color: root.dimText, strokeWidth: 2
            });
            connFactory.createObject(theCanvas, {
                from: r1, to: r3, color: root.dimText, strokeWidth: 2
            });
            connFactory.createObject(theCanvas, {
                from: r2, to: r3, color: root.dimText,
                strokeWidth: 2, style: ShapePath.DashLine
            });

            // --- Center-bottom: small accent rectangles ---
            rectFactory.createObject(theCanvas, {
                xWu: 6.0, yWu: 3.0, widthWu: 0.6, heightWu: 0.6, color: root.gold
            });
            rectFactory.createObject(theCanvas, {
                xWu: 7.0, yWu: 3.0, widthWu: 0.6, heightWu: 0.6, color: root.pink
            });
            rectFactory.createObject(theCanvas, {
                xWu: 8.0, yWu: 3.0, widthWu: 0.6, heightWu: 0.6, color: root.cyan
            });
            rectFactory.createObject(theCanvas, {
                xWu: 9.0, yWu: 3.0, widthWu: 0.6, heightWu: 0.6, color: root.teal
            });
            txtFactory.createObject(theCanvas, {
                xWu: 5.8, yWu: 2.3, text: "Color palette", color: root.dimText
            });

            // --- Right column: Image, hexagon, diamond ---

            // Image
            imgFactory.createObject(theCanvas, {
                xWu: 11.2, yWu: 9.0, widthWu: 2.0, heightWu: 2.0
            });
            txtFactory.createObject(theCanvas, {
                xWu: 11.7, yWu: 6.7, text: "Image", color: root.dimText
            });

            // Hexagon outline (teal, no fill)
            let hex = [];
            for (let i = 0; i < 6; i++) {
                let a = (i * 60 - 30) * Math.PI / 180;
                hex.push({x: 12.2 + 1.0 * Math.cos(a), y: 5.0 + 1.0 * Math.sin(a)});
            }
            hex.push(hex[0]);
            polyFactory.createObject(theCanvas, {
                vertices: hex, strokeColor: root.teal, strokeWidth: 2
            });
            txtFactory.createObject(theCanvas, {
                xWu: 11.6, yWu: 3.7, text: "Hexagon", color: root.teal
            });

            // Diamond (cyan outline)
            let diamond = [
                {x:12.2, y:2.8}, {x:13.0, y:2.0},
                {x:12.2, y:1.2}, {x:11.4, y:2.0}, {x:12.2, y:2.8}
            ];
            polyFactory.createObject(theCanvas, {
                vertices: diamond, strokeColor: root.cyan, strokeWidth: 2
            });
        }
    }
}
