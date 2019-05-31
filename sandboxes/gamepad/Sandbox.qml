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
        //Component.onCompleted: forceActiveFocus();
        focus: true
        showDebugOverlay: true
        anchors.fill: parent
    }

}
