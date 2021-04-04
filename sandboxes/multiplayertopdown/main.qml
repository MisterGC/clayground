// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0
//Game idea, finding other players before a time limit
Window {
    id:window
    visible: true
    visibility: Window.Maximized
    title: qsTr("TopDown")
    Sandbox {id:sandBox}
    Component.onCompleted: if(Qt.platform.pluginName === "minimal") Qt.quit()
    Rectangle {
        id:lobbyRect
        anchors.fill: parent
        property string connectedApps: ""

        ListModel{
            id:appsModel
        }

        ListModel{
            id:msgReceived
        }

        ListModel{
            id:groupsModel
        }

        Column{
            y:5
            x:5
            spacing: 5
            Text{
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Lobby")
            }

            Row{
                spacing: 5
                Column{
                    Text {
                        text: qsTr("Players")
                    }
                    Rectangle{
                        width: 150
                        height: 100
                        border.width: 1
                        ListView{
                            anchors.fill: parent
                            anchors.margins: 2
                            model: appsModel
                            delegate: Rectangle{
                                width: 150; height: 30
                                Text {
                                    width: 100; height: 30
                                    text: applicationPid + " " + localHostName
                                    font.bold: lobbyRect.connectedApps.indexOf(UUID)>=0
                                    MouseArea{
                                        anchors.fill: parent
                                        onClicked: lobby.connectApp(JSON.stringify({"applicationPid":applicationPid,"localHostName":localHostName,"tcpPort":tcpPort,"ipList":ipList,"UUID":UUID}))
                                    }
                                }
                            }
                        }
                    }
                }
                Column{
                    Text {
                        text: qsTr("Received Messages")
                    }
                    Rectangle{
                        width: 150
                        height: 100
                        border.width: 1
                        ListView{
                            anchors.fill: parent
                            anchors.margins: 2
                            model: msgReceived
                            highlight: Rectangle { color: "lightsteelblue"; radius: 5 }
                            delegate: Rectangle{
                                width: 100; height: 30
                                Text {
                                    anchors.fill: parent
                                    text: msg
                                }
                            }
                        }
                    }
                }
            }

            Column{
                Text {
                    text: qsTr("Groups")
                }
                Row{
                    spacing: 5
                    Rectangle{
                        width: 150
                        height: 100
                        border.width: 1
                        ListView{
                            anchors.fill: parent
                            anchors.margins: 2
                            model: groupsModel
                            delegate: Rectangle{
                                width: 150; height: 30
                                Text {
                                    width: 100; height: 30
                                    text: group
                                }
                            }
                        }
                    }
                    Button{
                        text: qsTr("New Group")
                        onClicked: modelNewGroup.visible=true
                    }
                }
            }

            Row{
                TextField{
                    id:textField
                    width: 300
                }

                Button{
                    text: qsTr("Send")
                    onClicked: lobby.sendMsg(textField.text)
                }
            }

            Button{
                text: qsTr("Play")
                onClicked: {
                    lobbyRect.visible=false
                    sandBox.focus=true
                }
            }
        }

        Lobby{
            id:lobby
            onAppsChanged: {
                appsModel.clear()
                for (var prop in apps) {
                    appsModel.append(JSON.parse(prop));
                }
            }
            onGroupsChanged: {
                groupsModel.clear();
                for (var g in groups){
                    groupsModel.append({"group":g,"UUID":groups[g]})
                    console.log(groups[g])
                }
            }
            onMsgReceived: {console.log(msg)
                msgReceived.append({"msg":msg})
            }
            onConnectedTo: {
                lobbyRect.connectedApps+=UUID
                var component = Qt.createComponent("Player.qml");
                var obj = component.createObject(sandBox,{world:sandBox, x:0, y:0, width:50, height:50})
                obj.color = Qt.rgba(Math.random(),Math.random(),Math.random(),1);
            }
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
                    }
                }
                Row{
                    spacing: 10
                    Button{
                        text: "Create"
                        onClicked: {
                            lobby.joinGroup(groupField.text);
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
    Player{
        widthWu:100
        heightWu:100
    }

}

