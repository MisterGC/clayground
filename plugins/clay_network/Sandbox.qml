// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Network 1.0

Item
{
//    readonly property string group: "somegroup"

    ClayNetworkUser{
        id: user1
        //Component.onCompleted: joinGroup(group)
        onMsgReceived: console.log("User1 received: " + msg)

    }

    ClayNetworkUser{
        id: user2
        Component.onCompleted: {
            //joinGroup(group);
            sendDirectMessage("Hi there!", user1.userId);
            //sendMessage("Hi everyone!");
        }
        //onMsgReceived: console.log("User2 received: " + msg)
    }

//    ClayNetworkUser{
//        id: user3
//        onMsgReceived: console.log("User3 received: " + msg)
//    }
}
