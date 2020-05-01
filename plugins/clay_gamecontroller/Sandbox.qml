// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.5
import QtQuick.Particles 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "black"

    Keys.forwardTo: [controller1, controller2]
    Component.onCompleted: forceActiveFocus()

    Text {
        x: parent.width * 0.01
        y: parent.height * 0.01
        font.pixelSize: parent.height * 0.03
        text: "#Gamepads: " + controller1.numConnectedGamepads
        color: "orange"
        font.bold: true
    }

    Grid {
        anchors.fill: parent
        columns: 2
    GameController {
        id: controller1
        width: parent.width * .5
        height: parent.height
        Component.onCompleted: {
            // Use first gamepad or keyboard as fallback
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
        Component.onCompleted: {
            // Use second gamepad or touchscreen as fallback
            if (numConnectedGamepads > 1)
                selectGamepad(1);
            else
                selectTouchscreenGamepad();
        }
        showDebugOverlay: true
    }
    }

}
