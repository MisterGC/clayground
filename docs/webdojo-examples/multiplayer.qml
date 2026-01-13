// P2P Network Demo - WebRTC via PeerJS
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Network

Item {
    id: root

    property string nodeName: ""
    property var remoteNames: ({})

    Network {
        id: network
        maxNodes: 4
        topology: Network.Topology.Star

        onNetworkCreated: (networkId) => {
            statusText.text = "Network: " + networkId + " (share this code!)"
            addChatMessage("System", "Network created: " + networkId)
        }

        onNodeJoined: (nodeId) => {
            addChatMessage("System", "A node is joining...")
            updateRemoteNode(nodeId, 0.5, 0.5, "?")
        }

        onNodeLeft: (nodeId) => {
            let name = remoteNames[nodeId] || nodeId.substring(0, 6)
            addChatMessage("System", name + " left")
            if (remoteNodes[nodeId]) {
                remoteNodes[nodeId].destroy()
                delete remoteNodes[nodeId]
                delete remoteNames[nodeId]
            }
        }

        onMessageReceived: (from, data) => {
            if (data.type === "chat") {
                let name = remoteNames[from] || from.substring(0, 6)
                addChatMessage(name, data.text)
            }
        }

        onStateReceived: (from, data) => {
            if (data && data.x !== undefined && data.y !== undefined) {
                if (data.name && data.name !== remoteNames[from]) {
                    let oldName = remoteNames[from]
                    remoteNames[from] = data.name
                    if (oldName === undefined || oldName === "?")
                        addChatMessage("System", data.name + " joined")
                }
                updateRemoteNode(from, data.x, data.y, data.name || "?")
            }
        }

        onErrorOccurred: (msg) => {
            statusText.text = "Error: " + msg
            addChatMessage("Error", msg)
        }
    }

    property var remoteNodes: ({})

    ListModel { id: chatMessages }

    function addChatMessage(from, text) {
        chatMessages.append({sender: from, message: text})
        if (chatMessages.count > 50) chatMessages.remove(0)
    }

    function updateRemoteNode(nodeId, x, y, name) {
        if (!remoteNodes[nodeId]) {
            remoteNodes[nodeId] = remoteComp.createObject(gameArea, { odId: nodeId })
        }
        remoteNodes[nodeId].targetX = x
        remoteNodes[nodeId].targetY = y
        remoteNodes[nodeId].nodeName = name || "?"
    }

    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: network.broadcastState({
            x: local.x / gameArea.width,
            y: local.y / gameArea.height,
            name: nodeName
        })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        RowLayout {
            spacing: 10

            Text {
                id: statusText
                text: network.connected ? "Connected (" + network.nodeCount + " nodes)" : "Not connected"
                color: network.connected ? "#4CAF50" : "#999"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: chatPanel.visible ? "Hide Chat" : "Show Chat"
                visible: network.connected
                onClicked: chatPanel.visible = !chatPanel.visible
            }
        }

        RowLayout {
            spacing: 10
            visible: !network.connected

            TextField {
                id: nameInput
                placeholderText: "Your Name"
                Layout.preferredWidth: 100
                text: "Node"
            }

            Button {
                text: "Host"
                enabled: nameInput.text.length > 0
                onClicked: { nodeName = nameInput.text; network.host() }
            }

            TextField {
                id: codeInput
                placeholderText: "Network Code"
                Layout.preferredWidth: 80
                font.capitalization: Font.AllUppercase
            }

            Button {
                text: "Join"
                enabled: codeInput.text.length >= 4 && nameInput.text.length > 0
                onClicked: { nodeName = nameInput.text; network.join(codeInput.text) }
            }
        }

        RowLayout {
            spacing: 10
            visible: network.connected

            Button {
                text: "Leave"
                onClicked: { network.leave(); remoteNodes = {}; chatMessages.clear() }
            }

            TextField {
                id: chatInput
                placeholderText: "Type message, press Enter..."
                Layout.fillWidth: true
                onAccepted: {
                    if (text) {
                        network.broadcast({type: "chat", text: text})
                        addChatMessage("You", text)
                        text = ""
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

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
                    color: "#666"
                    text: network.connected ? "Click to move. WASD keys work too." : "Host or Join a network"
                }

                Item {
                    id: local
                    width: 30
                    height: 30
                    visible: network.connected
                    x: parent.width/2 - 15
                    y: parent.height/2 - 15

                    Behavior on x { NumberAnimation { duration: 50 } }
                    Behavior on y { NumberAnimation { duration: 50 } }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 2
                        text: nodeName
                        color: "#0d47a1"
                        font.pixelSize: 10
                        font.bold: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        color: "#1976d2"
                        border.color: "#0d47a1"
                        border.width: 2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: network.connected
                    onClicked: (m) => {
                        root.forceActiveFocus()
                        local.x = m.x - 15
                        local.y = m.y - 15
                    }
                }

                Component {
                    id: remoteComp
                    Item {
                        property string odId: ""
                        property string nodeName: "?"
                        property real targetX: 0.5
                        property real targetY: 0.5
                        width: 30
                        height: 30
                        x: targetX * parent.width - 15
                        y: targetY * parent.height - 15

                        Behavior on x { NumberAnimation { duration: 80 } }
                        Behavior on y { NumberAnimation { duration: 80 } }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 2
                            text: nodeName
                            color: "#bf360c"
                            font.pixelSize: 10
                            font.bold: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 15
                            color: "#e65100"
                            border.color: "#bf360c"
                            border.width: 2
                        }
                    }
                }
            }

            Rectangle {
                id: chatPanel
                visible: false
                Layout.preferredWidth: 200
                Layout.fillHeight: true
                color: "#f5f5f5"
                border.color: "#ddd"
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4

                    Text {
                        text: "Chat Log"
                        font.bold: true
                        color: "#333"
                    }

                    ListView {
                        id: chatList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: chatMessages
                        clip: true
                        spacing: 2

                        delegate: Text {
                            width: chatList.width
                            wrapMode: Text.Wrap
                            font.pixelSize: 11
                            color: sender === "System" ? "#666" : (sender === "Error" ? "#c00" : "#333")
                            text: "<b>" + sender + ":</b> " + message
                            textFormat: Text.StyledText
                        }

                        onCountChanged: Qt.callLater(() => positionViewAtEnd())
                    }
                }
            }
        }

        Text {
            text: "Open in two browser tabs to test networking."
            color: "#999"
            font.pixelSize: 11
        }
    }

    focus: true
    Keys.onPressed: (e) => {
        if (!network.connected) return
        let s = 10
        if (e.key === Qt.Key_W || e.key === Qt.Key_Up) local.y = Math.max(0, local.y - s)
        if (e.key === Qt.Key_S || e.key === Qt.Key_Down) local.y = Math.min(gameArea.height-30, local.y + s)
        if (e.key === Qt.Key_A || e.key === Qt.Key_Left) local.x = Math.max(0, local.x - s)
        if (e.key === Qt.Key_D || e.key === Qt.Key_Right) local.x = Math.min(gameArea.width-30, local.x + s)
    }
}
