// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Clayground.Network

Rectangle {
    id: root
    color: "#f5f5f5"

    Network {
        id: network
        maxNodes: 4
        topology: Network.Topology.Star

        onNetworkCreated: (networkId) => {
            statusText.text = "Network created: " + networkId
            logMessage("Network created with code: " + networkId)
        }

        onNodeJoined: (nodeId) => {
            logMessage("Node joined: " + nodeId.substring(0, 8) + "...")
        }

        onNodeLeft: (nodeId) => {
            logMessage("Node left: " + nodeId.substring(0, 8) + "...")
            if (remoteNodes[nodeId]) {
                remoteNodes[nodeId].destroy()
                delete remoteNodes[nodeId]
            }
        }

        onMessageReceived: (fromId, data) => {
            if (data.type === "chat") {
                logMessage("[" + fromId.substring(0, 6) + "] " + data.text)
            }
        }

        onStateReceived: (fromId, data) => {
            if (data && typeof data.x === 'number' && typeof data.y === 'number') {
                updateRemoteNode(fromId, data.x, data.y)
            }
        }

        onErrorOccurred: (message) => {
            logMessage("Error: " + message)
        }

        onStatusChanged: {
            let statusName = ["Disconnected", "Connecting", "Connected", "Error"][network.status]
            logMessage("Status: " + statusName)
        }
    }

    property var remoteNodes: ({})

    function updateRemoteNode(nodeId, x, y) {
        if (!remoteNodes[nodeId]) {
            remoteNodes[nodeId] = remoteNodeComp.createObject(gameArea, {
                odId: nodeId
            })
        }
        remoteNodes[nodeId].targetX = x
        remoteNodes[nodeId].targetY = y
    }

    function logMessage(msg) {
        logModel.append({ message: msg })
        if (logModel.count > 50) logModel.remove(0)
    }

    // Broadcast local node position periodically
    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: {
            network.broadcastState({
                x: localNode.x / gameArea.width,
                y: localNode.y / gameArea.height
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
                text: {
                    switch (network.status) {
                        case Network.Status.Disconnected: return "Not connected"
                        case Network.Status.Connecting: return "Connecting..."
                        case Network.Status.Connected:
                            return network.isHost ? "Hosting:" : "Connected to:"
                        case Network.Status.Error: return "Error"
                        default: return "Unknown"
                    }
                }
                font.pixelSize: 16
                font.bold: true
                color: {
                    switch (network.status) {
                        case Network.Status.Connected: return "#2e7d32"
                        case Network.Status.Connecting: return "#1565c0"
                        case Network.Status.Error: return "#c62828"
                        default: return "#666"
                    }
                }
            }

            // Copyable network ID
            TextField {
                visible: network.connected
                text: network.networkId
                readOnly: true
                selectByMouse: true
                Layout.preferredWidth: 90
                font.pixelSize: 16
                font.bold: true
                font.family: "monospace"
                color: "#2e7d32"

                background: Rectangle {
                    color: "transparent"
                    border.color: "transparent"
                }

                onActiveFocusChanged: if (activeFocus) selectAll()
                Keys.onPressed: (event) => {
                    if ((event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) && event.key === Qt.Key_C) {
                        selectAll(); copy()
                        logMessage("Copied: " + network.networkId)
                        event.accepted = true
                    }
                }
                TapHandler {
                    onDoubleTapped: { parent.selectAll(); parent.copy(); logMessage("Copied: " + network.networkId) }
                }
            }

            // Status indicator
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: {
                    switch (network.status) {
                        case Network.Status.Connected: return "#4caf50"
                        case Network.Status.Connecting: return "#2196f3"
                        case Network.Status.Error: return "#f44336"
                        default: return "#9e9e9e"
                    }
                }
                visible: network.status !== Network.Status.Disconnected

                SequentialAnimation on opacity {
                    running: network.status === Network.Status.Connecting
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: network.connected
                text: "Nodes: " + network.nodeCount
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
                text: "Host"
                onClicked: {
                    logMessage("Creating network...")
                    network.host()
                }
            }

            TextField {
                id: networkCodeInput
                placeholderText: "Network Code"
                Layout.preferredWidth: 120
                font.capitalization: Font.AllUppercase
                selectByMouse: true

                // Enable standard keyboard shortcuts
                Keys.onPressed: (event) => {
                    if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier) {
                        if (event.key === Qt.Key_V) {
                            paste()
                            event.accepted = true
                        } else if (event.key === Qt.Key_C) {
                            copy()
                            event.accepted = true
                        } else if (event.key === Qt.Key_A) {
                            selectAll()
                            event.accepted = true
                        }
                    }
                }
            }

            Button {
                text: "Join"
                enabled: networkCodeInput.text.length >= 4
                onClicked: {
                    logMessage("Joining network: " + networkCodeInput.text.toUpperCase())
                    network.join(networkCodeInput.text)
                }
            }
        }

        // Leave button and chat
        RowLayout {
            Layout.fillWidth: true
            visible: network.connected

            Button {
                text: "Leave"
                onClicked: {
                    network.leave()
                    for (let id in remoteNodes) {
                        if (remoteNodes[id]) remoteNodes[id].destroy()
                    }
                    remoteNodes = {}
                }
            }

            Item { Layout.fillWidth: true }

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
                          ? "Click to move. WASD keys work too."
                          : "Host or Join a network to start"
                    color: "#666"
                    horizontalAlignment: Text.AlignHCenter
                    visible: !network.connected || network.nodeCount < 2
                }

                Rectangle {
                    id: localNode
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
                        root.forceActiveFocus()
                        localNode.x = mouse.x - localNode.width / 2
                        localNode.y = mouse.y - localNode.height / 2
                    }
                }

                Component {
                    id: remoteNodeComp

                    Rectangle {
                        id: remoteNode
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

        Text {
            Layout.fillWidth: true
            text: "Press 'L' to toggle Clayground log overlay"
            font.pixelSize: 11
            color: "#999"
            horizontalAlignment: Text.AlignHCenter
        }
    }

    focus: true
    Keys.onPressed: (event) => {
        if (!network.connected) return
        let step = 10
        switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_A:
                localNode.x = Math.max(0, localNode.x - step)
                break
            case Qt.Key_Right:
            case Qt.Key_D:
                localNode.x = Math.min(gameArea.width - localNode.width, localNode.x + step)
                break
            case Qt.Key_Up:
            case Qt.Key_W:
                localNode.y = Math.max(0, localNode.y - step)
                break
            case Qt.Key_Down:
            case Qt.Key_S:
                localNode.y = Math.min(gameArea.height - localNode.height, localNode.y + step)
                break
        }
    }
}
