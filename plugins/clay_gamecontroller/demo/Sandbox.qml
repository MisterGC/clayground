// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Keyboard, touch and gamepad input handling
// @tags Input, Gamepad, Keyboard
// @category Plugin Demos

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

    // F1 or a tap on the layout line switches both controllers
    property string layout: "nes"

    // One map for both layouts: nes uses only the stick and A/B of it
    readonly property var keys: ({
        axisX: [Qt.Key_Left, Qt.Key_Right], axisY: [Qt.Key_Down, Qt.Key_Up],
        axisRightX: [Qt.Key_J, Qt.Key_L], axisRightY: [Qt.Key_K, Qt.Key_I],
        buttonA: Qt.Key_A, buttonB: Qt.Key_B, buttonX: Qt.Key_X,
        buttonY: Qt.Key_Y, buttonL1: Qt.Key_Q, buttonR1: Qt.Key_E,
        triggerL2: Qt.Key_1, triggerR2: Qt.Key_3,
        buttonSelect: Qt.Key_Backspace, buttonStart: Qt.Key_Return
    })

    function toggleLayout() { layout = layout === "nes" ? "full" : "nes"; }

    Keys.forwardTo: [controller1, controller2]
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_F1) { toggleLayout(); event.accepted = true; }
    }
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
            text: "Layout: " + root.layout + " - press F1 or tap here to switch"
            font.family: root.monoFont
            font.pixelSize: 13
            color: root.textColor
            MouseArea { anchors.fill: parent; onClicked: root.toggleLayout() }
        }

        Text {
            text: root.layout === "nes" ?
                      "Left: keyboard - arrows, A, B  |  Right: touch" :
                      "Left: keyboard - arrows, IJKL, A B X Y, Q E (L1 R1), " +
                      "1 3 (L2 R2), Backspace Return (select start)  |  Right: touch"
            font.family: root.monoFont
            font.pixelSize: 11
            color: root.dimTextColor
        }

        Text {
            text: "Connected gamepads: " + controller1.numConnectedGamepads
            font.family: root.monoFont
            font.pixelSize: 11
            color: root.dimTextColor
        }
    }

    Row {
        anchors.fill: parent
        anchors.topMargin: 90

        GameController {
            id: controller1
            width: parent.width * .5
            height: parent.height
            layout: root.layout
            Component.onCompleted: updateCtrl()
            onNumConnectedGamepadsChanged: updateCtrl()
            function updateCtrl() {
                if (numConnectedGamepads > 0)
                    selectGamepad(0);
                else
                    selectKeyboard(root.keys);
            }
            showDebugOverlay: true
        }

        GameController {
            id: controller2
            width: parent.width * .5
            height: parent.height
            layout: root.layout
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
