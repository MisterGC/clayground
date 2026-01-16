// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Clayground.Network

Rectangle {
    id: root
    color: "#f5f5f5"

    // Platform detection: LAN mode only available on native (not WASM)
    readonly property bool isWasm: Qt.platform.os === "wasm"
    property bool lanMode: false

    Network {
        id: network
        maxNodes: 4
        topology: Network.Topology.Star
        signalingMode: root.lanMode ? Network.SignalingMode.Local : Network.SignalingMode.Cloud

        onNetworkCreated: (networkId) => logMessage("Created: " + networkId)
        onNodeJoined: (nodeId) => logMessage("Joined: " + nodeId.substring(0, 8))
        onNodeLeft: (nodeId) => {
            logMessage("Left: " + nodeId.substring(0, 8))
            if (remoteNodes[nodeId]) {
                remoteNodes[nodeId].destroy()
                delete remoteNodes[nodeId]
            }
        }
        onMessageReceived: (fromId, data) => {
            if (data.type === "chat")
                logMessage("[" + fromId.substring(0, 4) + "] " + data.text)
        }
        onStateReceived: (fromId, data) => {
            if (data && typeof data.x === 'number')
                updateRemoteNode(fromId, data.x, data.y)
        }
        onErrorOccurred: (message) => logMessage("Error: " + message)
        onStatusChanged: logMessage("Status: " + ["Disconnected", "Connecting", "Connected", "Error"][network.status])
    }

    property var remoteNodes: ({})

    function updateRemoteNode(nodeId, x, y) {
        if (!remoteNodes[nodeId]) {
            remoteNodes[nodeId] = remoteNodeComp.createObject(gameArea, { odId: nodeId })
        }
        remoteNodes[nodeId].targetX = x
        remoteNodes[nodeId].targetY = y
    }

    function logMessage(msg) {
        logModel.append({ message: msg })
        if (logModel.count > 50) logModel.remove(0)
    }

    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: network.broadcastState({ x: localNode.x / gameArea.width, y: localNode.y / gameArea.height })
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header with mode switch (LAN only available on native platforms)
        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Text {
                text: root.lanMode ? "LAN" : "Internet"
                font.pixelSize: 18
                font.bold: true
                color: root.lanMode ? "#388e3c" : "#1976d2"
            }

            Switch {
                id: modeSwitch
                visible: !root.isWasm  // Hide on WASM - LAN not supported in browser
                text: "LAN"
                checked: root.lanMode
                enabled: !network.connected
                onCheckedChanged: root.lanMode = checked
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: network.connected
                text: network.nodeCount + " nodes"
                font.pixelSize: 14
                color: "#666"
            }
        }

        // Status + Network ID
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: {
                    switch (network.status) {
                        case Network.Status.Disconnected: return "Disconnected"
                        case Network.Status.Connecting: return "Connecting..."
                        case Network.Status.Connected: return network.isHost ? "Hosting:" : "Joined:"
                        case Network.Status.Error: return "Error"
                        default: return ""
                    }
                }
                font.pixelSize: 14
                color: network.status === Network.Status.Connected ? "#2e7d32" :
                       network.status === Network.Status.Error ? "#c62828" : "#666"
            }

            TextField {
                visible: network.connected
                text: network.networkId
                readOnly: true
                selectByMouse: true
                Layout.preferredWidth: 130
                font.pixelSize: 14
                font.family: "monospace"
                font.bold: true
                color: "#2e7d32"
                background: Rectangle { color: "#e8f5e9"; radius: 3 }
                onActiveFocusChanged: if (activeFocus) selectAll()
                TapHandler { onDoubleTapped: { parent.selectAll(); parent.copy(); logMessage("Copied!") } }
            }
        }

        // Controls (disconnected)
        RowLayout {
            Layout.fillWidth: true
            visible: !network.connected
            spacing: 10

            Button {
                text: "Host"
                onClicked: {
                    logMessage("Hosting" + (root.lanMode ? " (LAN)..." : "..."))
                    network.host()
                }
            }

            TextField {
                id: codeInput
                placeholderText: root.lanMode ? "LAN Code (L...)" : "Network Code"
                Layout.preferredWidth: 160
                font.capitalization: Font.AllUppercase
                selectByMouse: true
            }

            Button {
                text: "Join"
                enabled: codeInput.text.length >= 4
                onClicked: {
                    logMessage("Joining " + codeInput.text)
                    network.join(codeInput.text)
                }
            }
        }

        // Controls (connected)
        RowLayout {
            Layout.fillWidth: true
            visible: network.connected
            spacing: 10

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

            TextField {
                id: chatInput
                placeholderText: "Message..."
                Layout.fillWidth: true
                onAccepted: if (text.trim()) {
                    network.broadcast({ type: "chat", text: text })
                    logMessage("[You] " + text)
                    text = ""
                }
            }

            Button {
                text: "Send"
                onClicked: if (chatInput.text.trim()) {
                    network.broadcast({ type: "chat", text: chatInput.text })
                    logMessage("[You] " + chatInput.text)
                    chatInput.text = ""
                }
            }
        }

        // Game area and log
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                id: gameArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: root.lanMode ? "#e8f5e9" : "#e3f2fd"
                border.color: root.lanMode ? "#a5d6a7" : "#90caf9"
                border.width: 2
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: network.connected ? "Click to move" : "Host or Join a network"
                    color: "#888"
                    visible: !network.connected || network.nodeCount < 2
                }

                Rectangle {
                    id: localNode
                    width: 30; height: 30; radius: 15
                    color: root.lanMode ? "#388e3c" : "#1976d2"
                    border.color: root.lanMode ? "#1b5e20" : "#0d47a1"
                    border.width: 2
                    visible: network.connected
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height / 2
                    Behavior on x { NumberAnimation { duration: 100 } }
                    Behavior on y { NumberAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "You"; color: "white"; font.pixelSize: 8; font.bold: true }
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
                        property string odId: ""
                        property real targetX: 0.5
                        property real targetY: 0.5
                        width: 30; height: 30; radius: 15
                        color: "#e65100"
                        border.color: "#bf360c"
                        border.width: 2
                        x: targetX * parent.width - width / 2
                        y: targetY * parent.height - height / 2
                        Behavior on x { NumberAnimation { duration: 80 } }
                        Behavior on y { NumberAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: odId.substring(0, 2); color: "white"; font.pixelSize: 8; font.bold: true }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 220
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
