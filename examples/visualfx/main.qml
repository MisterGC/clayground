// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visibility: Window.Maximized
    visible: true
    title: qsTr("Particle")
    Sandbox { anchors.fill: parent }
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}
