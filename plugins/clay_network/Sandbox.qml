// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

Item
{
    id: networkDemo

    // This demo demonstrates multiple aspects:
    // Dynamically created set of users that communicate with each other
    // Creation of one group with group-internal conversations
    // Disconnect of one user after some time

    // Change the following two values to check scalability and performance:
    readonly property int nrOfDynamicUsers: 4
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
            function sendDirectMessage(user, msg) {dynUser.sendDirectMessage(user, msg)}
            function sendDirectMessageVisu(user, msg) {
                console.log("Send visu message to " + user.userId)
                let obj = textMsgComp.createObject(networkDemo, {x: rect.x, y:rect.y, text: msg})
                obj.x = user.x;
                obj.y = user.y;
                dynUser.sendDirectMessage(user.userId, msg)
                nrOfSentMsg++;
            }
            Timer {interval: Math.random()*10000; running: true
            onTriggered: rect.destroy(); }

            ClayNetworkUser{
                id: dynUser
                property int nr: 0
                readonly property string myMsg: "Msg from user dynamic_" + nr + "!"
                onNewMessage: console.log(nr + " received: "  + message)
                onNewParticipant: {sendDirectMessage(user, "Hi from dynUser_" + nr + "!");}
                onParticipantLeft:  {console.log("Participant " + user + " left.");}
            }
        }
    }

    // DEMO OF GROUP CONCEPT
    readonly property string group: "debating-society"

    Timer{
        id: conversationSim
        interval: chatInterval; running: false; repeat: true;
        onTriggered: {
            let arr = networkDemo.dynUsers;
            if (arr.length) {
                let sender = arr[Math.floor(Math.random() * arr.length)];
                let receiver = arr[Math.floor(Math.random() * arr.length)];
                sender.sendDirectMessageVisu(receiver, "data from " + sender.nr);
            }
            //alice.sendMessage(group + " rocks!")
        }
    }

//    ClayNetworkUser{
//        id: alice
//        Component.onCompleted: joinGroup(group)
//        onConnectedTo: sendDirectMessage("Hi from Alice!", otherUser);
//        onDisconnectedFrom: console.log("Alice got disconnected from " + otherUser)
//        onMsgReceived: console.log("Alice received: " + msg)
//    }

//    ClayNetworkUser{
//        id: bob
//        Component.onCompleted: joinGroup(group)
//        onConnectedTo: sendDirectMessage("Hi from Bob!", otherUser);
//        onDisconnectedFrom: console.log("Bob got disconnected from " + otherUser)
//        onMsgReceived: {console.log("Bob received: " + msg);}
//    }


//    // DISCONNECT AFTER SOME TIME (all others get informed)
//    Timer{interval: 5000; running: true;
//        onTriggered: {
//            volatileUser.destroy();
//            conversationSim.start();
//        }
//    }
//    ClayNetworkUser{id: volatileUser; Component.onCompleted: joinGroup(group)}

    Text {
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.top: parent.top; anchors.topMargin: height * .5
        opacity: .8; font.pixelSize: parent.width * .03
        text: "Please press 'L' to show networking log"
    }

}
