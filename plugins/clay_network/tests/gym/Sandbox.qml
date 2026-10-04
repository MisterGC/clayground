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
// client token the host keeps (#323). Every node can stream keyed state
// for many objects at once, to show that one object's update never
// discards another's (#302). Every node reads the session clock against
// the wall clock all instances share, so a driver can tell how far apart
// their session times are, and every message carries its send time (#304).
// A node can show another's keyed objects through thirty interpolators at
// once and count what they do per frame (#305). Replicated objects (#306):
// the host runs thirty enemies at 20 Hz - a position and a mood string - a
// joiner runs its avatar, the host sets session properties, and every node
// reports what it shows of them. The tracked stream's gaps are kept, so a
// driver can tell a lost state from one the link held up (#307).

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
    // Losing the host (#376): hostLostReason as a handler on connected saw
    // it when connected turned false, and the reason hostLost() gave
    property string reasonAtDisconnect: ""
    property string lostReason: ""

    // Every reliable message received, as {from, probe, i, st, sentAt, at} -
    // the sender attribution checks look up their probes here, the link
    // checks their order. st is the sender's session time when it sent the
    // probe, sentAt what messageReceived said, at the session time here on
    // arrival (#304).
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
        reasonAtDisconnect = ""; lostReason = ""
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
        for (let i = 0; i < n; ++i) net.broadcast({probe: probe, i: i, st: net.sessionTime})
    }
    // This node's session time and the shared wall clock, read together:
    // on one machine, s - w is the same on every node whose session clock
    // agrees with the host's (#304)
    function clockReading() {
        return JSON.stringify({s: net.sessionTime, w: Date.now(), synced: net.sessionTimeSynced})
    }

    // Keyed state (#302): keyedCount objects, each under its own key, sent
    // every keyedTimer.interval ms - all of one frame in the same handler,
    // so they leave as batches. keyedTick counts the frames sent; every
    // update carries its frame. A receiver keeps per sender and key how
    // many arrived (n), the newest frame (last) and how often an update
    // was older than one before it (back) - the seq guard makes that 0.
    property int keyedCount: 0
    property int keyedTick: 0
    property var keyedSeen: ({})
    function resetKeyed() { keyedTimer.stop(); keyedTick = 0; keyedSeen = {} }
    function startKeyed(n, hz) {
        keyedCount = n
        keyedTimer.interval = Math.round(1000 / hz)
        keyedTimer.start()
    }
    function stopKeyed() { keyedTimer.stop() }
    function keyedReport() {
        let out = {}
        for (let from in keyedSeen) {
            let ks = Object.values(keyedSeen[from])
            out[from] = {
                keys: ks.length,
                minN: Math.min(...ks.map(k => k.n)), maxN: Math.max(...ks.map(k => k.n)),
                minLast: Math.min(...ks.map(k => k.last)),
                back: ks.reduce((a, k) => a + k.back, 0)
            }
        }
        return JSON.stringify(out)
    }
    Timer {
        id: keyedTimer
        repeat: true
        onTriggered: {
            for (let k = 0; k < gym.keyedCount; ++k)
                net.broadcastState({i: gym.keyedTick, o: k}, "obj" + k)
            gym.keyedTick++
        }
    }

    // Thirty interpolators (#305): interpCount of them, the k-th fed with
    // interpSender's keyed state "obj<k>". Each counts the updated() it
    // emitted and how many of them handed out a value object that was
    // neither of the two before it - an object made per frame shows there.
    property int interpCount: 0
    property string interpSender: ""
    function resetInterpCounts() {
        for (let k = 0; k < interpRep.count; ++k) {
            let it = interpRep.itemAt(k)
            it.updates = 0; it.fresh = 0; it.pushes = 0
        }
    }
    function interpReport() {
        let r = {n: interpRep.count, updates: 0, fresh: 0, pushes: 0, minUpdates: -1}
        for (let k = 0; k < interpRep.count; ++k) {
            let it = interpRep.itemAt(k)
            r.updates += it.updates; r.fresh += it.fresh; r.pushes += it.pushes
            r.minUpdates = r.minUpdates < 0 ? it.updates : Math.min(r.minUpdates, it.updates)
        }
        return JSON.stringify(r)
    }
    Repeater {
        id: interpRep
        model: gym.interpCount
        delegate: StateInterpolator {
            network: net
            nodeId: gym.interpSender
            property int updates: 0
            property int fresh: 0
            property int pushes: 0
            property var _seen1: null
            property var _seen2: null
            onUpdated: {
                updates++
                if (value !== _seen1 && value !== _seen2) fresh++
                _seen2 = _seen1; _seen1 = value
            }
        }
    }

    // Replicated objects (#306): enemies the host spawns and moves, at
    // 20 Hz with a mood that changes every second; an avatar a joiner
    // spawns and moves, which passes to the host when the joiner leaves.
    // Both are moved on the wall clock, so their owners agree on where they
    // are without asking each other.
    property bool objectsMoving: false
    function enemyX(i, t) { return gym.senderX(t) + i }
    function enemyMood(i, t) { return (Math.floor(t / 1000) + i) % 3 === 0 ? "hunting" : "idle" }
    function spawnEnemies(n) {
        for (let i = 0; i < n; ++i)
            net.spawn("gymEnemy", {spawnIndex: i}, {onOwnerLeft: "despawn"})
    }
    function spawnAvatar() {
        return net.spawn("gymAvatar", {token: net.clientToken}, {onOwnerLeft: "host"})
    }
    function despawnAll(type) {
        for (const o of net.objects(type))
            net.despawn(o.id)
    }
    // What this node shows of every object, by id
    function objectsReport() {
        let out = {}
        for (const r of [enemies, avatars])
            for (const id of r.ids()) {
                const it = r.itemFor(id)
                out[id] = {type: r.type, owner: it.rep.owner, x: it.x, mood: it.mood,
                           spawnIndex: it.spawnIndex, token: it.token}
            }
        return JSON.stringify({objects: out, session: net.sessionProperties,
                               seqEntries: net._objectSequenceEntries()})
    }
    Timer {
        interval: 50; repeat: true
        running: gym.objectsMoving
        onTriggered: {
            const t = Date.now()
            for (const id of enemies.ids()) {
                const e = enemies.itemFor(id)
                if (e.rep.isOwner) { e.x = gym.enemyX(e.spawnIndex, t); e.mood = gym.enemyMood(e.spawnIndex, t) }
            }
            for (const id of avatars.ids()) {
                const a = avatars.itemFor(id)
                if (a.rep.isOwner) { a.x = gym.senderX(t); a.mood = "walking" }
            }
        }
    }
    Component {
        id: replicaDelegate
        Item {
            id: obj
            required property string objectId
            property int spawnIndex: -1
            property string token: ""
            property string mood: ""
            property alias rep: rep
            ReplicatedObject {
                id: rep
                network: net
                objectId: obj.objectId
                properties: ["x", "mood"]
                interpolate: true
                settleMs: 150
            }
        }
    }
    Replicas { id: enemies; network: net; type: "gymEnemy"; delegate: replicaDelegate }
    Replicas { id: avatars; network: net; type: "gymAvatar"; delegate: replicaDelegate }

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
    // its estimate of the transit (transitMs()). A conditioned link moves
    // the lag, not err; err grows only when the view stalls or jumps.
    property var _trk: ({n: 0, maxAbsErr: 0, sumErr: 0, sumLag: 0, maxLag: 0})

    // Gaps in the tracked stream (#307): for every state that arrives, the
    // ms since the state before it arrived, and the ms between the two on
    // the sender's clock. The two differ by what the link did: a lossy
    // state channel loses a state and goes on with the next one, a channel
    // that retransmits holds the next one up behind it.
    readonly property int sendPeriodMs: 50
    property var _gaps: []
    property real _gapPrevAt: 0
    property real _gapPrevSent: 0
    function resetGapStats() { _gaps = []; _gapPrevAt = 0; _gapPrevSent = 0 }
    function _noteArrival(sentMoment) {
        const at = Date.now()
        if (_gapPrevAt > 0)
            _gaps.push([at - _gapPrevAt, sentMoment - _gapPrevSent])
        _gapPrevAt = at
        _gapPrevSent = sentMoment
    }
    function gapStats() { return JSON.stringify(_gaps) }
    // The interpolator's transit estimate. On the wall clock its offset
    // also holds how far this node's wall clock is from the session clock
    // the send times are on (#304)
    function transitMs() {
        return sync.network ? sync.clockOffsetMs
                            : sync.clockOffsetMs - (Date.now() - net.sessionTime)
    }
    function resetTrackStats() { _trk = {n: 0, maxAbsErr: 0, sumErr: 0, sumLag: 0, maxLag: 0} }
    function trackStats() {
        let t = _trk
        return JSON.stringify({
            n: t.n, maxAbsErr: t.maxAbsErr, maxLag: t.maxLag,
            meanErr: t.n ? t.sumErr / t.n : 0, meanLag: t.n ? t.sumLag / t.n : 0,
            delayMs: sync.effectiveDelayMs, clockOffsetMs: gym.transitMs()
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
    // The interpolator runs on the network's session clock and takes the
    // sender's offset from it (#304), unless a check turns that off
    property bool sharedClock: true
    function feed(data, sentAt) { sync.push(data, gym.useSentAt ? sentAt : undefined) }

    Network {
        id: net
        maxNodes: 4
        topology: Network.Topology.Star
        signalingUrl: gym.signalingUrl
        password: gym.roomPassword
        onStateReceived: (from, data, sentAt, key) => {
            if (from === net.hostId) gym.lastFromHostAt = Date.now()
            if (key !== "") {
                if (from === gym.interpSender && data.o < interpRep.count) {
                    let it = interpRep.itemAt(data.o)
                    it.pushes++
                    it.push(data, sentAt)
                }
                let seen = gym.keyedSeen[from] || (gym.keyedSeen[from] = {})
                let k = seen[key] || (seen[key] = {n: 0, last: -1, back: 0})
                if (data.i <= k.last) k.back++
                k.n++
                k.last = Math.max(k.last, data.i)
                return
            }
            if (from !== gym.trackedSender) return
            if (data.x !== undefined) gym._noteArrival(data.x * 100)
            if (gym.stallMs > 0 || gym.jitterMs > 0) {
                let release = Date.now() + (gym.jitterMs > 0 ? Math.random() * gym.jitterMs : 0)
                gym.held.push({d: data, sa: sentAt, at: release})
                return
            }
            gym.feed(data, sentAt)
        }
        onErrorOccurred: (message) => gym.lastError = message
        onJoinRefused: (reason, message) => gym.refusedReason = reason
        onHostLost: (reason, message) => gym.lostReason = reason
        onConnectedChanged: if (!connected) gym.reasonAtDisconnect = hostLostReason
        onNodeJoined: (nodeId) => gym.joinedLog = gym.joinedLog.concat([nodeId])
        onSignalingLost: gym.signalingLosses++
        onStatusChanged: if (status === Network.Status.Disconnected) gym.disconnectedAt = Date.now()
        onNodeLeft: (nodeId) => gym.leftLog = gym.leftLog.concat([nodeId])
        onMessageReceived: (from, data, sentAt) => {
            if (from === net.hostId) gym.lastFromHostAt = Date.now()
            gym.msgLog = gym.msgLog.concat([{from: from, probe: data.probe, i: data.i,
                                             st: data.st, sentAt: sentAt, at: net.sessionTime}])
        }
    }

    StateInterpolator {
        id: sync
        network: gym.sharedClock ? net : null
        nodeId: gym.trackedSender
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
            let err = lag - (sync.effectiveDelayMs + gym.transitMs())
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
        interval: gym.sendPeriodMs; repeat: true
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
