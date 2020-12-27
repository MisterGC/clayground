// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Box2D 2.0
import Clayground.Common 1.0
import Clayground.GameController 1.0
import Clayground.Physics 1.0

Item {
    anchors.fill: parent

    component Wall: RectBoxBody {
        color: "#7084aa"
        bodyType: Body.Static; categories: Box.Category1
        collidesWith: Box.Category2 | Box.Category3
    }

    component Player:  RectBoxBody {
        color: "#3fa4c8"
        bodyType: Body.Dynamic; bullet: true
        categories: Box.Category2; collidesWith: Box.Category1 | Box.Category3
        readonly property real veloCompMax: 25
        property real xDirDesire: theGameCtrl.axisX; linearVelocity.x: xDirDesire * veloCompMax
        property real yDirDesire: -theGameCtrl.axisY; linearVelocity.y: yDirDesire * veloCompMax
    }

    component WoodenBox:  RectBoxBody {
        color: "orange"; bodyType: Body.Dynamic;
        categories: Box.Category3; collidesWith: Box.Category1 | Box.Category2 | Box.Category3
    }

    ClayWorld {
        id: someWorld

        anchors.fill: parent
        pixelPerUnit: width / someWorld.worldXMax
        gravity: Qt.point(0,0); timeStep: 1/60.0
        map: "map.svg"

        components: new Map([ ['Player', c1], ['Wall', c2] ])
        Component { id: c1; Player {} }
        Component { id: c2; Wall {} }

        property var player: null
        onObjectCreated: if (Clayground.typeName(obj) === "Player") {player = obj;}

        // Assign it directly to the world -> PhysicsItems are migrated automatically
        // to the room item which contains all 'inhabitants of the world'
        Repeater {
            model: 2
            delegate:  WoodenBox{
                xWu: (someWorld.worldXMin + someWorld.worldXMax) * .5
                yWu: (someWorld.worldYMin + someWorld.worldYMax) * .5 + index * heightWu * 1.1
                widthWu: 5; heightWu: 5}
        }

        // Directly assign an entity to the room item of the world
        WoodenBox{
            parent: someWorld.room; color: "black"
            xWu: (someWorld.worldXMin + someWorld.worldXMax) * .5
            yWu: (someWorld.worldYMin + someWorld.worldYMax) * .5 - 1.5 * heightWu
            widthWu: 5; heightWu: 5
        }


        onWorldAboutToBeCreated: player = null;
        Keys.forwardTo: theGameCtrl
        GameController {id: theGameCtrl; anchors.fill: parent;}
        onWorldCreated: {
            someWorld.observedItem = player;
            theGameCtrl.selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
        }
    }

    Minimap {
        color: "black";
        opacity: 0.75
        world: someWorld
        width: parent.width * 0.2
        height: width * (world.room.height / world.room.width)
        anchors.right: parent.right; anchors.rightMargin: width * 0.1
        anchors.bottom: parent.bottom; anchors.bottomMargin: anchors.rightMargin

        typeMapping: new Map([ ['Player', mc1], ['Wall', mc2], ['WoodenBox', mc3] ])
        Component {id: mc1; Rectangle {color: "#3fa4c8"}}
        Component {id: mc2; Rectangle {color: "grey"}}
        Component {id: mc3; Rectangle {color: "orange"}}
    }
}
