// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.GameController

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    Keys.forwardTo: [controller1, controller2]
    Component.onCompleted: forceActiveFocus()
    focus: true

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 15
        spacing: 5

        Text {
            text: "Clayground.GameController"
            font.family: root.monoFont
            font.pixelSize: 18
            font.bold: true
            color: root.accentColor
        }

        Text {
            text: "Connected gamepads: " + controller1.numConnectedGamepads
            font.family: root.monoFont
            font.pixelSize: 13
            color: root.dimTextColor
        }

        Text {
            text: "Left: Keyboard (WASD) / Gamepad 1  |  Right: Touch / Gamepad 2"
            font.family: root.monoFont
            font.pixelSize: 11
            color: root.dimTextColor
        }
    }

    Row {
        anchors.fill: parent
        anchors.topMargin: 80

        GameController {
            id: controller1
            width: parent.width * .5
            height: parent.height
            Component.onCompleted: updateCtrl()
            onNumConnectedGamepadsChanged: updateCtrl()
            function updateCtrl() {
                if (numConnectedGamepads > 0)
                    selectGamepad(0);
                else
                    selectKeyboard(Qt.Key_Up,
                                   Qt.Key_Down,
                                   Qt.Key_Left,
                                   Qt.Key_Right,
                                   Qt.Key_M,
                                   Qt.Key_N);
            }
            showDebugOverlay: true
        }

        GameController {
            id: controller2
            width: parent.width * .5
            height: parent.height
            Component.onCompleted: updateCtrl()
            onNumConnectedGamepadsChanged: updateCtrl()
            function updateCtrl() {
                if (numConnectedGamepads > 1)
                    selectGamepad(1);
                else
                    selectTouchscreenGamepad();
            }
            showDebugOverlay: true
        }
    }
}
