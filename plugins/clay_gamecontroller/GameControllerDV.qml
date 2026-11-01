// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype GameControllerDV
    \inqmlmodule Clayground.GameController
    \brief Debug visualization component showing GameController state.

    GameControllerDV displays the inputs of a GameController's layout with
    their live values, and its layout and active input source - for a
    physical gamepad, the pad's name. With \c nes
    it shows the stick as four directions and B/A; with \c full it shows both
    sticks with their position, A/B/X/Y, L1/R1, the triggers L2/R2 filling
    with their value, and select/start.
    Useful for debugging input handling during development.

    Every input has an indicator named \c {"dv_" + input}, e.g.
    \c dv_buttonX, whose \c level is the value it shows (a button is 0 or 1);
    the line naming layout and source is \c dv_source.

    Example usage:
    \qml
    import Clayground.GameController

    GameControllerDV {
        observed: myController
        anchors.centerIn: parent
    }
    \endqml

    \qmlproperty GameController GameControllerDV::observed
    \brief The GameController instance to visualize.
*/
import QtQuick

Rectangle {
    id: theDebugVisu

    opacity: .75
    color: "grey"
    anchors.centerIn: parent
    width: parent.width * .5
    height: .5 * width
    border.width: (_full ? .04 : .1) * height
    border.color: "lightgrey"
    radius: height * .08
    property var observed: null

    readonly property bool _full: observed !== null && observed.layout === "full"
    readonly property real _h: height

    function _level(input) {
        if (!observed) return 0;
        const v = observed.inputValue(input);
        return typeof v === "boolean" ? (v ? 1 : 0) : v;
    }

    function _sourceName() {
        if (!observed) return "";
        const src = observed.keyboardSelected ? "Keyboard" :
                    observed.gamepadSelected && observed.gamepad ?
                        observed.gamepad.name :
                    observed.vGamepadSelected ? "Touchscreen" : "None";
        return observed.layout + " · " + src +
               (observed.syntheticActive ? " + Dojo" : "");
    }

    // Carries an input's value; the visuals read level from here.
    component Reading: Item {
        property string input: ""
        objectName: "dv_" + input
        readonly property real level: theDebugVisu._level(input)
    }

    component RoundButton: Rectangle {
        id: theButton
        property string input: ""
        property alias label: theLabel.text
        readonly property real level: theReading.level
        width: .12 * theDebugVisu._h
        height: width
        radius: width * .5
        color: level > .5 ? "red" : "darkred"
        Reading { id: theReading; input: theButton.input }
        Text {
            id: theLabel
            anchors.centerIn: parent
            font.pixelSize: .6 * parent.height
            font.bold: true
            color: "white"
            text: theButton.input.replace("button", "")
        }
    }

    // Fills from the bottom with the trigger's value
    component Trigger: Rectangle {
        id: theTrigger
        property string input: ""
        property alias label: theTLabel.text
        width: .14 * theDebugVisu._h
        height: .1 * theDebugVisu._h
        color: "black"
        Reading { id: theTReading; input: theTrigger.input }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: theTReading.level * parent.height
            color: "red"
        }
        Text {
            id: theTLabel
            anchors.centerIn: parent
            font.pixelSize: .7 * parent.height
            font.bold: true
            color: "white"
        }
    }

    component Stick: Rectangle {
        id: theStick
        property string inputX: ""
        property string inputY: ""
        width: .34 * theDebugVisu._h
        height: width
        radius: width * .5
        color: "black"
        Reading { id: theX; input: theStick.inputX }
        Reading { id: theY; input: theStick.inputY }
        Rectangle {
            width: .35 * parent.width
            height: width
            radius: width * .5
            color: Math.abs(theX.level) > .05 || Math.abs(theY.level) > .05 ?
                       "red" : "darkred"
            x: .5 * (parent.width - width) + theX.level * .5 * (parent.width - width)
            y: .5 * (parent.height - height) - theY.level * .5 * (parent.height - height)
        }
    }

    Text {
        objectName: "dv_source"
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: parent.height * (theDebugVisu._full ? .05 : .12)
        anchors.horizontalCenter: parent.horizontalCenter
        font.bold: true
        font.pixelSize: parent.height * .09
        text: theDebugVisu._sourceName()
    }

    // nes: the stick as four directions, then B and A
    Item {
        anchors.fill: parent
        visible: !theDebugVisu._full

        Reading { id: theNesX; input: "axisX" }
        Reading { id: theNesY; input: "axisY" }

        Rectangle {
            x: .3 * parent.height
            y: .6 * parent.height
            width: .15 * parent.height
            height: width
            color: theNesY.level < -0.3 ? "red" : "black"
        }
        Rectangle {
            x: .3 * parent.height
            y: .3 * parent.height
            width: .15 * parent.height
            height: width
            color: theNesY.level > 0.3 ? "red" : "black"
        }
        Rectangle {
            x: .15 * parent.height
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            color: theNesX.level < -0.3 ? "red" : "black"
        }
        Rectangle {
            x: .45 * parent.height
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            color: theNesX.level > 0.3 ? "red" : "black"
        }

        Rectangle {
            x: .65 * parent.width
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            radius: width * .5
            color: theNesB.level > .5 ? "red" : "darkred"
            Reading { id: theNesB; input: "buttonB" }
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
            x: .8 * parent.width
            y: .45 * parent.height
            width: .15 * parent.height
            height: width
            radius: width * .5
            color: theNesA.level > .5 ? "red" : "darkred"
            Reading { id: theNesA; input: "buttonA" }
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

    // full: shoulders and triggers on top, the left stick, select/start and
    // the right stick in the middle, A/B/X/Y on the right
    Item {
        id: theFull
        anchors.fill: parent
        visible: theDebugVisu._full
        readonly property real h: theDebugVisu._h

        Trigger { input: "triggerL2"; label: "L2"; x: .25 * theFull.h; y: .18 * theFull.h }
        RoundButton { input: "buttonL1"; x: .45 * theFull.h; y: .17 * theFull.h }
        RoundButton { input: "buttonR1"; x: 1.43 * theFull.h; y: .17 * theFull.h }
        Trigger { input: "triggerR2"; label: "R2"; x: 1.61 * theFull.h; y: .18 * theFull.h }

        Stick {
            inputX: "axisX"; inputY: "axisY"
            x: .4 * theFull.h - .5 * width; y: .58 * theFull.h - .5 * height
        }
        RoundButton {
            input: "buttonSelect"; label: "Se"
            x: .82 * theFull.h - .5 * width; y: .45 * theFull.h - .5 * height
        }
        RoundButton {
            input: "buttonStart"; label: "St"
            x: 1.18 * theFull.h - .5 * width; y: .45 * theFull.h - .5 * height
        }
        Stick {
            inputX: "axisRightX"; inputY: "axisRightY"
            x: 1.12 * theFull.h - .5 * width; y: .74 * theFull.h - .5 * height
        }

        Item {
            id: theFace
            readonly property real step: .14 * theFull.h
            x: 1.6 * theFull.h; y: .58 * theFull.h
            RoundButton { input: "buttonA"; x: -.5 * width; y: theFace.step - .5 * height }
            RoundButton { input: "buttonB"; x: theFace.step - .5 * width; y: -.5 * height }
            RoundButton { input: "buttonX"; x: -theFace.step - .5 * width; y: -.5 * height }
            RoundButton { input: "buttonY"; x: -.5 * width; y: -theFace.step - .5 * height }
        }
    }
}
