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
import QtQuick 2.12
import QtQuick.Controls 2.5

Rectangle {
    id: bg
    border.width: height * .1
    border.color: Qt.lighter(valColor, .9)
    property alias valColor: grid.valColor
    property alias val: grid.val
    property alias max: grid.max
    property alias spacing: grid.spacing
    color: Qt.darker(valColor, 1.6)

    Grid {
        id: grid
        anchors.centerIn: parent
        height: parent.height - 4 * parent.border.width
        rows: 1
        spacing: grid.height * .15
        columns: max
        property int max: 10
        property int val: 3
        property color valColor: "orange"
        Repeater {
            model: grid.max
            Rectangle {
                height: grid.height
                width: (bg.width - (grid.spacing * grid.max + 1)) / grid.max
                opacity: index < grid.val ? 1 : 0.2
                color: valColor
                Behavior on opacity { NumberAnimation {duration: 500}}
            }
        }
    }
}

