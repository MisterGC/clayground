import QtQuick 2.0
import QtQuick.Controls 2.12

Item {

    function updateGroups(groups){
        groupsModel.clear();
        for (var g in groups){
            if(g)
                groupsModel.append({"group":g,"groupLength":groups[g]===undefined?0:groups[g].length})
        }
    }

    Timer{
        interval: 500; running: parent.visible; repeat: true
        onTriggered: updateGroups(lobby.groups)
    }

    Rectangle {
        id:lobbyRect
        anchors.fill: parent
        color: "transparent"
        property string connectedApps: ""

        ListModel{
            id:groupsModel
        }

        Image{
            anchors.fill: parent
            source: "map.svg"
            Rectangle{
                anchors.fill: parent
                color: "black"
                opacity: 0.6
            }
        }

        Column{
            y:5
            x:5
            spacing: 5
            Text{
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Lobby")
                color: "white"
            }

            Column{
                Row{
                    spacing: 5
                    Text {
                        text: qsTr("Rooms")
                        color: "white"
                    }
                    Button{
                        text: qsTr("New")
                        onClicked: modelNewGroup.visible=true
                    }
                }
                Row{
                    spacing: 5
                    Rectangle{
                        width: window.width-10
                        height: 100
                        border.width: 1
                        ListView{
                            anchors.fill: parent
                            anchors.margins: 2
                            model: groupsModel
                            delegate: Rectangle{
                                width: 150; height: 30
                                Row{
                                    Text {
                                        width: window.width-160; height: 30
                                        text: group
                                    }
                                    Text {
                                        width: 25; height: 30
                                        text: groupLength+"/8"
                                    }
                                    Button{
                                        text: "Join"
                                        enabled: groupLength<8
                                        onClicked: join(group)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function join(group){
        lobby.joinGroup(group)
        visible=false
        waitingRoom.visible=true
        waitingRoom.groupName=group
    }

    Rectangle{
        id:modelNewGroup
        width: 400
        height: 300
        visible: false
        onVisibleChanged: {
            groupField.text=""
        }

        Column{
            spacing: 10
            Text {
                text: qsTr("New Group")
            }
            Row{
                spacing: 10
                Text {
                    text: qsTr("Group:")
                }
                TextField{
                    id: groupField
                    focus: true
                }
            }
            Row{
                spacing: 10
                Button{
                    text: "Create"
                    onClicked: {
                        join(groupField.text);
                        modelNewGroup.visible=false
                    }
                }
                Button{
                    text: "Cancel"
                    onClicked: modelNewGroup.visible=false
                }
            }
        }
    }
}
