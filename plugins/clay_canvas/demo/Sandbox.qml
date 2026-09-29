// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief 2D shapes, images, connectors, sketch strokes, arrows, hand text and axes
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
    property color chalk: "#f1efe6"
    property color slate: "#2e3d37"
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
        worldXMin: 0; worldXMax: 24
        worldYMin: 0; worldYMax: 10
        keyBoardNavigationEnabled: true

        // Factories for dynamic creation
        Component { id: polyFactory; Canv.Poly { canvas: theCanvas } }
        Component { id: txtFactory; Canv.Text { canvas: theCanvas; fontSizeWu: .3 } }
        Component { id: imgFactory; Canv.Image { canvas: theCanvas; source: "image.svg" } }
        Component { id: rectFactory; Canv.Rectangle { canvas: theCanvas } }
        Component { id: connFactory; Canv.Connector { canvas: theCanvas } }
        Component { id: axesFactory; Canv.Axes { canvas: theCanvas } }

        // Write, hold, wipe, write again. The two self-drawing pieces share one
        // rhythm so they can be read side by side instead of drifting apart.
        Component {
            id: writeLoopFactory
            SequentialAnimation {
                id: theLoop
                property var subject: null
                running: theLoop.subject !== null
                loops: Animation.Infinite
                NumberAnimation {
                    target: theLoop.subject; property: "progress"
                    from: 0; to: 1; duration: 3000
                }
                PauseAnimation { duration: 1200 }
                PropertyAction { target: theLoop.subject; property: "progress"; value: 0 }
            }
        }

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

            // --- Right: the board - sketch strokes, arrows, hand text, axes ---

            // The slate goes down first: everything after it is a later sibling
            // and therefore drawn on top of it, no z juggling needed.
            rectFactory.createObject(theCanvas, {
                objectName: "boardSlate",
                xWu: 14.5, yWu: 10.0, widthWu: 9.5, heightWu: 10.0,
                color: root.slate
            });

            // One zigzag, two pens: the difference is the sketch look, nothing else.
            let boardZig = function(x0, y0) {
                let pts = [];
                for (let i = 0; i < 5; i++)
                    pts.push({x: x0 + i * 0.8, y: i % 2 === 0 ? y0 : y0 + 1.4});
                return pts;
            };

            polyFactory.createObject(theCanvas, {
                objectName: "chalkPoly",
                vertices: boardZig(15.0, 7.8),
                strokeColor: root.chalk, strokeWidth: 3,
                sketch: "chalk", progress: 0.6, seed: 3
            });
            txtFactory.createObject(theCanvas, {
                objectName: "capChalk",
                xWu: 15.0, yWu: 7.5, text: "Chalk", color: root.dimText
            });

            polyFactory.createObject(theCanvas, {
                objectName: "markerPoly",
                vertices: boardZig(19.6, 7.8),
                strokeColor: root.gold, strokeWidth: 3,
                sketch: "marker", progress: 0.8, seed: 7
            });
            txtFactory.createObject(theCanvas, {
                objectName: "capMarker",
                xWu: 19.6, yWu: 7.5, text: "Marker", color: root.dimText
            });

            let bx1 = rectFactory.createObject(theCanvas, {
                objectName: "boardBoxA",
                xWu: 15.2, yWu: 6.8, widthWu: 1.6, heightWu: 0.9,
                color: root.teal, radius: 4
            });
            let bx2 = rectFactory.createObject(theCanvas, {
                objectName: "boardBoxB",
                xWu: 18.4, yWu: 6.8, widthWu: 1.6, heightWu: 0.9,
                color: root.cyan, radius: 4
            });

            // attach "edge" puts the head where the box starts; with "center" the
            // shaft would run under the box and the head would sit inside it.
            connFactory.createObject(theCanvas, {
                objectName: "boxArrow",
                canvas: theCanvas,
                from: bx1, to: bx2, color: root.cyan, strokeWidth: 3,
                arrow: "to", attach: "edge", sketch: "marker", seed: 5
            });

            // An arrow needs no items at all - two world points and the canvas.
            connFactory.createObject(theCanvas, {
                objectName: "freeArrow",
                canvas: theCanvas,
                from: {x: 21.2, y: 6.7}, to: {x: 23.4, y: 5.5},
                color: root.chalk, strokeWidth: 3,
                arrow: "both", sketch: "chalk", seed: 11
            });
            txtFactory.createObject(theCanvas, {
                objectName: "capArrows",
                xWu: 15.2, yWu: 5.5, text: "Arrows", color: root.dimText
            });

            let handText = txtFactory.createObject(theCanvas, {
                objectName: "handText",
                xWu: 15.2, yWu: 4.9, fontSizeWu: 0.55,
                text: "a board writes itself", color: root.chalk,
                sketch: "chalk"
            });
            writeLoopFactory.createObject(theCanvas, {subject: handText});
            txtFactory.createObject(theCanvas, {
                objectName: "capHandText",
                xWu: 15.2, yWu: 4.1, text: "Hand text", color: root.dimText
            });

            // The series points are world points, like Poly vertices - they are
            // placed on the board, not relative to the axes' origin.
            let boardAxes = axesFactory.createObject(theCanvas, {
                objectName: "boardAxes",
                xWu: 16.5, yWu: 0.9, widthWu: 4.5, heightWu: 2.3,
                xLabel: "Ib", yLabel: "Ic", fontSizeWu: 0.4,
                strokeColor: root.chalk, strokeWidth: 3,
                seriesColor: root.gold, seriesWidth: 3,
                series: [{x: 16.8, y: 1.05}, {x: 17.8, y: 1.4}, {x: 18.8, y: 1.95},
                         {x: 19.7, y: 2.55}, {x: 20.6, y: 3.0}],
                sketch: "chalk", seed: 2
            });
            writeLoopFactory.createObject(theCanvas, {subject: boardAxes});
            txtFactory.createObject(theCanvas, {
                objectName: "capAxes",
                xWu: 16.5, yWu: 0.6, text: "Axes", color: root.dimText
            });

            // The board doubled the world's width, so frame the whole thing -
            // in any window size the showcase and the board are both in view.
            theCanvas.fit(0, 0, 24, 10, 0.2);
        }
    }
}
