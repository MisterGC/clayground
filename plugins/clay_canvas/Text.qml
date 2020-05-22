// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0

Text {
    property ClayCanvas canvas: null
    parent: canvas.coordSys
    property real xWu: 0
    property real yWu: 0
    property real fontSizeWu: 10

    x: canvas.xToScreen(xWu)
    y: canvas.yToScreen(yWu)
    font.pixelSize: fontSizeWu * canvas.pixelPerUnit
}
