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
            text: "Connected gamepads: " + controller1.numConnectedGamepads +
                  (controller1.numConnectedGamepads > 0 ?
                       "  |  Left: the first pad" +
                       (controller1.numConnectedGamepads > 1 ? ", Right: the second" : "") : "")
            font.family: root.monoFont
            font.pixelSize: 11
            color: root.dimTextColor
        }
    }

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: padPanel.top
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

    // Every connected pad by name, with every button and axis it reports,
    // live: one look tells whether a pad is fully recognised
    Rectangle {
        id: padPanel
        objectName: "padPanel"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        height: padColumn.implicitHeight + 16
        radius: 6
        color: root.surfaceColor

        Column {
            id: padColumn
            x: 8; y: 8
            width: parent.width - 16
            spacing: 8

            // A browser shows the page a pad only once it was pressed
            Text {
                objectName: "noPadHint"
                visible: controller1.numConnectedGamepads === 0
                text: Qt.platform.os === "wasm" ?
                          "No gamepad yet - press any button on your pad, the browser shows it only then" :
                          "No gamepad connected - plug one in, it shows up here"
                font.family: root.monoFont
                font.pixelSize: 12
                color: root.dimTextColor
            }

            Repeater {
                model: controller1.gamepads
                delegate: Column {
                    id: thePadView
                    required property var modelData
                    required property int index
                    readonly property var pad: modelData
                    objectName: "pad_" + pad.deviceId
                    width: padColumn.width
                    spacing: 4

                    Text {
                        text: "#" + thePadView.index + "  " + thePadView.pad.name +
                              "  (" + thePadView.pad.type + ", " +
                              thePadView.pad.buttons.length + " buttons, " +
                              thePadView.pad.axes.length + " axes)" +
                              (controller1.gamepad === thePadView.pad ? "  - left controller" :
                               controller2.gamepad === thePadView.pad ? "  - right controller" : "")
                        font.family: root.monoFont
                        font.pixelSize: 12
                        font.bold: true
                        color: root.textColor
                    }

                    Flow {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: thePadView.pad.buttons
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool down: thePadView.pad.values[modelData] === true
                                readonly property string label: thePadView.pad.labels[modelData] || ""
                                objectName: "button_" + modelData
                                width: buttonText.implicitWidth + 10
                                height: 18
                                radius: 3
                                color: down ? root.accentColor : "#0d1b33"
                                border.color: root.accentColor
                                Text {
                                    id: buttonText
                                    anchors.centerIn: parent
                                    text: parent.modelData + (parent.label ? " " + parent.label : "")
                                    font.family: root.monoFont
                                    font.pixelSize: 10
                                    color: parent.down ? "#000000" : root.textColor
                                }
                            }
                        }

                        Repeater {
                            model: thePadView.pad.axes
                            delegate: Rectangle {
                                id: theAxis
                                required property string modelData
                                readonly property real value: thePadView.pad.values[modelData] || 0
                                readonly property bool trigger: modelData.endsWith("Trigger")
                                objectName: "axis_" + modelData
                                width: 150
                                height: 18
                                radius: 3
                                color: "#0d1b33"
                                border.color: root.accentColor
                                // A stick fills from the middle, a trigger from the left
                                Rectangle {
                                    readonly property real origin: theAxis.trigger ? 0 : theAxis.width * .5
                                    readonly property real span: theAxis.trigger ? theAxis.width : theAxis.width * .5
                                    x: theAxis.value >= 0 ? origin : origin + theAxis.value * span
                                    width: Math.abs(theAxis.value) * span
                                    height: parent.height
                                    radius: 3
                                    color: root.accentColor
                                    opacity: .6
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: theAxis.modelData + " " + theAxis.value.toFixed(2)
                                    font.family: root.monoFont
                                    font.pixelSize: 10
                                    color: root.textColor
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
