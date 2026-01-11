// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Network

Item {
    id: root

    ClayMultiplayer {
        id: network
        maxPlayers: 4
        topology: ClayMultiplayer.Star

        onRoomCreated: (roomId) => {
            statusText.text = "Room created: " + roomId
            logMessage("Room created with code: " + roomId)
        }

        onPlayerJoined: (playerId) => {
            logMessage("Player joined: " + playerId.substring(0, 8) + "...")
        }

        onPlayerLeft: (playerId) => {
            logMessage("Player left: " + playerId.substring(0, 8) + "...")
        }

        onMessageReceived: (fromId, data) => {
            if (data.type === "chat") {
                logMessage("[" + fromId.substring(0, 6) + "] " + data.text)
            } else if (data.type === "move") {
                // Update remote player position
                updateRemotePlayer(fromId, data.x, data.y)
            }
        }

        onStateReceived: (fromId, data) => {
            updateRemotePlayer(fromId, data.x, data.y)
        }

        onErrorOccurred: (message) => {
            statusText.text = "Error: " + message
            logMessage("Error: " + message)
        }
    }

    property var remotePlayers: ({})

    function updateRemotePlayer(playerId, x, y) {
        if (!remotePlayers[playerId]) {
            remotePlayers[playerId] = remotePlayerComp.createObject(gameArea, {
                odId: playerId
            })
        }
        remotePlayers[playerId].targetX = x
        remotePlayers[playerId].targetY = y
    }

    function logMessage(msg) {
        logModel.append({ message: msg })
        if (logModel.count > 50) logModel.remove(0)
    }

    // Broadcast local player position periodically
    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: {
            network.broadcastState({
                x: localPlayer.x / gameArea.width,
                y: localPlayer.y / gameArea.height
            })
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Status bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                id: statusText
                text: network.connected
                      ? (network.isHost ? "Hosting: " + network.roomId : "Connected to: " + network.roomId)
                      : "Not connected"
                font.pixelSize: 16
                font.bold: true
                color: network.connected ? "#2e7d32" : "#666"
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: network.connected
                text: "Players: " + network.playerCount
                font.pixelSize: 14
                color: "#666"
            }
        }

        // Connection controls
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !network.connected

            Button {
                text: "Host Game"
                onClicked: network.createRoom()
            }

            TextField {
                id: roomCodeInput
                placeholderText: "Room Code"
                Layout.preferredWidth: 120
                font.capitalization: Font.AllUppercase
            }

            Button {
                text: "Join"
                enabled: roomCodeInput.text.length >= 4
                onClicked: network.joinRoom(roomCodeInput.text)
            }
        }

        // Leave button
        RowLayout {
            Layout.fillWidth: true
            visible: network.connected

            Button {
                text: "Leave"
                onClicked: {
                    network.leave()
                    // Clean up remote players
                    for (let id in remotePlayers) {
                        if (remotePlayers[id]) remotePlayers[id].destroy()
                    }
                    remotePlayers = {}
                }
            }

            Item { Layout.fillWidth: true }

            // Chat input
            TextField {
                id: chatInput
                placeholderText: "Type message..."
                Layout.preferredWidth: 200
                onAccepted: {
                    if (text.trim()) {
                        network.broadcast({ type: "chat", text: text })
                        logMessage("[You] " + text)
                        text = ""
                    }
                }
            }

            Button {
                text: "Send"
                onClicked: {
                    if (chatInput.text.trim()) {
                        network.broadcast({ type: "chat", text: chatInput.text })
                        logMessage("[You] " + chatInput.text)
                        chatInput.text = ""
                    }
                }
            }
        }

        // Game area and log side by side
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Game area
            Rectangle {
                id: gameArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#e8f5e9"
                border.color: "#a5d6a7"
                border.width: 2
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: network.connected
                          ? "Click to move your player\nUse arrow keys or WASD"
                          : "Host or Join a game to start"
                    color: "#666"
                    horizontalAlignment: Text.AlignHCenter
                    visible: !network.connected || network.playerCount < 2
                }

                // Local player
                Rectangle {
                    id: localPlayer
                    width: 30
                    height: 30
                    radius: 15
                    color: "#1976d2"
                    border.color: "#0d47a1"
                    border.width: 2
                    visible: network.connected
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height / 2

                    Behavior on x { NumberAnimation { duration: 100 } }
                    Behavior on y { NumberAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: "You"
                        color: "white"
                        font.pixelSize: 8
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: network.connected
                    onClicked: (mouse) => {
                        localPlayer.x = mouse.x - localPlayer.width / 2
                        localPlayer.y = mouse.y - localPlayer.height / 2
                    }
                }

                focus: true
                Keys.onPressed: (event) => {
                    if (!network.connected) return
                    let step = 10
                    switch (event.key) {
                        case Qt.Key_Left:
                        case Qt.Key_A:
                            localPlayer.x = Math.max(0, localPlayer.x - step)
                            break
                        case Qt.Key_Right:
                        case Qt.Key_D:
                            localPlayer.x = Math.min(gameArea.width - localPlayer.width, localPlayer.x + step)
                            break
                        case Qt.Key_Up:
                        case Qt.Key_W:
                            localPlayer.y = Math.max(0, localPlayer.y - step)
                            break
                        case Qt.Key_Down:
                        case Qt.Key_S:
                            localPlayer.y = Math.min(gameArea.height - localPlayer.height, localPlayer.y + step)
                            break
                    }
                }

                Component {
                    id: remotePlayerComp

                    Rectangle {
                        id: remotePlayer
                        property string odId: ""
                        property real targetX: 0.5
                        property real targetY: 0.5

                        width: 30
                        height: 30
                        radius: 15
                        color: "#e65100"
                        border.color: "#bf360c"
                        border.width: 2

                        x: targetX * parent.width - width / 2
                        y: targetY * parent.height - height / 2

                        Behavior on x { NumberAnimation { duration: 80 } }
                        Behavior on y { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: odId.substring(0, 2)
                            color: "white"
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }
                }
            }

            // Log panel
            Rectangle {
                Layout.preferredWidth: 250
                Layout.fillHeight: true
                color: "#fafafa"
                border.color: "#e0e0e0"
                border.width: 1
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 5

                    Text {
                        text: "Log"
                        font.bold: true
                        font.pixelSize: 12
                        color: "#666"
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ListModel { id: logModel }
                        delegate: Text {
                            width: parent ? parent.width : 0
                            text: message
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            color: "#333"
                        }
                        onCountChanged: positionViewAtEnd()
                    }
                }
            }
        }

        // Help text
        Text {
            Layout.fillWidth: true
            text: "Press 'L' to toggle Clayground log overlay"
            font.pixelSize: 11
            color: "#999"
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
