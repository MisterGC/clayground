import QtQuick 2.0
import QtGamepad 1.0

Item {
    property alias dirControllerUsed: gamepad.buttonR3
    property bool buttonA: false
    property bool buttonB: false
    property real axisX: 0
    property real axisY: 0
    property alias showDebugOverlay: theDebugVisu.visible
    property bool keyboardSelected: false


    Connections {
        target: GamepadManager
        onGamepadConnected: gamepad.deviceId = deviceId
    }

    /** Selects the specified gamepad as input source */
    function selectGamepad() {
        buttonA = Qt.binding(function() {return gamepad.buttonB;});
        buttonB = Qt.binding(function() {return gamepad.buttonA;});
        axisX = Qt.binding(function() {return gamepad.buttonLeft ? -1 : gamepad.buttonRight ? 1 : 0;});
        axisY = Qt.binding(function() {return gamepad.buttonUp ? 1 : gamepad.buttonDown ? -1 : 0;});
        keyboardSelected = false;
    }

    /** Selects the keyboard as input */
    function selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey) {
        keyboardSelected = true;
        _upKey = upKey;
        _downKey = downKey;
        _leftKey = leftKey;
        _rightKey = rightKey;
        _buttonAKey = buttonAKey;
        _buttonBKey = buttonBKey;
    }

    property var _upKey: null
    property var _downKey: null
    property var _leftKey: null
    property var _rightKey: null
    property var _buttonAKey: null
    property var _buttonBKey: null

    Keys.onPressed: {
        if (!keyboardSelected) return;
        switch (event.key)
        {
            case _upKey: axisY = 1; break;
            case _downKey: axisY = -1; break;
            case _leftKey: axisX = -1; break;
            case _rightKey: axisX = 1; break;
            case _buttonAKey: buttonB = true; break;
            case _buttonBKey: buttonA = true; break;
        }
    }

    Keys.onReleased: {
        if (!keyboardSelected) return;
        switch (event.key)
        {
            case _upKey: axisY = 0; break;
            case _downKey: axisY = 0; break;
            case _leftKey: axisX = 0; break;
            case _rightKey: axisX = 0; break;
            case _buttonAKey: buttonB = false; break;
            case _buttonBKey: buttonA = false; break;
        }
    }

    Gamepad {
        id: gamepad
        Component.onCompleted: console.log("Nr of conn gamepads: " + GamepadManager.connectedGamepads.length)
        deviceId: GamepadManager.connectedGamepads.length > 0 ? GamepadManager.connectedGamepads[0] : -1
    }

    MultiPointTouchArea {
        enabled: false
        minimumTouchPoints: 1
        maximumTouchPoints: 1
        anchors.fill: parent
        touchPoints: [
            TouchPoint { id: point1 }
        ]
        onPressed: {
            theVirtualController.xCenter = point1.x
            theVirtualController.yCenter = point1.y
            theVirtualController.visible = true
        }
        onReleased: {
            theVirtualController.visible = false
        }
    }

    Rectangle {
        id: theVirtualController
        visible: false
        width: 150
        height: 150
        opacity: 0.7
        property real xCenter: 0
        property real yCenter: 0
        x: xCenter - 0.5 * width
        y: yCenter - 0.5 * height
        color: "black"

        Rectangle {
            id: theVirtualAxis
            visible: theVirtualController.visible
            radius: 50
            width: 120
            height: 120
            color: "red"
            x: 0.5 * (theVirtualController.width-width) + stickPos.x
            y: 0.5 * (theVirtualController.height-height) + stickPos.y
            property real normX: stickPos.x / (0.5*theVirtualController.width)
            property real normY: stickPos.y / (0.5*theVirtualController.height)
            property vector2d stickPos: applyLimit(point1.x, point1.y)
            function applyLimit(x, y) {
                var vec = Qt.vector2d(x - theVirtualController.xCenter,
                                      y - theVirtualController.yCenter)
                if (Math.abs(vec.x) > 0.5 * theVirtualController.width)
                    vec.x = vec.x/Math.abs(vec.x) * 0.5 * theVirtualController.width
                if (Math.abs(vec.y) > 0.5 * theVirtualController.height)
                    vec.y = vec.y/Math.abs(vec.y) * 0.5 * theVirtualController.height
                return vec
            }
        }

    }

    Rectangle {
        id: theDebugVisu
        opacity: .75
        color: "grey"
        anchors.centerIn: parent
        width: parent.width * .3
        height: .5 * width
        border.width: .1 * height
        border.color: "lightgrey"
        radius: height * .08

        Text {
            color: "black"
            anchors.top: parent.top
            anchors.topMargin: parent.height * .12
            anchors.horizontalCenter: parent.horizontalCenter
            font.bold: true
            font.pixelSize: parent.height * .09
            text: "Source: " + (theController.keyboardSelected ? "Keyboard" : "Gamepad")
        }

        Rectangle {
            id: down
            x: .3 * parent.height
            y: .6 * parent.height
            width: .15 * parent.height
            height: width
            color: theController.axisY < -0.3 ? "red" : "black"
        }
        Rectangle {
            id: up
            x: .3 * parent.height
            y: .3 * parent.height
            width: .15 * parent.height
            height: width
            color: theController.axisY > 0.3 ? "red" : "black"
        }
        Rectangle {
            id: left
            x: .15 * parent.height
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            color: theController.axisX < -0.3 ? "red" : "black"
        }
        Rectangle {
            id: right
            x: .45 * parent.height
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            color: theController.axisX > 0.3 ? "red" : "black"
        }

        Rectangle {
            id: btnB
            x: .65 * parent.width
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            radius: width * .5
            color: theController.buttonB ? "red" : "darkred"
            Text {
                font.pixelSize: parent.height * .35
                anchors.top: parent.bottom
                anchors.right: parent.right
                text: "B"
                font.bold: true
                color: "darkred"
            }
        }
        Rectangle {
            id: btnA
            x: .8 * parent.width
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            radius: width * .5
            color: theController.buttonA ? "red" : "darkred"
            Text {
                font.pixelSize: parent.height * .35
                anchors.top: parent.bottom
                anchors.right: parent.right
                text: "A"
                font.bold: true
                color: "darkred"
            }
        }


    }
}
