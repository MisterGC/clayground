// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Box2D 2.0
import Clayground.Network 1.0
import Clayground.World 1.0
import Clayground.GameController 1.0

ClayWorld {
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0,0)
    timeStep: 1/60.0
    anchors.fill: parent


    components: new Map([
                         ['Player', playerComp],
                         ['Wall', wallComp]
                     ])
    Component { id: playerComp; Player {} }
    Component { id: wallComp; Wall {} }

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
            player.onXWuChanged.connect(_regulatedSendPosition)
            player.onYWuChanged.connect(_regulatedSendPosition)
            _regulatedSendPosition();
        }
    }

    property int updateFreq: 25
    Timer {id: updateTimer; interval: updateFreq; onTriggered: _sendPosition()}
    function _regulatedSendPosition(){
        if (updateTimer.running) return;
        updateTimer.restart();
        _sendPosition();
    }

    function _sendPosition(){
        networkUser.broadcastMessage(JSON.stringify({xWu: player.xWu, yWu: player.yWu}))
    }

    ClayNetworkUser {
        id: networkUser

        property var otherPlayers: new Map()
        onNewParticipant: {
            let obj = playerComp.createObject(theWorld, {
                                                  xWu: player.xWu, yWu: player.yWu,
                                                  bodyType: Body.Static, sensor: true,
                                                  widthWu: player.widthWu, heightWu: player.heightWu
                                              });
            otherPlayers.set(user, obj);
            theWorld._regulatedSendPosition();
        }
        onNewMessage: {
            if (otherPlayers.has(from)){
                let p = otherPlayers.get(from);
                let update = JSON.parse(message);
                p.xWu = update.xWu;
                p.yWu = update.yWu;
            }
        }
    }
}

