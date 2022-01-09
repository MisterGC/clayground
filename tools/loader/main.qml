// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Clayground.Common
import Clayground.Storage

Window {
    id: _theWindow

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
        anchors.centerIn: parent
        width: 0.9 * parent.width
        height: 0.75 * parent.height
        z: 999
        opacity: 0
        Behavior on opacity {NumberAnimation{duration: 250}}
        function toggle() { opacity = opacity > .5 ? 0.0 : 1.0; }
    }

    Loader {
        id: sbxLoader
        anchors.fill: parent
        source: ClayLiveLoader.sandboxUrl
        onSourceChanged: showSbxSourceComp.createObject(parent)
    }

    Component {
        id: showSbxSourceComp
        Text {
            id: _lblSrc

            font.pixelSize: parent.height * .06
            font.bold: true; color: "white"; anchors.centerIn: parent
            visible: sbxLoader.source !== ""; opacity: 1.0;

            Behavior on opacity {NumberAnimation{duration: _lblSrc.ttl}}
            property int ttl: 750
            property var _sbxUrlEls: sbxLoader.source.toString().split('/')
            text: _sbxUrlEls.length > 1 ? _sbxUrlEls[_sbxUrlEls.length-2] : ""

            Component.onCompleted: opacity = 0

            Rectangle {color: "black"; anchors.centerIn: parent; z: -1;
                opacity: 0.9; height: parent.height * 1.1; width: parent.width * 1.1}
            Timer { running: true; interval: _lblSrc.ttl; onTriggered: _lblSrc.destroy() }
        }
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
            let opt = keyvalues.get("liveLoaderCtrl");
            if (opt === "toggleHelp") guideScreen.toggle();
            keyvalues.set("liveLoaderCtrl", "")
        }
    }

    // The guide screen and all (documented) shortcuts
    readonly property string _SC_USED_MOD: "Ctrl+"
    readonly property string _SC_TOGGLE_LOG: _SC_USED_MOD + "L"
    readonly property string _SC_TOGGLE_GUIDE: _SC_USED_MOD + "G"
    function _scRestartSbx(sbxIdx) {return _SC_USED_MOD + sbxIdx;}
    function _restart(sbxIdx){ keyvalues.set("command", "restart " + sbxIdx); }

    Rectangle {
       id: guideScreen
       anchors.fill: parent
       color: "black"
       Column {
           anchors.centerIn: parent
           spacing: 5
           Text {font.bold: true; color: "#D69545"; text: "OVERLAYS"}
           ShortcutDescr {keys: _SC_TOGGLE_LOG; descr: "Show/Hide log overlay"}
           ShortcutDescr {keys: _SC_TOGGLE_GUIDE; descr: "Show/Hide this guide overlay."}
           Text {font.bold: true; color: "#D69545"; text: "SANDBOXES"}
           Repeater {
               model: ClayLiveLoader.sandboxes
               ShortcutDescr {
                   property var segs: modelData.split('/')
                   keys: _scRestartSbx(index+1)
                   descr: segs[segs.length-2] + "/" + segs[segs.length-1]
               }
           }
       }
       opacity: 0
       visible: opacity > .1
       Behavior on opacity {NumberAnimation{duration: 250}}
       function toggle() { opacity = opacity > .5 ? 0.0 : .85; }
       MouseArea {anchors.fill: parent; onClicked: guideScreen.toggle();}
    }

    Shortcut {sequence: _SC_TOGGLE_LOG; onActivated: claylog.toggle(); }
    Shortcut {sequence: _SC_TOGGLE_GUIDE; onActivated: guideScreen.toggle(); }
    Shortcut {sequence: _scRestartSbx(1); onActivated: _restart(0)}
    Shortcut {sequence: _scRestartSbx(2); onActivated: _restart(1)}
    Shortcut {sequence: _scRestartSbx(3); onActivated: _restart(2)}
    Shortcut {sequence: _scRestartSbx(4); onActivated: _restart(3)}
    Shortcut {sequence: _scRestartSbx(5); onActivated: _restart(4)}
}
