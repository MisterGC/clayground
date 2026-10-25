// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype TouchscreenGamepad
    \inqmlmodule Clayground.GameController
    \brief Virtual on-screen gamepad for touch devices.

    TouchscreenGamepad provides a touch-based controller interface for the
    inputs of its GameController's layout. It fills its parent and is used
    internally by GameController when touchscreen input is selected.

    With the \c nes layout a virtual stick appears wherever the area is
    touched, and B and A sit in the lower right corner. With \c full the left
    half drives the left stick and the right half the right stick; A, B, X
    and Y sit in the lower right as a diamond (A at the bottom, B right, X
    left, Y top), L1/L2 in the upper left, R1/R2 in the upper right, select
    and start at the bottom centre. A trigger reads 1 while touched.

    A stick's value is the finger's offset from where it touched down,
    divided by the stick's radius and clamped to [-1, 1] on each axis. Every
    stick and pad follows its own touch point, so a stick and buttons can be
    held at the same time; the mouse drives them as one touch point.

    \qmlproperty bool TouchscreenGamepad::enabled
    \brief Whether touchscreen input handling is active.

    \qmlproperty GameController TouchscreenGamepad::gameController
    \brief Reference to the parent GameController.

    \qmlproperty real TouchscreenGamepad::unit
    \readonly
    \brief Size of the stick's base in pixels, a tenth of the height; the
    pads are 0.8 of it.

    \qmlmethod void TouchscreenGamepad::configure()
    \brief Writes every input of the layout as neutral.
*/
import QtQuick

Item {
    id: theTouch

    anchors.fill: parent
    enabled: false
    visible: enabled
    property var gameController: null

    readonly property bool _full: gameController !== null &&
                                  gameController.layout === "full"
    readonly property real unit: .1 * height

    function configure() {
        if (!gameController) return;
        for (const name of gameController._layoutInputs())
            gameController._write(name, gameController._neutral(name));
    }

    function _write(name, value) {
        if (gameController) gameController._write(name, value);
    }

    // A MultiPointTouchArea rather than a PointHandler: a PointHandler lets go
    // of its point as soon as a second one lands inside it, even one a pad on
    // top has taken - holding the stick and pressing L1 would drop the stick.
    component Stick: Item {
        id: theStick

        property string inputX: ""
        property string inputY: ""
        readonly property real radius: .5 * theTouch.unit
        readonly property alias active: thePoint.pressed

        function _update() {
            if (!thePoint.pressed) {
                theTouch._write(inputX, 0);
                theTouch._write(inputY, 0);
                return;
            }
            const dx = thePoint.x - thePoint.startX;
            const dy = thePoint.startY - thePoint.y;
            theTouch._write(inputX, Math.max(-1, Math.min(1, dx / radius)));
            theTouch._write(inputY, Math.max(-1, Math.min(1, dy / radius)));
        }

        MultiPointTouchArea {
            anchors.fill: parent
            maximumTouchPoints: 1
            touchPoints: [
                TouchPoint {
                    id: thePoint
                    onPressedChanged: theStick._update()
                    onXChanged: theStick._update()
                    onYChanged: theStick._update()
                }
            ]
            onCanceled: theStick._update()
        }

        Rectangle {
            id: theBase
            visible: thePoint.pressed
            width: theTouch.unit
            height: width
            radius: width * .5
            opacity: 0.7
            color: "white"
            x: thePoint.startX - .5 * width
            y: thePoint.startY - .5 * height

            Rectangle {
                width: .75 * parent.width
                height: width
                radius: width * .5
                color: "red"
                x: .5 * (parent.width - width) + (theTouch.gameController ?
                   theStick.radius * theTouch.gameController.inputValue(theStick.inputX) : 0)
                y: .5 * (parent.height - height) - (theTouch.gameController ?
                   theStick.radius * theTouch.gameController.inputValue(theStick.inputY) : 0)
            }
        }
    }

    component Pad: Rectangle {
        id: thePad

        property string input: ""
        property alias label: theLabel.text
        readonly property alias pressed: theTap.pressed

        objectName: "touch_" + input
        width: .8 * theTouch.unit
        height: width
        radius: width * .5
        color: pressed ? "#ffb347" : "orange"

        TapHandler {
            id: theTap
            gesturePolicy: TapHandler.WithinBounds
            onPressedChanged: theTouch._write(thePad.input,
                thePad.input.startsWith("button") ? pressed : (pressed ? 1 : 0))
        }
        Text {
            id: theLabel
            anchors.centerIn: parent
            font.pixelSize: .5 * parent.height
            text: thePad.input.replace("button", "").replace("trigger", "")
        }
    }

    Stick {
        objectName: "touch_stickLeft"
        width: theTouch._full ? .5 * parent.width : parent.width
        height: parent.height
        inputX: "axisX"
        inputY: "axisY"
    }

    Stick {
        objectName: "touch_stickRight"
        visible: theTouch._full
        x: .5 * parent.width
        width: .5 * parent.width
        height: parent.height
        inputX: "axisRightX"
        inputY: "axisRightY"
    }

    // B and A side by side, as on the NES
    Row {
        visible: !theTouch._full
        anchors.right: parent.right
        anchors.rightMargin: .25 * theTouch.unit
        anchors.bottom: parent.bottom
        anchors.bottomMargin: anchors.rightMargin
        spacing: .25 * theTouch.unit

        Pad { input: "buttonB" }
        Pad { input: "buttonA" }
    }

    Item {
        id: theFace
        visible: theTouch._full
        readonly property real step: .9 * theTouch.unit
        width: 3 * step
        height: width
        anchors.right: parent.right
        anchors.rightMargin: .25 * theTouch.unit
        anchors.bottom: parent.bottom
        anchors.bottomMargin: anchors.rightMargin

        Pad { input: "buttonA"; x: theFace.step; y: 2 * theFace.step }
        Pad { input: "buttonB"; x: 2 * theFace.step; y: theFace.step }
        Pad { input: "buttonX"; x: 0; y: theFace.step }
        Pad { input: "buttonY"; x: theFace.step; y: 0 }
    }

    Row {
        visible: theTouch._full
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: .25 * theTouch.unit
        spacing: .25 * theTouch.unit

        Pad { input: "triggerL2"; label: "L2" }
        Pad { input: "buttonL1" }
    }

    Row {
        visible: theTouch._full
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: .25 * theTouch.unit
        spacing: .25 * theTouch.unit

        Pad { input: "buttonR1" }
        Pad { input: "triggerR2"; label: "R2" }
    }

    Row {
        visible: theTouch._full
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: .25 * theTouch.unit
        spacing: .5 * theTouch.unit

        Pad { input: "buttonSelect"; label: "Sel" }
        Pad { input: "buttonStart"; label: "Sta" }
    }
}
