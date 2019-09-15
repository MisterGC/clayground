import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5

Window {
    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .35
    width: Screen.desktopAvailableWidth * .32
    height: width
    title: qsTr("Clay Live Loader")

    Loader {
        id: sbxLoader
        anchors.fill: parent
        property bool available: ClayLiveLoader.sandboxFile.length >
                                 ClayLiveLoader.sandboxDir.length
        source: available ? "file:" + ClayLiveLoader.sandboxFile : ""
    }

    Rectangle {
       id: messageShow
       anchors.fill: parent
       color: "black"
       visible: !sbxLoader.available
       ScrollView {
           anchors.centerIn: parent
           width: parent.width * .95
           TextArea {
               enabled: false
               textFormat: TextEdit.RichText
               wrapMode: Text.Wrap
               horizontalAlignment:Text.AlignHCenter
               color: "white"
               text: ClayLiveLoader.altMessage
               font.pixelSize: messageShow.height * .04
               font.family: "Monospace"
           }
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
