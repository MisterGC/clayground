// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Clayground.Canvas as Canv

Canv.ClayCanvas
{
    id: theCanvas

    anchors.fill: parent
    pixelPerUnit: 50
    worldXMin: 0; worldXMax: 10
    worldYMin: 0; worldYMax: 10

    keyBoardNavigationEnabled: true

    Component { id: polyFactory; Canv.Poly {canvas: theCanvas}}
    Component { id: txtFactory; Canv.Text {canvas: theCanvas; fontSizeWu:.25}}
    Component { id: imgFactory; Canv.Image{canvas: theCanvas; source: "image.svg"}}
    Component { id: rectFactory; Canv.Rectangle{color: "black"; canvas: theCanvas; xWu: 5; yWu: 4; widthWu: 2; heightWu: 3}}

    Component.onCompleted: {
        let line = [{x:3, y:3}, {x:5, y:5}]
        polyFactory.createObject(theCanvas, {vertices: line})

        let triangle = [{x:6, y:6}, {x:7, y:6}, {x: 6.5, y:7}, {x:6, y:6}]
        polyFactory.createObject(theCanvas, {vertices: triangle, fillColor:"orange"})

        let txt = "A triangle"
        txtFactory.createObject(theCanvas, {xWu:5.9, yWu:5.9, text:txt})

        imgFactory.createObject(theCanvas, {xWu:1.0, yWu:8.0, widthWu: 2.5, heightWu: 2.5})

        rectFactory.createObject(theCanvas);
    }
}
