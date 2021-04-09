// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

Item
{
    id: networkDemo

    // Change the following two values to check scalability
    // and performance:
    readonly property int nrOfDynamicUsers: 3
    readonly property int chatInterval: 1000

    property var dynUsers: []

    Component.onCompleted: {
        for (let i=0; i<nrOfDynamicUsers; ++i)
            dynUsers.push(dynUserComp.createObject(networkDemo, {nr:i}));
    }

    Component{
        id: dynUserComp
        ClayNetworkUser{
            id: dynUser
            property int nr: 0
            readonly property string myMsg: "Msg from user dynamic_" + nr + "!"
            onMsgReceived: console.log(nr + " received: "  + msg)
            onConnectedTo: sendDirectMessage("Hi from dynUser_" + nr + "!", otherUser);
        }
    }

    // Demo of group-internal communication
    readonly property string group: "debating-society"

    Timer{
        id: conversationSim
        interval: chatInterval; running: true; repeat: true;
        onTriggered: {
            let arr = networkDemo.dynUsers;
            let sender = arr[Math.floor(Math.random() * arr.length)];
            let receiver = arr[Math.floor(Math.random() * arr.length)];
            sender.sendDirectMessage( "data from " + sender.nr, receiver.userId);
            alice.sendMessage(group + " rocks!")
        }
    }

    ClayNetworkUser{
        id: alice
        Component.onCompleted: joinGroup(group)
        onConnectedTo: sendDirectMessage("Hi from Alice!", otherUser);
        onMsgReceived: console.log("Alice received: " + msg)
    }

    ClayNetworkUser{
        id: bob
        Component.onCompleted: joinGroup(group)
        onConnectedTo: sendDirectMessage("Hi from Bob!", otherUser);
        onMsgReceived: {console.log("Bob received: " + msg);}
    }

    Text {
        anchors.centerIn: parent; opacity: .8; font.pixelSize: parent.width * .03
        text: "Please press 'L' to show networking log"}

}
