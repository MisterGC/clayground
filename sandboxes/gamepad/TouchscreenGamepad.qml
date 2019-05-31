import QtQuick 2.0

Item {
    enabled: false

    MultiPointTouchArea {
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
}
