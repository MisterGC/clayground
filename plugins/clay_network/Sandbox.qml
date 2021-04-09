// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

Item
{
    id: networkDemo

    // Change the following two values to check scalability
    // and performance:
    readonly property int nrOfDynamicUsers: 12
    readonly property int chatInterval: 100

    property var dynUsers: []

    Component.onCompleted: {
        for (let i=0; i<nrOfDynamicUsers; ++i)
            dynUsers.push(dynUserComp.createObject(networkDemo, {nr:i}));
    }

    Component{
        id: textMsgComp
        Text{
            id: textMsg
            readonly property int ttl: 1000
            Behavior on x {NumberAnimation{duration: ttl}}
            Behavior on y {NumberAnimation{duration: ttl}}
            Timer{
                id: ttlTimer; interval: ttl; running: true;
                onTriggered: textMsg.destroy();
            }
        }
    }

    Component{
        id: dynUserComp
        Rectangle{
            id: rect
            color: Qt.hsla(.5, 1, .1 + (nrOfSentMsg/50) * .7, 1)
            width: (parent.height*.6)/nrOfDynamicUsers; height: width;
            radius: width * .1
            property int nrOfSentMsg: 0

            transformOrigin: Item.Center
            property int circleRadius: parent.width * .3
            x: parent.width * .5 + circleRadius * Math.sin(2*Math.PI/networkDemo.nrOfDynamicUsers*nr)
            y: parent.height * .5 + circleRadius * Math.cos(2*Math.PI/networkDemo.nrOfDynamicUsers*nr)

            property alias nr: dynUser.nr
            property alias userId: dynUser.userId
            function sendDirectMessage(msg, uId) {dynUser.sendDirectMessage(msg, uId)}
            function sendDirectMessageVisu(msg, user) {
                let obj = textMsgComp.createObject(networkDemo, {x: rect.x, y:rect.y, text: msg})
                obj.x = user.x;
                obj.y = user.y;
                dynUser.sendDirectMessage(msg, user.userId)
                nrOfSentMsg++;
            }

            ClayNetworkUser{
                id: dynUser
                property int nr: 0
                readonly property string myMsg: "Msg from user dynamic_" + nr + "!"
                onMsgReceived: console.log(nr + " received: "  + msg)
                onConnectedTo: sendDirectMessage("Hi from dynUser_" + nr + "!", otherUser);
            }
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
            sender.sendDirectMessageVisu( "data from " + sender.nr, receiver);
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
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.top: parent.top; anchors.topMargin: height * .5
        opacity: .8; font.pixelSize: parent.width * .03
        text: "Please press 'L' to show networking log"}

}
