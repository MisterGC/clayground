// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visible: true
    visibility: Window.Maximized
    title: qsTr("Platformer")
    Sandbox { anchors.fill: parent }
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}
