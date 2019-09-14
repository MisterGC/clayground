import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .35
    width: Screen.desktopAvailableWidth * .32
    height: width
    title: qsTr("Clay Live Loader")
    Loader {
        width: parent.width
        height: width
        property bool available: ClayLiveLoader.sandboxFile.length >
                                 ClayLiveLoader.sandboxDir.length
        source: available ? "file:" + ClayLiveLoader.sandboxFile : ""
        onSourceChanged: {
            if (source.length > 0)
                item.forceActiveFocus();
        }
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
