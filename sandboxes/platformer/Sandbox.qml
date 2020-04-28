// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.GameController 1.0
import Clayground.World 1.0
import Clayground.Physics 1.0
import Clayground.ScalingCanvas 1.0

ClayWorld
{
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0, 15*9.81)
    timeStep: 1/60.0

    components: new Map([
                         ['Player', c1],
                         ['Wall', c2],
                         ['Rock', c3]
                     ])
    Component { id: c1; Player {} }
    Component { id: c2; Wall {} }
    Component { id: c3; VisualizedPolyBody {} }

    property var player: null
    onWorldAboutToBeCreated: {
        player = null;
    }
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
    Player {
        id: anotherPlayer
        parent: theWorld
        world: theWorld.physics
    }

    //physicsDebugging: true

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl
        anchors.fill: parent
        onButtonBPressedChanged:  if (buttonBPressed) player.jump();
    }

    onObjectCreated: {
       if (obj instanceof VisualizedPolyBody) {
           obj.fixedRotation = false;
           obj.bullet = true
           obj.friction = 10;
           obj.density = 1000;
           obj.categories = Box.Category3;
           obj.collidesWith = Box.Category1 | Box.Category2 | Box.Category3;
       }
       else {
           obj.color = "black";
           if (obj instanceof Player) {
               player = obj;
               player.spriteSource = theWorld.resource("player_animated.png")
           }
       }
    }
}
