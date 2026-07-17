// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Net Gym - deterministic sandbox for multiplayer state-sync verification.
// Driven by run_net_gym.py through the inspector protocol: one instance
// hosts, others join, everyone broadcasts a deterministic moving value at
// 20 Hz and interpolates a chosen sender's stream.

import QtQuick
import Clayground.Network

Item {
    id: gym
    anchors.fill: parent

    // Deterministic motion source (10 Wu/s, wraps every 10s)
    property real emitterX: 0
    NumberAnimation on emitterX {
        from: 0; to: 100; duration: 10000
        loops: Animation.Infinite; running: true
    }

    readonly property string netId: net.networkId
    readonly property bool connected: net.connected
    readonly property var nodeList: net.nodes

    // Interpolated view on trackedSender's stream (-1 until data flows)
    property string trackedSender: ""
    readonly property real remoteX: sync.active && sync.value.x !== undefined
                                    ? sync.value.x : -1

    function hostUp() {
        net.signalingMode = Network.SignalingMode.Local
        net.host()
    }
    function joinNet(code) { net.join(code) }
    function trackSender(id) { gym.trackedSender = id; sync.reset() }

    Network {
        id: net
        maxNodes: 4
        topology: Network.Topology.Star
        onStateReceived: (from, data) => {
            if (from === gym.trackedSender) sync.push(data)
        }
    }

    StateInterpolator { id: sync }

    Timer {
        interval: 50; repeat: true
        running: net.connected
        onTriggered: net.broadcastState({x: gym.emitterX})
    }

    // Expose network internals to the test driver
    readonly property var netRef: net
}
