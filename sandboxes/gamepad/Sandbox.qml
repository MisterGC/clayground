import QtQuick 2.5
import QtQuick.Particles 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "black"

    Component.onCompleted: {
        ReloadTrigger.observeFile("GameController.qml");
    }

    GameController {
        id: theController
        anchors.fill: parent
        onAxisXChanged: console.log("New X: " + axisX)
        onAxisYChanged: console.log("New Y: " + axisY)
    }

    Rectangle {
    color: "grey"
    anchors.centerIn: parent
    width: parent.width * .6
    height: .5 * width
    border.width: .1 * height
    border.color: "lightgrey"

    Rectangle {
        id: up
        x: .3 * parent.height
        y: .6 * parent.height
        width: .15 * parent.height
        height: width
        color: theController.axisY > 0.3 ? "red" : "black"
    }
    Rectangle {
        id: down
        x: .3 * parent.height
        y: .3 * parent.height
        width: .15 * parent.height
        height: width
        color: theController.axisY < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: left
        x: .15 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: theController.axisX < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: right
        x: .45 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: theController.axisX > 0.3 ? "red" : "black"
    }

    Rectangle {
        id: btnB
        x: .65 * parent.width
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        radius: width * .5
        color: theController.buttonB ? "red" : "darkred"
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
        color: theController.buttonA ? "red" : "darkred"
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
}
