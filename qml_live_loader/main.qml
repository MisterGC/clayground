import QtQuick 2.12
import QtQuick.Window 2.12
import LiveLoading 1.0

Window {
    visible: true
    width: 1200
    height: 800
    title: qsTr("Live Qml Coding Sandbox")
    flags: Qt.WindowStaysOnTopHint

    LiveLoader {
        id: theLiveLoader
        anchors.fill: parent
        observed: "Sandbox.qml"
    }
}
