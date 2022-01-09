// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Box2D
import Clayground.Network
import Clayground.World
import Clayground.GameController

ClayWorld {
    id: theWorld

    map: "map.svg"
    pixelPerUnit: width / theWorld.worldXMax
    gravity: Qt.point(0,0)
    timeStep: 1/60.0
    anchors.fill: parent

    // Set this property to true if you want to run the app
    // on multiple computers within one LAN
    property bool multiplayer: false

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

    onMapEntityCreated: (obj, groupId, compName) => {
        if (obj instanceof Player) {
            player = obj;
            player.color = "#d45500";
            if (multiplayer) {
                player.onXWuChanged.connect(_networking.regulatedSendPosition)
                player.onYWuChanged.connect(_networking.regulatedSendPosition)
                _networking.regulatedSendPosition();
            }
        }
    }

    Minimap {
        opacity: 0.75
        world: theWorld
        width: theWorld.width * 0.2
        height: width * (_observed.height / _observed.width)
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

    property var _networking: _netLoader.item
    Loader {id: _netLoader; sourceComponent: theWorld.multiplayer ? _networkingComp : null}
    Component {
        id: _networkingComp
        Item {
            property int updateFreq: 25
            Timer {id: updateTimer; interval: updateFreq; onTriggered: sendPosition()}
            function regulatedSendPosition(){
                if (updateTimer.running) return;
                updateTimer.restart();
                sendPosition();
            }

            function sendPosition(){
                networkUser.broadcastMessage(JSON.stringify({xWu: player.xWu, yWu: player.yWu}))
            }

            ClayNetworkUser {
                id: networkUser

                property var otherPlayers: new Map()
                onNewParticipant: (user) => {
                    let obj = playerComp.createObject(theWorld, {
                                                          xWu: player.xWu, yWu: player.yWu,
                                                          bodyType: Body.Static, sensor: true,
                                                          widthWu: player.widthWu, heightWu: player.heightWu
                                                      });
                    otherPlayers.set(user, obj);
                    _networking.regulatedSendPosition();
                }
                onParticipantLeft: (user) => {
                    if (otherPlayers.has(user)){
                        let u = otherPlayers.get(user);
                        u.destroy();
                        otherPlayers.delete(user);
                    }
                }
                onNewMessage: (from) => {
                    if (otherPlayers.has(from)){
                        let p = otherPlayers.get(from);
                        let update = JSON.parse(message);
                        p.xWu = update.xWu;
                        p.yWu = update.yWu;
                    }
                }
            }
        }
    }
}
