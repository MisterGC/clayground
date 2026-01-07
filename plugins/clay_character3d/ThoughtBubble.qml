// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ThoughtBubble
    \inqmlmodule Clayground.Character3D
    \brief Simple text bubble for character speech or thoughts.

    ThoughtBubble displays text in a bordered rectangle, suitable for
    speech or thought indicators above characters.

    Example usage:
    \qml
    import Clayground.Character3D

    ThoughtBubble {
        text: "Hello!"
    }
    \endqml
*/
import QtQuick

Rectangle {
    width: _text.width + 4
    height: _text.height + 4
    color: "lightgrey"
    border.color: "black"
    border.width: 1
    /*! The text to display in the bubble. */
    property alias text: _text.text

    Text {
        id: _text
        font.pointSize: 3
        color: "black"
        anchors.centerIn: parent
    }
}
