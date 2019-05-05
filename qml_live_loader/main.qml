import QtQuick 2.12
import QtQuick.Window 2.12
//import "qrc:/" as Live

Window {
    visible: true
    width: 400
    height: 400
    title: qsTr("Live Qml Coding Sandbox")
    flags: Qt.WindowStaysOnTopHint

    LiveLoader {
        id: theLiveLoader
        anchors.fill: parent
        observed: "Sandbox.qml"
    }
}
