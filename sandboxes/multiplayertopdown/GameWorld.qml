// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.GameController 1.0
import Clayground.World 1.0

ClayWorld {
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0,0)
    timeStep: 1/60.0
    anchors.fill: parent

    property var enemyComponent: Qt.createComponent("Enemy.qml")
    property var enemies: new Map()

    components: new Map([
                         ['Player', c1],
                         ['Wall', c2]
                     ])
    Component { id: c1; Player {} }
    Component { id: c2; Wall {} }

    property var player: null
    onMapAboutToBeLoaded: player = null;
    onMapLoaded: {
        theGameCtrl.selectKeyboard(Qt.Key_Up,
                                   Qt.Key_Down,
                                   Qt.Key_Left,
                                   Qt.Key_Right,
                                   Qt.Key_A,
                                   Qt.Key_S);
        theWorld.observedItem = player;
    }

    Keys.forwardTo: theGameCtrl
    GameController {id: theGameCtrl; anchors.fill: parent}

    onMapEntityCreated: {
        if (obj instanceof Player) {
            player = obj;
            player.color = "#d45500";
            player.onXChanged.connect(sendPosition)
            player.onYChanged.connect(sendPosition)
        }
    }

    Minimap {
        id: theMinimap
        opacity: 0.75
        world: theWorld
        width: parent.width * 0.2
        height: width * (coordSys.height / coordSys.width)
        anchors.right: parent.right
        anchors.rightMargin: width * 0.1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: anchors.rightMargin
        color: "black"

        typeMapping: new Map([
                                ['Player', mc1],
                                ['Wall', mc2]
                            ])
        Component {id: mc1; Rectangle {color: "orange"}}
        Component {id: mc2; Rectangle {color: "grey"}}

    }

    function sendPosition(){
        lobby.sendMsg(JSON.stringify({"uUID":lobby.appUUID,"x":player.x,"y":player.y}))
    }

    function getEnemy(uUID){
        for(var i in enemies){
            var enemy = enemies[i]
            if(enemy.uUID == uUID)
                return enemy
        }
        return null
    }

    function addEnemy(uuid){
        console.log(uuid)
        var obj = enemyComponent.createObject(theWorld/*theWorld.coordSys ???*/,{"uUID":uuid})
        enemies[uuid]=obj
    }

    function moveEnemy(uuid, x, y){
        var enemy = getEnemy(uuid)
        enemy.x=x; enemy.y=y
    }

}

/*
// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.GameController 1.0
import Clayground.World 1.0
import Clayground.Network 1.0

ClayWorld {
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0,0)
    timeStep: 1/60.0

    property var enemyComponent: Qt.createComponent("Enemy.qml")
    property var enemies: new Map()

    components: new Map([
                         ['Player', c1],
                         ['Wall', c2]
                     ])
    Component { id: c1; Player {} }
    Component { id: c2; Wall {} }

    property var player: null
    onMapAboutToBeLoaded: player = null;
    onMapLoaded: {
        theGameCtrl.selectKeyboard(Qt.Key_Up,
                                   Qt.Key_Down,
                                   Qt.Key_Left,
                                   Qt.Key_Right,
                                   Qt.Key_A,
                                   Qt.Key_S);
        theWorld.observedItem = player;
    }

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl
        anchors.fill: parent

        onAxisXChanged: {
            if (axisX > 0) player.moveRight();
            else if (axisX < 0) player.moveLeft();
            else { player.stopLeft(); player.stopRight();}
        }
        onAxisYChanged: {
            if (axisY > 0) player.moveUp();
            else if (axisY < 0) player.moveDown();
            else { player.stopUp(); player.stopDown();}
        }
    }

    onMapEntityCreated: {
        if (obj instanceof Player) {
            player = obj;
            player.color = "#d45500";
            player.onXChanged.connect(sendPosition)
            player.onYChanged.connect(sendPosition)
        }
    }

    Minimap {
        id: theMinimap
        opacity: 0.75
        world: theWorld
        width: parent.width * 0.2
        height: width * (coordSys.height / coordSys.width)
        anchors.right: parent.right
        anchors.rightMargin: width * 0.1
        anchors.bottom: parent.bottom
        anchors.bottomMargin: anchors.rightMargin
        color: "black"

        typeMapping: new Map([
                                ['Player', mc1],
                                ['Wall', mc2]
                            ])
        Component {id: mc1; Rectangle {color: "orange"}}
        Component {id: mc2; Rectangle {color: "grey"}}

    }

    function sendPosition(){
        lobby.sendMsg(JSON.stringify({"uUID":lobby.appUUID,"x":player.x,"y":player.y}))
    }

    function getEnemy(uUID){
        for(var i in enemies){
            var enemy = enemies[i]
            if(enemy.uUID == uUID)
                return enemy
        }
        return null
    }

    Lobby{
        id: lobby
        onAppsChanged: {
            for (var app in apps) {
                connectApp(app)
            }
        }
        onMsgReceived: {
            var obj = JSON.parse(msg)
            var enemy = getEnemy(obj.uUID)
            enemy.x=obj.x
            enemy.y=obj.y
        }
        onConnectedTo: {
            var obj = enemyComponent.createObject(theWorld.coordSys,{"uUID":UUID})
            enemies[UUID]=obj
            console.log("onConnectedTo "+obj)
        }
    }

}
*/
