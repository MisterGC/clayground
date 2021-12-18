// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick as Quick

Quick.Text {
    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null
    property real xWu: 0
    property real yWu: 0
    property real fontSizeWu: 10

    x: canvas ? canvas.xToScreen(xWu) : 0
    y: canvas ? canvas.yToScreen(yWu) : 0
    font.pixelSize: fontSizeWu * canvas ? canvas.pixelPerUnit : 0
}
