import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    visibility: Window.Maximized
    title: qsTr("Gui")
    Sandbox { standaloneApp: true; anchors.centerIn: parent }
}
