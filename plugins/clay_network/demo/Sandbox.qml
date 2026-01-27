// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief P2P multiplayer and HTTP client networking
// @tags Network, Multiplayer, HTTP

import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Clayground.Common
import Clayground.Network

Rectangle {
    id: root
    color: "#1a1a2e"

    // Clayground branding colors
    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"

    // Monospace font for retro feel
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Username for network display
    property string userName: "Player" + Math.floor(Math.random() * 90 + 10)

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
                logMessage("[" + (data.name || fromId.substring(0, 4)) + "] " + data.text)
        }
        onStateReceived: (fromId, data) => {
            if (data && typeof data.x === 'number')
                updateRemoteNode(fromId, data.x, data.y, data.name || fromId.substring(0, 4))
        }
        onErrorOccurred: (message) => logMessage("Error: " + message)
        onStatusChanged: logMessage("Status: " + ["Disconnected", "Connecting", "Connected", "Error"][network.status])
    }

    property var remoteNodes: ({})

    function updateRemoteNode(nodeId, x, y, name) {
        if (!remoteNodes[nodeId]) {
            remoteNodes[nodeId] = remoteNodeComp.createObject(gameArea, { odId: nodeId, nodeName: name })
        }
        remoteNodes[nodeId].targetX = x
        remoteNodes[nodeId].targetY = y
        remoteNodes[nodeId].nodeName = name
    }

    function logMessage(msg) {
        logModel.append({ message: msg })
        if (logModel.count > 50) logModel.remove(0)
    }

    Timer {
        interval: 50
        repeat: true
        running: network.connected
        onTriggered: network.broadcastState({
            x: localNode.x / gameArea.width,
            y: localNode.y / gameArea.height,
            name: root.userName.substring(0, 6)
        })
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
                font.family: root.monoFont
                font.pixelSize: 18
                font.bold: true
                color: root.accentColor
            }

            Switch {
                id: modeSwitch
                visible: !root.isWasm  // Hide on WASM - LAN not supported in browser
                checked: root.lanMode
                enabled: !network.connected
                onCheckedChanged: root.lanMode = checked

                indicator: Rectangle {
                    implicitWidth: 40
                    implicitHeight: 20
                    x: modeSwitch.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: 10
                    color: modeSwitch.checked ? root.accentColor : Qt.darker(root.surfaceColor, 1.3)
                    border.color: modeSwitch.checked ? Qt.darker(root.accentColor, 1.2) : root.dimTextColor

                    Rectangle {
                        x: modeSwitch.checked ? parent.width - width - 2 : 2
                        y: 2
                        width: 16
                        height: 16
                        radius: 8
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 100 } }
                    }
                }

                contentItem: Text {
                    text: "LAN"
                    font.family: root.monoFont
                    font.pixelSize: 12
                    color: root.dimTextColor
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: modeSwitch.indicator.width + 6
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: network.connected
                text: network.nodeCount + " nodes"
                font.family: root.monoFont
                font.pixelSize: 14
                color: root.dimTextColor
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
                font.family: root.monoFont
                font.pixelSize: 14
                color: network.status === Network.Status.Connected ? "#4ade80" :
                       network.status === Network.Status.Error ? "#ef4444" : root.textColor
            }

            TextField {
                visible: network.connected
                text: network.networkId
                readOnly: true
                selectByMouse: true
                Layout.preferredWidth: 130
                font.pixelSize: 14
                font.family: root.monoFont
                font.bold: true
                color: "#4ade80"
                background: Rectangle {
                    color: Qt.darker(root.surfaceColor, 1.3)
                    radius: 4
                    border.color: root.accentColor
                    border.width: 1
                }
                onActiveFocusChanged: if (activeFocus) selectAll()
                TapHandler { onDoubleTapped: { parent.selectAll(); parent.copy(); logMessage("Copied!") } }
            }
        }

        // Controls (disconnected)
        RowLayout {
            Layout.fillWidth: true
            visible: !network.connected
            spacing: 8

            TextField {
                id: nameInput
                text: root.userName
                placeholderText: "Name"
                Layout.preferredWidth: 80
                font.family: root.monoFont
                color: root.textColor
                placeholderTextColor: root.dimTextColor
                onTextChanged: root.userName = text
                background: Rectangle {
                    color: Qt.darker(root.surfaceColor, 1.3)
                    radius: 4
                    border.color: nameInput.focus ? root.accentColor : "transparent"
                    border.width: 1
                }
            }

            Button {
                text: "Host"
                onClicked: {
                    logMessage("Hosting" + (root.lanMode ? " (LAN)..." : "..."))
                    network.host()
                }
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    font.family: root.monoFont
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            TextField {
                id: codeInput
                placeholderText: root.lanMode ? "LAN Code" : "Code"
                Layout.preferredWidth: 100
                font.family: root.monoFont
                font.capitalization: Font.AllUppercase
                color: root.textColor
                placeholderTextColor: root.dimTextColor
                selectByMouse: true
                background: Rectangle {
                    color: Qt.darker(root.surfaceColor, 1.3)
                    radius: 4
                    border.color: codeInput.focus ? root.accentColor : "transparent"
                    border.width: 1
                }
            }

            Button {
                text: "Join"
                enabled: codeInput.text.length >= 4
                onClicked: {
                    logMessage("Joining " + codeInput.text)
                    network.join(codeInput.text)
                }
                background: Rectangle {
                    color: parent.enabled ?
                           (parent.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor) :
                           root.dimTextColor
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    font.family: root.monoFont
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Clipboard capability warning
        Text {
            Layout.fillWidth: true
            visible: !network.connected && Clayground.capabilities.clipboard.status !== "full"
            text: Clayground.capabilities.clipboard.hint
            font.family: root.monoFont
            font.pixelSize: 10
            color: "#f59e0b"
        }

        // Controls (connected) - just Leave button, chat moved to log panel
        RowLayout {
            Layout.fillWidth: true
            visible: network.connected
            spacing: 8

            Button {
                text: "Leave"
                onClicked: {
                    network.leave()
                    for (let id in remoteNodes) {
                        if (remoteNodes[id]) remoteNodes[id].destroy()
                    }
                    remoteNodes = {}
                }
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(root.surfaceColor, 1.5) : Qt.darker(root.surfaceColor, 1.3)
                    radius: 4
                    border.color: root.dimTextColor
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    font.family: root.monoFont
                    color: root.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Item { Layout.fillWidth: true }
        }

        // Game area and log with resizable splitter
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            handle: Rectangle {
                implicitWidth: 6
                color: SplitHandle.pressed ? root.accentColor :
                       SplitHandle.hovered ? Qt.lighter(root.surfaceColor, 1.3) : root.surfaceColor
            }

            Rectangle {
                id: gameArea
                SplitView.fillWidth: true
                SplitView.minimumWidth: 200
                color: root.surfaceColor
                border.color: root.accentColor
                border.width: 2
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: network.connected ? "Click to move" : "Host or Join a network"
                    font.family: root.monoFont
                    color: root.dimTextColor
                    visible: !network.connected || network.nodeCount < 2
                }

                Rectangle {
                    id: localNode
                    width: 30; height: 30; radius: 15
                    color: root.accentColor
                    border.color: Qt.darker(root.accentColor, 1.3)
                    border.width: 2
                    visible: network.connected
                    x: parent.width / 2 - width / 2
                    y: parent.height / 2 - height / 2
                    Behavior on x { NumberAnimation { duration: 100 } }
                    Behavior on y { NumberAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: root.userName.substring(0, 4)
                        font.family: root.monoFont
                        font.pixelSize: 8
                        font.bold: true
                        color: "white"
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
                        property string odId: ""
                        property string nodeName: ""
                        property real targetX: 0.5
                        property real targetY: 0.5
                        width: 30; height: 30; radius: 15
                        color: "#ff6b35"
                        border.color: "#cc5429"
                        border.width: 2
                        x: targetX * parent.width - width / 2
                        y: targetY * parent.height - height / 2
                        Behavior on x { NumberAnimation { duration: 80 } }
                        Behavior on y { NumberAnimation { duration: 80 } }
                        Text {
                            anchors.centerIn: parent
                            text: nodeName.substring(0, 4) || odId.substring(0, 2)
                            font.family: root.monoFont
                            font.pixelSize: 8
                            font.bold: true
                            color: "white"
                        }
                    }
                }
            }

            Rectangle {
                SplitView.preferredWidth: 250
                SplitView.minimumWidth: 180
                color: root.surfaceColor
                border.color: Qt.darker(root.surfaceColor, 0.8)
                border.width: 1
                radius: 4

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 5

                    Text {
                        text: "Chat"
                        font.family: root.monoFont
                        font.bold: true
                        font.pixelSize: 12
                        color: root.textColor
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
                            font.family: root.monoFont
                            font.pixelSize: 11
                            color: root.dimTextColor
                        }
                        onCountChanged: positionViewAtEnd()
                    }

                    // Chat input at bottom
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        visible: network.connected

                        TextField {
                            id: chatInput
                            placeholderText: "Message..."
                            Layout.fillWidth: true
                            font.family: root.monoFont
                            font.pixelSize: 11
                            color: root.textColor
                            placeholderTextColor: root.dimTextColor
                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                border.color: chatInput.focus ? root.accentColor : "transparent"
                                border.width: 1
                            }
                            onAccepted: if (text.trim()) {
                                network.broadcast({ type: "chat", text: text, name: root.userName.substring(0, 6) })
                                logMessage("[" + root.userName.substring(0, 6) + "] " + text)
                                text = ""
                            }
                        }

                        Button {
                            text: "▶"
                            implicitWidth: 32
                            onClicked: if (chatInput.text.trim()) {
                                network.broadcast({ type: "chat", text: chatInput.text, name: root.userName.substring(0, 6) })
                                logMessage("[" + root.userName.substring(0, 6) + "] " + chatInput.text)
                                chatInput.text = ""
                            }
                            background: Rectangle {
                                color: parent.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor
                                radius: 4
                            }
                            contentItem: Text {
                                text: parent.text
                                font.family: root.monoFont
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Press 'L' to toggle Clayground log overlay"
            font.family: root.monoFont
            font.pixelSize: 11
            color: root.dimTextColor
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
