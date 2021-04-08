// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Network 1.0

Item
{
    id: networkDemo

    Component.onCompleted: {
        for (let i=0; i<2; ++i)
            dynUserComp.createObject(networkDemo, {nr:i});
    }

    Component{
        id: dynUserComp
        ClayNetworkUser{
            property int nr: 0
            onConnectedTo: sendDirectMessage("Hi from user dynamic_" + nr + "!", otherUser);
            onMsgReceived: console.log("User dynamic_" + nr + " received: "  + msg)
        }
    }

    // Demo of group-internal communication
    readonly property string group: "user2and3Club"

    Timer{
        interval: 2000; running: true;
        onTriggered: user2.sendMessage(group + " rocks!")
    }

    ClayNetworkUser{
        id: user2
        Component.onCompleted: joinGroup(group)
        onConnectedTo: sendDirectMessage("Hi from user2!", otherUser);
        onMsgReceived: {console.log("User2 received: " + msg);}
    }

    ClayNetworkUser{
        id: user3
        Component.onCompleted: joinGroup(group)
        onConnectedTo: sendDirectMessage("Hi from user3!", otherUser);
        onMsgReceived: console.log("User3 received: " + msg)
    }
}
