// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick.Controls

Item {
    anchors.fill: parent

    property bool is3D: true

    Loader {
        anchors.fill: parent
        sourceComponent: is3D ? _sbx3d : _sbx2d
    }

    Component {
        id: _sbx2d
        Sandbox2d {}
    }
    Component {
        id: _sbx3d
        Sandbox3d {}
    }

    Button {
        text: is3D ? "Switch to 2D" : "Switch to 3D"
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        onClicked: is3D = !is3D
    }
}
