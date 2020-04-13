// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0

Rectangle {
    property CoordCanvas canvas: null
    parent: canvas.coordSys
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 0
    property real heightWu: 0

    x: canvas.xToScreen(xWu)
    y: canvas.yToScreen(yWu)
    width: widthWu * canvas.pixelPerUnit
    height: heightWu * canvas.pixelPerUnit
}
