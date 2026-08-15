// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "black"
    opacity: 0.85
    // NOT `visible: false`. MainWindow shows and hides the WIDGET; leaving the
    // root item invisible meant the scene graph rendered nothing at all, so
    // all that reached the screen was the widget's opaque clear colour - the
    // white wipe. Visibility belongs to one owner, and that owner is
    // MainWindow.

    property var sandboxes: ClayLiveLoader ? ClayLiveLoader.sandboxes : []

    // Click to dismiss. Routed through MainWindow rather than hiding the item
    // here, so its idea of whether the guide is up stays true.
    signal closeRequested()

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
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

        ShortcutDescr {
            keys: "Ctrl+F"
            descr: "Show/Hide annotation surface"
        }

        ShortcutDescr {
            keys: "Tab"
            descr: "Fold the annotation panel away (surface only)"
        }

        ShortcutDescr {
            keys: "Ctrl+Shift+F"
            descr: "Clear annotations marked addressed"
        }

        ShortcutDescr {
            keys: "Ctrl+T"
            descr: "Toggle trace recording"
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