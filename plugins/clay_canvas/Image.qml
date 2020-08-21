// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0

Image {
    property ClayCanvas canvas: null
    parent: canvas.coordSys
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 0
    property real heightWu: 0

    x: canvas.xToScreen(xWu)
    y: canvas.yToScreen(yWu)
    width: sourceSize.width
    height: sourceSize.height
    sourceSize.width: widthWu * canvas.pixelPerUnit
    sourceSize.height: heightWu * canvas.pixelPerUnit
}
