// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

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
