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
        showDebugOverlay: true
        anchors.fill: parent
        onAxisXChanged: console.log("New X: " + axisX)
        onAxisYChanged: console.log("New Y: " + axisY)
    }

}
