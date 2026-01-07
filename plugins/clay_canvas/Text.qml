// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Text
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick::Text
    \brief Text element positioned in world units with scalable font size.

    Text extends Qt Quick's Text to work with ClayCanvas world coordinates.
    Position and font size are specified in world units.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Text {
        canvas: myCanvas
        xWu: 0; yWu: 2
        fontSizeWu: 0.5
        text: "Hello World!"
        color: "blue"
    }
    \endqml

    \qmlproperty ClayCanvas Text::canvas
    \brief The parent canvas for coordinate transformation. Required.

    \qmlproperty real Text::xWu
    \brief X position in world units.

    \qmlproperty real Text::yWu
    \brief Y position in world units.

    \qmlproperty real Text::fontSizeWu
    \brief Font size in world units.
*/
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
