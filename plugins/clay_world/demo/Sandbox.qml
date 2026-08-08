// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Item {
    id: _sbx
    anchors.fill: parent

    readonly property var demos: [
        {"title": "3D Primitives", "comp": _sbx3d},
        {"title": "3D Scene (SVG areas)", "comp": _sbx3dScene},
        {"title": "2D World", "comp": _sbx2d}
    ]
    property int demoIndex: 0

    Loader {
        anchors.fill: parent
        sourceComponent: _sbx.demos[_sbx.demoIndex].comp
    }

    Component {
        id: _sbx2d
        Sandbox2d {}
    }
    Component {
        id: _sbx3d
        Sandbox3d {}
    }
    Component {
        id: _sbx3dScene
        Sandbox3dScene {}
    }

    Button {
        text: _sbx.demos[(_sbx.demoIndex + 1) % _sbx.demos.length].title
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        onClicked: _sbx.demoIndex = (_sbx.demoIndex + 1) % _sbx.demos.length
    }
}
