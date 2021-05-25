import QtQuick 2.0
import QtQuick.Controls 2.12

Rectangle {
    id: waitingRoom

    anchors.fill: parent
    property string connectedApps: ""
    property string groupName: ""

    function playersInTheRoom(apps){
        appsModel.clear()
        for (let i in apps) {
            appsModel.append(JSON.parse(lobby.appInfo(apps[i])));
        }
    }

    Timer{
        interval: 500; running: waitingRoom.visible
        triggeredOnStart: true; repeat: true
        onTriggered: playersInTheRoom(lobby.appsInGroup(groupName))
    }

    ListModel{ id:appsModel }

    Column{
        y:5; x:5; spacing: 5

        Text{ text: "Lobby"; anchors.horizontalCenter: parent.horizontalCenter }

        Column{
            Text { text: "Players" }
            Rectangle{
                width: 150; height: 100; border.width: 1
                ListView{
                    anchors.fill: parent
                    anchors.margins: 2
                    model: appsModel
                    delegate:
                        Text {
                        width: 150; height: 30
                        text: applicationPid + " " + localHostName
                        font.bold: waitingRoom.connectedApps.indexOf(UUID)>=0
                        MouseArea{
                            anchors.fill: parent
                            onClicked: lobby.connectApp(JSON.stringify({"applicationPid":applicationPid,
                                                                           "localHostName":localHostName,
                                                                           "tcpPort":tcpPort,
                                                                           "ipList":ipList,
                                                                           "UUID":UUID}))
                        }
                    }
                }
            }
        }

        Button{
            text: qsTr("Play")
            onClicked: { sandBox.focus=true; waitingRoom.visible=false; }
        }
    }
}