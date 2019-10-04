/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.0

Rectangle {
    id: theDebugVisu

    opacity: .75
    color: "grey"
    anchors.centerIn: parent
    width: parent.width * .5
    height: .5 * width
    border.width: .1 * height
    border.color: "lightgrey"
    radius: height * .08
    property var observed: null

    Text {
        color: "black"
        anchors.top: parent.top
        anchors.topMargin: parent.height * .12
        anchors.horizontalCenter: parent.horizontalCenter
        font.bold: true
        font.pixelSize: parent.height * .09
        text: "Source: " + (observed.keyboardSelected ?
                                "Keyboard" :
                            observed.gamepadSelected ?
                                "Gamepad (" + observed.gamepadId + ")" :
                                "Touchscreen")
    }

    Rectangle {
        id: down
        x: .3 * parent.height
        y: .6 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisY < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: up
        x: .3 * parent.height
        y: .3 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisY > 0.3 ? "red" : "black"
    }
    Rectangle {
        id: left
        x: .15 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisX < -0.3 ? "red" : "black"
    }
    Rectangle {
        id: right
        x: .45 * parent.height
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        color: observed.axisX > 0.3 ? "red" : "black"
    }

    Rectangle {
        id: btnB
        x: .65 * parent.width
        y: .45 * parent.height
        width: .15 * parent.height
        height: width
        radius: width * .5
        color: observed.buttonBPressed ? "red" : "darkred"
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
        color: observed.buttonAPressed ? "red" : "darkred"
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
