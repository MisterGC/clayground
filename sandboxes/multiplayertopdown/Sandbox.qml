// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

//Game idea, finding other players before a time limit
Rectangle {
    id: window

    anchors.fill: parent

    // Start or join a game
    RoomScreen{ id:roomScreen; anchors.fill: parent }
    // Wait for game to be started
    WaitingRoom{ id: waitingRoom; visible: false }
    // Actual Game
    GameWorld{id:sandBox;  anchors.centerIn: parent; focus:true}

    // ClayNetwork
    Lobby {
        id:lobby

        // nodeId

        // There are nodes in the general ClayNetwork
        // they can join and leave, there is always info about
        // all the nodes in the network - there is no need
        // to deal with IPs or ports there are only nodeIds
        // which can be mapped to a human-readable name (optional)

        // onNodeJoined(<nodeId>)
        // onNodeLeft(<nodeId>)
        // nodes -> list<uuid>
        // name(<nodeId>)
        onAppsChanged: {}


        // There are sessions that can be created within the
        // network, each node can only be in one session at a
        // time - later this concept may be extended to multiple
        // session (so the backend may already provide them) but
        // they are not exposed

        // onSessionCreated(<sessionid>)
        // onSessionDestroyed
        // name(<sessionid>) -> string
        // sessions -> list<uuid>
        // createSession -> uuid (sessionid)
        // joinSession
        // onSessionJoined(<nodeId>)
        // onSessionLeft(<nodeId>)
        onGroupsChanged: {
            roomScreen.updateGroups(groups)
        }


        // Message sending and receiving is only possible for a node
        // when it has joined a session, messages can be sent to all,
        // a group or individuals within the same session

        // onMessage(string)
        // sendMessage(<receivers>) if no receiver specified
        onMsgReceived: {console.log(msg)
            //msgReceived.append({"msg":msg})
            var obj = JSON.parse(msg)
            sandBox.moveEnemy(obj.uUID,obj.x,obj.y)
        }
        onConnectedTo: sandBox.addEnemy(UUID);
        onAppsSharingGroupsChanged: {
            console.log(appsSharingGroups)
        }
        onConnectedGroupsChanged: {
            console.log(connectedGroups)
        }
    }
}

