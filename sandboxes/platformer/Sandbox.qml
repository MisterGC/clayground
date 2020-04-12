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
import Box2D 2.0
import Clayground.GameController 1.0
import Clayground.World 1.0

ClayWorld
{
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0, 15*9.81)
    timeStep: 1/60.0

    property var player: null
    onWorldAboutToBeCreated: player = null;
    onWorldCreated: {
        theGameCtrl.selectKeyboard(Qt.Key_Up,
                                   Qt.Key_Down,
                                   Qt.Key_Left,
                                   Qt.Key_Right,
                                   Qt.Key_A,
                                   Qt.Key_S);
        player.desireX = Qt.binding(function() {return theGameCtrl.axisX;});
        theWorld.observedItem = player;
    }

    physicsDebugging: true

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl
        anchors.fill: parent
        onButtonBPressedChanged:  if (buttonBPressed) player.jump();
    }

    onObjectCreated: {
       if (isInstanceOf(obj, "VisualizedPolyBody")) {
           obj.fixedRotation = false;
           obj.bullet = true
           obj.friction = 10;
           obj.density = 1000;
           obj.categories = Box.Category3;
           obj.collidesWith = Box.Category1 | Box.Category2 | Box.Category3;
       }
       else {
           obj.color = "black";
           if (isInstanceOf(obj, "Player")) {
               player = obj;
               player.spriteSource = theWorld.resource("player_animated.png")
           }
       }
    }
}
