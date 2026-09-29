// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Net Gym - deterministic sandbox for multiplayer state-sync verification.
// Driven by run_net_gym.py through the inspector protocol: one instance
// hosts, others join, everyone broadcasts a deterministic moving value at
// 20 Hz and interpolates a chosen sender's stream. The receiving side can
// hold or jitter the tracked stream to exercise the interpolator.

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
    readonly property int status: net.status
    readonly property var nodeList: net.nodes
    property string lastError: ""

    // Interpolated view on trackedSender's stream (-1 until data flows)
    property string trackedSender: ""
    readonly property real remoteX: sync.active && sync.value.x !== undefined
                                    ? sync.value.x : -1
    readonly property var syncRef: sync

    // Fault injection on the tracked stream (receiver side)
    property bool useSentAt: true     // hand the sender timestamp to the interpolator
    property int stallMs: 0           // > 0: hold updates, release them in one burst every stallMs
    property int jitterMs: 0          // > 0: delay each update by a random 0..jitterMs
    property var held: []

    // Fastest movement of remoteX seen since resetSpeedStats(), in Wu/s
    // (the emitter itself moves at 10 Wu/s; its wrap at 100 is skipped)
    property real maxObservedSpeed: 0
    property real _lastX: -1
    property real _lastT: 0
    function resetSpeedStats() { maxObservedSpeed = 0; _lastX = -1; _lastT = 0 }

    function hostUp() {
        net.signalingMode = Network.SignalingMode.Local
        net.host()
    }
    function joinNet(code) { lastError = ""; net.join(code) }
    function trackSender(id) {
        gym.trackedSender = id; sync.reset(); held = []; resetSpeedStats()
    }
    function feed(data, sentAt) { sync.push(data, gym.useSentAt ? sentAt : undefined) }

    Network {
        id: net
        maxNodes: 4
        topology: Network.Topology.Star
        onStateReceived: (from, data, sentAt) => {
            if (from !== gym.trackedSender) return
            if (gym.stallMs > 0 || gym.jitterMs > 0) {
                let release = Date.now() + (gym.jitterMs > 0 ? Math.random() * gym.jitterMs : 0)
                gym.held.push({d: data, sa: sentAt, at: release})
                return
            }
            gym.feed(data, sentAt)
        }
        onErrorOccurred: (message) => gym.lastError = message
    }

    StateInterpolator {
        id: sync
        onUpdated: {
            let now = Date.now()
            let x = value.x
            if (gym._lastT > 0 && x !== undefined) {
                let dx = Math.abs(x - gym._lastX)
                let dt = now - gym._lastT
                if (dx < 50 && dt > 0)
                    gym.maxObservedSpeed = Math.max(gym.maxObservedSpeed, dx / dt * 1000)
            }
            gym._lastX = x; gym._lastT = now
        }
    }

    // Burst release (stall) and jitter release run off the same timer
    Timer {
        interval: gym.stallMs > 0 ? gym.stallMs : 4
        repeat: true
        running: gym.stallMs > 0 || gym.jitterMs > 0
        onTriggered: {
            let now = Date.now()
            let h = gym.held
            if (gym.stallMs > 0) {
                for (let i = 0; i < h.length; ++i) gym.feed(h[i].d, h[i].sa)
                gym.held = []
                return
            }
            h.sort((a, b) => a.at - b.at)
            while (h.length > 0 && h[0].at <= now) {
                let e = h.shift()
                gym.feed(e.d, e.sa)
            }
        }
    }

    Timer {
        interval: 50; repeat: true
        running: net.connected
        onTriggered: net.broadcastState({x: gym.emitterX})
    }

    // Expose network internals to the test driver
    readonly property var netRef: net
}
