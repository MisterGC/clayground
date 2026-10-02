// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Net Gym - deterministic sandbox for multiplayer state-sync verification.
// Driven by run_net_gym.py through the inspector protocol, and in the
// browser by run_net_gym_web.py through web/Main.qml: one instance hosts,
// others join, everyone broadcasts a value that moves with the wall clock
// at 20 Hz and interpolates a chosen sender's stream. The receiving side
// can hold or jitter the tracked stream to exercise the interpolator, and
// Network.linkConditions puts any node behind a bad link (#301). How a node
// leaves, goes silent or loses signaling is timed here, on the page's own
// clock, so a driver's polling does not blur it (#299). Joining goes through
// the handshake: the room password, a joiner from another build, and the
// client token the host keeps (#323).

import QtQuick
import Clayground.Network

Item {
    id: gym
    anchors.fill: parent

    // Motion source: 10 Wu/s on the wall clock, the same function on every
    // instance - all of them run on one machine. A received x therefore
    // says which moment of the sender it shows: x * 100 is the sender's
    // Date.now() then, so the receiver measures its own lag in one place
    // instead of comparing two instances read at two different times.
    function senderX(t) { return t / 100 }

    readonly property string netId: net.networkId
    readonly property bool connected: net.connected
    readonly property int status: net.status
    readonly property var nodeList: net.nodes
    property string lastError: ""

    // Cloud signaling through this server (clay-dev-server) when set,
    // otherwise the host runs Local signaling
    property string signalingUrl: ""
    // The room password this node hosts with or joins with (#323)
    property string roomPassword: ""
    // Why the host refused this node's last join, "" if it did not
    property string refusedReason: ""

    // Every reliable message received, as {from, probe, i} - the sender
    // attribution checks look up their probes here, the link checks their
    // order
    property var msgLog: []
    // Every nodeLeft and nodeJoined, in order
    property var leftLog: []
    property var joinedLog: []
    // Leaving and signaling (#299), in Date.now() ms; 0 = not yet
    property int signalingLosses: 0
    property real leftAt: 0          // this node called leave()
    property real disconnectedAt: 0  // this node's status turned Disconnected
    // The last state or message from the host: it broadcasts at 20 Hz, so
    // this is when it went silent, on the receiver's own clock
    property real lastFromHostAt: 0
    function resetLogs() {
        leftLog = []; joinedLog = []; lastError = ""; refusedReason = ""
        signalingLosses = 0; leftAt = 0; disconnectedAt = 0
    }
    function leaveNow() { leftAt = Date.now(); net.leave() }
    // The link goes dark for exactly ms, timed here rather than by the driver
    function outage(ms) {
        net.linkConditions = ({blackout: true})
        _outageEnd.interval = ms
        _outageEnd.restart()
    }
    Timer { id: _outageEnd; onTriggered: net.linkConditions = ({}) }
    function msgsWithProbe(probe) {
        return JSON.stringify(msgLog.filter(m => m.probe === probe))
    }
    // n reliable messages to every node, numbered, so a receiver can tell
    // a lost or reordered one
    function sendProbes(probe, n) {
        for (let i = 0; i < n; ++i) net.broadcast({probe: probe, i: i})
    }

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
    // (the emitter itself moves at 10 Wu/s and only forward; any step
    // backwards - a re-stamped buffer - is skipped, it is not a speed)
    property real maxObservedSpeed: 0
    property real _lastX: -1
    property real _lastT: 0
    function resetSpeedStats() { maxObservedSpeed = 0; _lastX = -1; _lastT = 0 }

    // How far the interpolated view is behind the sender, every frame since
    // resetTrackStats(): lag is now minus the sender moment remoteX shows,
    // err is that minus what the interpolator means to show - its delay plus
    // its estimate of the transit (clockOffsetMs). A conditioned link moves
    // the lag, not err; err grows only when the view stalls or jumps.
    property var _trk: ({n: 0, maxAbsErr: 0, sumErr: 0, sumLag: 0, maxLag: 0})
    function resetTrackStats() { _trk = {n: 0, maxAbsErr: 0, sumErr: 0, sumLag: 0, maxLag: 0} }
    function trackStats() {
        let t = _trk
        return JSON.stringify({
            n: t.n, maxAbsErr: t.maxAbsErr, maxLag: t.maxLag,
            meanErr: t.n ? t.sumErr / t.n : 0, meanLag: t.n ? t.sumLag / t.n : 0,
            delayMs: sync.effectiveDelayMs, clockOffsetMs: sync.clockOffsetMs
        })
    }

    function hostUp() {
        resetLogs()
        net.signalingMode = gym.signalingUrl ? Network.SignalingMode.Cloud
                                             : Network.SignalingMode.Local
        net.host()
    }
    function joinNet(code) { resetLogs(); net.join(code) }
    function trackSender(id) {
        gym.trackedSender = id; sync.reset(); held = []; resetSpeedStats(); resetTrackStats()
    }
    function feed(data, sentAt) { sync.push(data, gym.useSentAt ? sentAt : undefined) }

    Network {
        id: net
        maxNodes: 4
        topology: Network.Topology.Star
        signalingUrl: gym.signalingUrl
        password: gym.roomPassword
        onStateReceived: (from, data, sentAt) => {
            if (from === net.hostId) gym.lastFromHostAt = Date.now()
            if (from !== gym.trackedSender) return
            if (gym.stallMs > 0 || gym.jitterMs > 0) {
                let release = Date.now() + (gym.jitterMs > 0 ? Math.random() * gym.jitterMs : 0)
                gym.held.push({d: data, sa: sentAt, at: release})
                return
            }
            gym.feed(data, sentAt)
        }
        onErrorOccurred: (message) => gym.lastError = message
        onJoinRefused: (reason, message) => gym.refusedReason = reason
        onNodeJoined: (nodeId) => gym.joinedLog = gym.joinedLog.concat([nodeId])
        onSignalingLost: gym.signalingLosses++
        onStatusChanged: if (status === Network.Status.Disconnected) gym.disconnectedAt = Date.now()
        onNodeLeft: (nodeId) => gym.leftLog = gym.leftLog.concat([nodeId])
        onMessageReceived: (from, data) => {
            if (from === net.hostId) gym.lastFromHostAt = Date.now()
            gym.msgLog = gym.msgLog.concat([{from: from, probe: data.probe, i: data.i}])
        }
    }

    StateInterpolator {
        id: sync
        onUpdated: {
            let now = Date.now()
            let x = value.x
            if (gym._lastT > 0 && x !== undefined) {
                let dx = x - gym._lastX
                let dt = now - gym._lastT
                if (dx >= 0 && dt > 0)
                    gym.maxObservedSpeed = Math.max(gym.maxObservedSpeed, dx / dt * 1000)
            }
            gym._lastX = x; gym._lastT = now

            if (x === undefined) return
            let lag = now - x * 100
            let err = lag - (sync.effectiveDelayMs + sync.clockOffsetMs)
            if (!isFinite(err)) return
            let t = gym._trk
            t.n++
            t.maxAbsErr = Math.max(t.maxAbsErr, Math.abs(err))
            t.sumErr += err
            t.sumLag += lag
            t.maxLag = Math.max(t.maxLag, lag)
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
        onTriggered: net.broadcastState({x: gym.senderX(Date.now())})
    }

    // Expose network internals to the test driver
    readonly property var netRef: net

    // The browser gym's stand-in for the inspector's eval (web/Main.qml):
    // an object made here is compiled in this file's context, so the
    // expression sees its ids and properties like an inspector eval does
    function evalInScope(expr) {
        let runner = Qt.createQmlObject(
            "import QtQml\nQtObject { function run() { return (" + expr + ") } }",
            gym, "gym-eval")
        try {
            return runner.run()
        } finally {
            runner.destroy()
        }
    }
}
