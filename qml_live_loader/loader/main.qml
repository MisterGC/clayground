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

    KeyValueStorage { id: keyvalues; name: "keyvalues" }
    Connections {
        target: ClayLiveLoader
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
        }
    }
}
