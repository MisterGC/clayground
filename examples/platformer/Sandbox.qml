// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.GameController
import Clayground.World
import Clayground.Physics
import Clayground.Canvas
import Clayground.Common

ClayWorld
{
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0, 15*9.81)
    timeStep: 1/60.0
    anchors.fill: parent

    components: new Map([
                         ['Player', c1],
                         ['Wall', c2],
                         ['Rock', c3],
                         ['Box', c4]
                     ])
    Component { id: c1; Player {} }
    Component { id: c2; Wall {} }
    Component { id: c3; VisualizedPolyBody {} }
    Component { id: c4; WoodenBox {} }

    property var player: null
    property var woodenBox: null
    onMapAboutToBeLoaded: {
        player = null;
    }
    onMapLoaded: {
        theGameCtrl.selectKeyboard(Qt.Key_Up,
                                   Qt.Key_Down,
                                   Qt.Key_Left,
                                   Qt.Key_Right,
                                   Qt.Key_A,
                                   Qt.Key_S);
        player.desireX = Qt.binding(function() {return theGameCtrl.axisX;});
        theWorld.observedItem = player;

        if (Clayground.runsInSandbox) {
            claylog.watch(player, "x")
            claylog.watch(player, "y")
            claylog.watch(player.graphics, "currentSprite", true)
            // Watch distance between upper-left pos player<->woodenBox
            claylog.watch(_ => {
                              let d = Qt.vector2d(woodenBox.x, woodenBox.y).minus(
                                  Qt.vector2d(player.x, player.y)).length();
                              return "dToBox: " + Math.round(d)});
        }
    }

    //physicsDebugging: true

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl
        anchors.fill: parent
        onButtonBPressedChanged:  if (buttonBPressed) player.jump();
    }

    onMapEntityCreated: (obj, groupId, compName) => {
       if (obj instanceof VisualizedPolyBody) {
           obj.fixedRotation = false;
           obj.bullet = true
           obj.friction = 10;
           obj.density = 1000;
           obj.categories = Box.Category3;
           obj.collidesWith = Box.Category1 | Box.Category2 | Box.Category3;
       }
       else {
           if (obj instanceof Player) player = obj;
           else if (obj instanceof WoodenBox) woodenBox = obj;
           else if (obj instanceof RectBoxBody) obj.color = "black";
       }
    }

}
