// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visibility: Window.FullScreen
    visible: true
    title: qsTr("Gui")
    Sandbox { anchors.fill: parent }
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}
