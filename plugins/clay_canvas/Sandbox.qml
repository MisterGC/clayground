// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Canvas 1.0

ClayCanvas
{
    id: theCanvas

    anchors.fill: parent
    pixelPerUnit: 50
    worldXMin: 0; worldXMax: 10
    worldYMin: 0; worldYMax: 10

    keyBoardNavigationEnabled: true

    Component { id: geoFactory; Poly {canvas: theCanvas}}
    Component { id: txtFactory; Text {canvas: theCanvas; fontSizeWu:.25}}
    Component { id: imgFactory; Image{canvas: theCanvas; source: "image.svg"}}

    Component.onCompleted: {
        let line = [{x:3, y:3}, {x:5, y:5}]
        geoFactory.createObject(theCanvas, {vertices: line})

        let triangle = [{x:6, y:6}, {x:7, y:6}, {x: 6.5, y:7}, {x:6, y:6}]
        geoFactory.createObject(theCanvas, {vertices: triangle, fillColor:"orange"})

        let txt = "A triangle"
        txtFactory.createObject(theCanvas, {xWu:5.9, yWu:5.9, text:txt})

        imgFactory.createObject(theCanvas, {xWu:1.0, yWu:8.0, widthWu: 2.5, heightWu: 2.5})
    }
}
