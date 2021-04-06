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

    function sendPosition(){
        lobby.sendMsg(JSON.stringify({"uUID":lobby.appUUID,"x":player.x,"y":player.y}))
    }

    function getEnemy(uUID){
        for(var i in enemies){
            var enemy = enemies[i]
            if(enemy.uUID === uUID)
                return enemy;
        }
        return null;
    }

    function addEnemy(uuid){
        let obj = enemyComponent.createObject(theWorld, {"uUID":uuid});
        enemies[uuid]=obj;
    }

    function moveEnemy(uuid, x, y){
        let enemy = getEnemy(uuid);
        enemy.x=x;
        enemy.y=y;
    }
}
