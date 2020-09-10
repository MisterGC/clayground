// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5
import Clayground.Storage 1.0

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
        source: ClayLiveLoader.sandboxUrl
    }

    Rectangle {
       id: messageShow
       anchors.fill: parent
       color: "black"
       visible: !sbxLoader.source
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

    KeyValueStore { id: keyvalues; name: "clayrtdb" }
    Connections {
        target: ClayLiveLoader
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
            claylog.clear();
        }
        onMessagePosted: claylog.add(message);
    }

    Timer {
        running: true
        repeat: true
        interval: 250
        onTriggered: {
            let opt = keyvalues.get("options");
            if (opt === "log") claylog.toggle();
            keyvalues.set("options", "");
        }
    }

    MessageView {
        id: claylog
        opacity: 0
        anchors.centerIn: parent
        width: 0.9 * parent.width
        height: 0.75 * parent.height
        z: 999
        function toggle() {
           let opac = opacity > .5 ? 0.0 : 1.0;
           opacity = opac;
        }
    }

    Shortcut {
       sequence: "r"
       onActivated: keyvalues.set("command", "restart");
    }

    Shortcut {
       sequence: "l"
       onActivated: claylog.toggle();
    }
}
