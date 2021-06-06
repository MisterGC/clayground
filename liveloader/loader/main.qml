// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5
import Clayground.Common 1.0
import Clayground.Storage 1.0

Window {
    visible: true
    x: keyvalues.get("x",Screen.desktopAvailableWidth * .01)
    y: keyvalues.get("y",Screen.desktopAvailableHeight * .35)
    width: keyvalues.get("width",Screen.desktopAvailableWidth * .32)
    height: keyvalues.get("height",width)
    title: qsTr("Clay Live Loader")

    onXChanged: keyvalues.set("x",x)
    onYChanged: keyvalues.set("y",y)
    onWidthChanged: keyvalues.set("width",width)
    onHeightChanged: keyvalues.set("height",height)

    MessageView {
        id: claylog
        Component.onCompleted: Clayground.watchView = claylog;
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
        function onRestarted() {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
            claylog.clear();
        }
        function onMessagePosted(message) { claylog.add(message); }
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

    function initRestart(sbxIdx){ keyvalues.set("command", "restart " + sbxIdx); }

    Shortcut {
       sequence: "r"
       onActivated: initRestart(-1)
    }

    Shortcut { sequence: "Ctrl+1"; onActivated: initRestart(1) }
    Shortcut { sequence: "Ctrl+2"; onActivated: initRestart(2) }
    Shortcut { sequence: "Ctrl+3"; onActivated: initRestart(3) }
    Shortcut { sequence: "Ctrl+4"; onActivated: initRestart(4) }
    Shortcut { sequence: "Ctrl+5"; onActivated: initRestart(5) }

    Shortcut {
       sequence: "l"
       onActivated: claylog.toggle();
    }
}
