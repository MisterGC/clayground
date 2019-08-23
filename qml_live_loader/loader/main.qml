import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    width: 400
    height: 400
    title: qsTr("Live Qml Coding Sandbox")
    flags: Qt.WindowStaysOnTopHint
    Loader {
        source: "file:" + ClayLiveLoader.sandboxFile
        anchors.fill: parent
    }
}
