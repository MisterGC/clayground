// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    visibility: Window.Maximized
    visible: true
    title: qsTr("Live Plugin Loading")
    Sandbox { anchors.fill: parent }
}
