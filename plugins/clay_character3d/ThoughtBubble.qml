import QtQuick

Rectangle {
    width: _text.width + 4
    height: _text.height + 4
    color: "lightgrey"
    border.color: "black"
    border.width: 1
    property alias text: _text.text

    Text {
        id: _text
        font.pointSize: 3
        color: "black"
        anchors.centerIn: parent
    }
}
