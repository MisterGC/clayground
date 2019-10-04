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

Item
{
    enabled: false
    property var upKey: null
    property var downKey: null
    property var leftKey: null
    property var rightKey: null
    property var buttonAKey: null
    property var buttonBKey: null
    property var gameController: null

    function configure(uk, dk, lk, rk, bA, bB) {
        upKey = uk;
        downKey = dk;
        leftKey = lk;
        rightKey = rk;
        buttonAKey = bA;
        buttonBKey = bB;
    }

    Keys.onPressed: {
        if (!enabled || event.isAutoRepeat) return;
        switch (event.key)
        {
            case upKey: gameController.axisY = 1; break;
            case downKey: gameController.axisY = -1; break;
            case leftKey: gameController.axisX = -1; break;
            case rightKey: gameController.axisX = 1; break;
            case buttonAKey: gameController.buttonBPressed = true; break;
            case buttonBKey: gameController.buttonAPressed = true; break;
        }
    }

    Keys.onReleased: {
        if (!enabled || event.isAutoRepeat) return;
        switch (event.key)
        {
            case upKey: if (gameController.axisY > 0) gameController.axisY = 0; break;
            case downKey: if (gameController.axisY < 0) gameController.axisY = 0; break;
            case leftKey: if (gameController.axisX < 0) gameController.axisX = 0; break;
            case rightKey: if (gameController.axisX > 0) gameController.axisX = 0; break;
            case buttonAKey: gameController.buttonBPressed = false; break;
            case buttonBKey: gameController.buttonAPressed = false; break;
        }
    }
}
