import QtQuick 2.0

Text {
    property real pixelPerUnit: 1
    property real xWu: 0
    property real yWu: 0
    property real fontSizeWu: 10

    x: xWu * pixelPerUnit
    y: parent.height - yWu * pixelPerUnit
    font.pixelSize: fontSizeWu * pixelPerUnit
}
