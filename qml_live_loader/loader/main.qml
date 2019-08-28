import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .35
    width: Screen.desktopAvailableWidth * .32
    height: width
    title: qsTr("Live Qml Coding Sandbox")
    flags: Qt.WindowStaysOnTopHint
    Loader {
        width: parent.width
        height: width
        source: "file:" + ClayLiveLoader.sandboxFile
    }

    KeyValueStorage { id: keyvalues; name: "clayrtdb" }
    Connections {
        target: ClayLiveLoader
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
        }
    }
}
