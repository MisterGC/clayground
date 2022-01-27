// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Network

Item
{
    id: networkDemo

    // This demo demonstrates multiple aspects:
    // Dynamically created set of users that communicate with each other
    // Disconnects of dynamically created users after random time
    readonly property bool demoDynamicUsers: true
    // Creation of one group with fixed set of usfalse and group-internal conversations
    readonly property bool demoGroupConcept: true

    // Change the following two values to check scalability and performance:
    readonly property int nrOfDynamicUsers: 10
    readonly property int chatInterval: 500

    property var dynUsers: []

    Component.onCompleted: {
        if (!demoDynamicUsers) return;
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

            Component.onDestruction: {
                let i = networkDemo.dynUsers.findIndex((e) => e.userId === rect.userId);
                if (i>-1) networkDemo.dynUsers.splice(i, 1);
            }

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
                let obj = textMsgComp.createObject(networkDemo, {x: rect.x, y:rect.y, text: msg})
                obj.x = user.x;
                obj.y = user.y;
                dynUser.sendDirectMessage(user.userId, msg)
                nrOfSentMsg++;
            }
            Timer {interval: 5000 + Math.random()*10000; running: true
            onTriggered: rect.destroy(); }

            ClayNetworkUser{
                id: dynUser
                property int nr: 0
                readonly property string myMsg: "Msg from user dynamic_" + nr + "!"
                onNewMessage: (message) => console.log(nr + " received: "  + message)
                onNewParticipant: (user) => {sendDirectMessage(user, "Hi from dynUser_" + nr + "!");}
                onParticipantLeft: (user) => {console.log("Participant " + user + " left.");}
            }
        }
    }

    // DEMO OF GROUP CONCEPT
    readonly property string group1: "debating-society"
    readonly property string group2: "anothergroup"

    Timer{
        id: conversationSim
        interval: chatInterval; running: true; repeat: true;
        onTriggered: {
            let arr = networkDemo.dynUsers;
            if (arr.length > 0) {
                let idx1 = Math.round(Math.random() * (arr.length -1));
                let idx2 = Math.round(Math.random() * (arr.length -1));
                let sender = arr[idx1];
                let receiver = arr[idx2];
                if (!sender || !receiver) return;
                sender.sendDirectMessageVisu(receiver, "data from " + sender.nr);
            }
            if (!demoGroupConcept) return;
            alice.sendGroupMessage(group1, group1 + " rocks!");
            anotherGuy.sendGroupMessage(group2, group2 + " is cool too!");
        }
    }

    ClayNetworkUser{
        id: alice
        name: "alice"
        Component.onCompleted: joinGroup(group1);
        onNewMessage: (from, message) => console.log(name + " got a message from " +
                                  nameForId(from) + ": " + message)
    }

    ClayNetworkUser{
        id: bob
        name: "bob"
        Component.onCompleted: {joinGroup(group1); joinGroup(group2);}
        onNewMessage: (from, message) => console.log(name + " got a message from " +
                                  nameForId(from) + ": " + message)
    }

    ClayNetworkUser{
        id: anotherGuy
        name: "anotherGuy"
        Component.onCompleted: joinGroup(group2)
        onNewMessage: console.log(name + " got a message from " +
                                  nameForId(from) + ": " + message)
    }


    Text {
        anchors.horizontalCenter: parent.horizontalCenter;
        anchors.top: parent.top; anchors.topMargin: height * .5
        opacity: .8; font.pixelSize: parent.width * .03
        text: "Please press 'L' to show networking log"
    }

}
