// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "black"
    opacity: 0.85
    visible: false
    
    property var sandboxes: ClayLiveLoader ? ClayLiveLoader.sandboxes : []
    
    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }
    
    Column {
        anchors.centerIn: parent
        spacing: 5
        
        Text {
            font.bold: true
            color: "#D69545"
            text: "OVERLAYS"
            font.pixelSize: 16
        }
        
        ShortcutDescr {
            keys: "Ctrl+L"
            descr: "Show/Hide log overlay"
        }
        
        ShortcutDescr {
            keys: "Ctrl+G"
            descr: "Show/Hide this guide overlay"
        }
        
        Text {
            font.bold: true
            color: "#D69545"
            text: "SANDBOXES"
            font.pixelSize: 16
            topPadding: 10
        }
        
        Repeater {
            model: sandboxes
            ShortcutDescr {
                property var segs: modelData.split('/')
                keys: "Ctrl+" + (index + 1)
                descr: segs[segs.length-2] + "/" + segs[segs.length-1]
            }
        }
    }
}