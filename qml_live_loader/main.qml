import QtQuick 2.12
import QtQuick.Window 2.12
import LiveLoading 1.0

Window {
    visible: true
    width: 480
    height: 480
    title: qsTr("Hello World")
    flags: Qt.WindowStaysOnTopHint

    LiveLoader {
        id: theLiveLoader
        anchors.fill: parent
        observed: "Sandbox.qml"
    }
}
