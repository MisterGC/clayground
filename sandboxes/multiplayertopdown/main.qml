// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

//Game idea, finding other players before a time limit
Window {
    id: theApp
    visible: true
    visibility: Window.FullScreen
    title: qsTr("TopDown")
    Sandbox {id:sandBox}
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
}

