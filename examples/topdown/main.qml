// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visible: true
    visibility: Window.Maximized
    title: qsTr("TopDown")
    Sandbox { anchors.centerIn: parent }
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}
