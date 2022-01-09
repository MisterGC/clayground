// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick

Item {
    anchors.fill: parent
    enabled: false
    visible: enabled
    property var gameController: null

    property real normX: 0.0
    property real normY: 0.0

    function configure() {
        axisX = Qt.binding(function() {return normX;});
        axisY = Qt.binding(function() {return normY;});
    }

    MultiPointTouchArea {
        minimumTouchPoints: 1
        maximumTouchPoints: 1
        anchors.fill: parent
        touchPoints: [
            TouchPoint { id: point1 }
        ]
        onPressed: {
            theVirtualController.xCenter = point1.x;
            theVirtualController.yCenter = point1.y;
            theVirtualController.visible = true;
        }
        onReleased: {
            theVirtualController.visible = false;
            normX = 0.0;
            normY = 0.0;
        }
    }

    Rectangle {
        id: theVirtualController
        visible: false
        width: .1 * parent.height
        height: width
        opacity: 0.7
        property real xCenter: 0
        property real yCenter: 0
        x: xCenter - 0.5 * width
        y: yCenter - 0.5 * height
        color: "white"

        Rectangle {
            id: theVirtualAxis
            visible: theVirtualController.visible
            radius: 50
            width: .75 * parent.width
            height: width
            color: "red"
            x: 0.5 * (theVirtualController.width-width) + stickPos.x
            y: 0.5 * (theVirtualController.height-height) - stickPos.y
            property vector2d stickPos: applyLimit(point1.x, point1.y)
            onStickPosChanged: {
                normX = stickPos.x;
                normY = stickPos.y;
            }
            function applyLimit(x, y) {
                var vec = Qt.vector2d(x - theVirtualController.xCenter,
                                      - (y - theVirtualController.yCenter))
                if (Math.abs(vec.x) > 0.5 * theVirtualController.width)
                    vec.x = vec.x/Math.abs(vec.x) * 0.5 * theVirtualController.width
                if (Math.abs(vec.y) > 0.5 * theVirtualController.height)
                    vec.y = vec.y/Math.abs(vec.y) * 0.5 * theVirtualController.height
                return vec
            }
        }

    }

    Row
    {
        anchors.right: parent.right
        anchors.rightMargin: width * .3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: anchors.rightMargin

        spacing: theButtonB.width * .3
        Rectangle {
            id: theButtonB
            width: theVirtualController.width * .8
            height: width
            color: "orange"
            radius: width / 2
            MouseArea {
                anchors.fill: parent
                onPressed: gameController.buttonBPressed = true
                onReleased: gameController.buttonBPressed = false
            }
            Text {
                font.pixelSize: .75 * parent.height
                anchors.centerIn: parent
                text: "B"
            }
        }
        Rectangle {
            width: theVirtualController.width * .8
            height: width
            color: "orange"
            radius: width / 2
            MouseArea {
                anchors.fill: parent
                onPressed: gameController.buttonAPressed = true
                onReleased: gameController.buttonAPressed = false
            }
            Text {
                font.pixelSize: .75 * parent.height
                anchors.centerIn: parent
                text: "A"
            }
        }
    }
}
