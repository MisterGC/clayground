// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0
//Game idea, finding other players before a time limit
Rectangle {
    id:window
    anchors.fill: parent

    GameWorld{id:sandBox;  anchors.centerIn: parent; focus:true}
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()

    RoomScreen{
        id:roomScreen
        anchors.fill: parent
    }

    WaitingRoom{
        id:waitingRoom
        visible: false
    }

    Lobby{
        id:lobby
        onAppsChanged: {}
        onGroupsChanged: {
            roomScreen.updateGroups(groups)
        }
        onMsgReceived: {
            var obj = JSON.parse(msg)
            sandBox.moveEnemy(obj.uUID,obj.x,obj.y)
        }
        onConnectedTo: {
            sandBox.addEnemy(UUID);
        }
        onAppsSharingGroupsChanged: {
            console.log(appsSharingGroups)
        }
        onConnectedGroupsChanged: {
            console.log(connectedGroups)
        }
    }
}

