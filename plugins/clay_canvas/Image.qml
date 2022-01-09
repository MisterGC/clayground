// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick as Quick

Quick.Image {
    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 0
    property real heightWu: 0

    x: canvas ? canvas.xToScreen(xWu) : 0
    y: canvas ? canvas.yToScreen(yWu) : 0
    width: sourceSize.width
    height: sourceSize.height
    sourceSize.width: widthWu * canvas ? canvas.pixelPerUnit : 0
    sourceSize.height: heightWu * canvas ? canvas.pixelPerUnit : 0
}
