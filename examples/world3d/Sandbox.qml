// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Box2D
import Clayground.Network
import Clayground.GameController

Item {
    anchors.fill: parent
    Loader {
        active: true
        anchors.fill: parent
        sourceComponent: _sbx2d
    }

    Component {
        id: _sbx2d
        Sandbox2d {}
    }
    Component {
        id: _sbx3d
        Sandbox3d {}
    }
}
