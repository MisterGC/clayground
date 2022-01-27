// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

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

    Keys.onPressed: (event)=> {
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

    Keys.onReleased: (event)=> {
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
