// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.12
import Clayground.Network 1.0

Window {
    visible: true
    visibility: Window.Maximized
    title: qsTr("Platformer")
    Sandbox { runsInSbx: false; anchors.fill: parent }
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

            Button{
                text: "send test"
                onClicked: lobby.sendMsg("test")
            }
        }

        Lobby{
            id:lobby
            onAppsChanged: {
                appsModel.clear()
                for (var prop in apps) {
                    appsModel.append(JSON.parse(prop));
                    console.log(apps)
                }
            }
            onMsgReceived: {console.log(msg)
                msgReceived.append({"msg":msg})
            }
            onConnectedTo: {
                lobbyRect.connectedApps+=UUID
            }
        }
    }
}
