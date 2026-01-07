// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Image
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick::Image
    \brief An image positioned and sized in world units.

    Image extends Qt Quick's Image to work with ClayCanvas world coordinates.
    Position and size are specified in world units, with the image scaled to fit.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Image {
        canvas: myCanvas
        xWu: -5; yWu: 5
        widthWu: 3; heightWu: 3
        source: "player.png"
    }
    \endqml

    \qmlproperty ClayCanvas Image::canvas
    \brief The parent canvas for coordinate transformation. Required.

    \qmlproperty real Image::xWu
    \brief X position in world units.

    \qmlproperty real Image::yWu
    \brief Y position in world units.

    \qmlproperty real Image::widthWu
    \brief Width in world units.

    \qmlproperty real Image::heightWu
    \brief Height in world units.
*/
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
