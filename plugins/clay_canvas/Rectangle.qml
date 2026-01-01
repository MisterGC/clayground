// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Rectangle
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick::Rectangle
    \brief A rectangle positioned and sized in world units.

    Rectangle extends Qt Quick's Rectangle to work with ClayCanvas world coordinates.
    Position and size are specified in world units, automatically transformed to screen coordinates.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Rectangle {
        canvas: myCanvas
        xWu: 5; yWu: 3
        widthWu: 2; heightWu: 1
        color: "red"
    }
    \endqml

    \qmlproperty ClayCanvas Rectangle::canvas
    \brief The parent canvas for coordinate transformation. Required.

    \qmlproperty real Rectangle::xWu
    \brief X position in world units.

    \qmlproperty real Rectangle::yWu
    \brief Y position in world units.

    \qmlproperty real Rectangle::widthWu
    \brief Width in world units.

    \qmlproperty real Rectangle::heightWu
    \brief Height in world units.
*/
import QtQuick as Quick

Quick.Rectangle {
    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null
    property real xWu: 0
    property real yWu: 0
    property real widthWu: 0
    property real heightWu: 0

    x: canvas ? canvas.xToScreen(xWu) : 0
    y: canvas ? canvas.yToScreen(yWu) : 0
    width: widthWu * (canvas ? canvas.pixelPerUnit : 0)
    height: heightWu * (canvas ? canvas.pixelPerUnit : 0)
}
