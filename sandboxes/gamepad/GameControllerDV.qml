import QtQuick 2.0

Rectangle {
    id: theDebugVisu

    opacity: .75
    color: "grey"
    anchors.centerIn: parent
    width: parent.width * .5
    height: .5 * width
    border.width: .1 * height
    border.color: "lightgrey"
    radius: height * .08
    property var observed: null

    Text {
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: parent.height * .12
        anchors.horizontalCenter: parent.horizontalCenter
        font.bold: true
        font.pixelSize: parent.height * .09
        text: "Source: " + (observed.keyboardSelected ?
                                "Keyboard" :
                                "Gamepad (" + observed.gamePadId + ")")
    }

    Rectangle {
        id: down
        x: .3 * parent.height
        y: .6 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisY < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: up
        x: .3 * parent.height
        y: .3 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisY > 0.3 ? "red" : "black"
    }
    Rectangle {
        id: left
        x: .15 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisX < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: right
        x: .45 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisX > 0.3 ? "red" : "black"
    }

    Rectangle {
        id: btnB
        x: .65 * parent.width
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        radius: width * .5
        color: observed.buttonBPressed ? "red" : "darkred"
        Text {
            font.pixelSize: parent.height * .35
            anchors.top: parent.bottom
            anchors.right: parent.right
            text: "B"
            font.bold: true
            color: "darkred"
        }
    }
    Rectangle {
        id: btnA
        x: .8 * parent.width
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        radius: width * .5
        color: observed.buttonAPressed ? "red" : "darkred"
        Text {
            font.pixelSize: parent.height * .35
            anchors.top: parent.bottom
            anchors.right: parent.right
            text: "A"
            font.bold: true
            color: "darkred"
        }
    }
}
