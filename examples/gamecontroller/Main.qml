// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visible: true
    visibility: Window.Maximized
    title: qsTr("GameController")
    color: "#1a1a2e"
    // Clear of a phone's notch and home indicator
    Sandbox {
        anchors.fill: parent
        anchors.leftMargin: parent.SafeArea.margins.left
        anchors.rightMargin: parent.SafeArea.margins.right
        anchors.topMargin: parent.SafeArea.margins.top
        anchors.bottomMargin: parent.SafeArea.margins.bottom
    }
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}
