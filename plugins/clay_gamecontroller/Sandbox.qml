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
import QtQuick 2.5
import QtQuick.Particles 2.0

Rectangle {
    id: root
    anchors.fill: parent
    color: "black"

    Keys.forwardTo: [controller1, controller2]
    Component.onCompleted: forceActiveFocus()

    Grid {
        anchors.fill: parent
        columns: 2
    GameController {
        id: controller1
        width: parent.width * .5
        height: parent.height
        Component.onCompleted: {
            //selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K);
            selectGamepad(0);
            //selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_M, Qt.Key_N);
            //selectTouchscreenGamepad();
        }
        showDebugOverlay: true
    }
    GameController {
        id: controller2
        width: parent.width * .5
        height: parent.height
        Component.onCompleted: {
            //selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K);
            //selectGamepad(1);
            //selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_M, Qt.Key_N);
            selectTouchscreenGamepad();
        }
        showDebugOverlay: true
    }
    }

}
