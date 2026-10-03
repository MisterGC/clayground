// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// An object that stops dead comes to rest on the other nodes where its
// owner stopped it (#367).
//
// Two stub networks, the owner's and a receiver's, joined by a link that
// hands each lossy and each settled state over after transitMs, stamped
// with the owner's session time like the Network does. The owner moves an
// item at a lunge's speed every frame and then stops it; the receiver
// shows it through the StateInterpolator with the default settleMs. Until
// the settle, the receiver must not carry the motion on past the stop:
// the largest overshoot it shows stays under 0.1 Wu. No built module is
// needed, so this runs on Windows too (#192).

import QtQuick
import QtTest
import "../.."

TestCase {
    id: tc
    name: "ReplicatedObjectStop"
    when: windowShown

    readonly property real t0: Date.now()
    readonly property int transitMs: 20

    // Every node runs on one clock here, as a session clock would make it
    function clock() { return Date.now() - t0 }

    QtObject {
        id: link
        property var queue: []
        function carry(to, id, data, settled) {
            queue.push({due: tc.clock() + tc.transitMs, to: to, id: id,
                        data: JSON.parse(JSON.stringify(data)),
                        sentAt: tc.clock(), settled: settled})
            deliver.start()
        }
    }
    Timer {
        id: deliver
        interval: 1
        repeat: true
        onTriggered: {
            ownerNet.sessionTime = tc.clock()
            remoteNet.sessionTime = tc.clock()
            const now = tc.clock()
            while (link.queue.length > 0 && link.queue[0].due <= now) {
                const m = link.queue.shift()
                const r = m.to._replicas[m.id]
                if (r)
                    r._receive(m.data, m.sentAt)
            }
            if (link.queue.length === 0)
                stop()
        }
    }

    component StubNet: QtObject {
        property string nodeId: ""
        property real sessionTime: 0
        property var peer: null
        property var table: ({})
        property var _replicas: ({})
        property int lossy: 0
        property int settled: 0
        function transitMs(nodeId) { return tc.transitMs }
        function objectInfo(id) { return table[id] || ({}) }
        function sendObjectState(id, data) {
            ++lossy
            sessionTime = tc.clock()
            link.carry(peer, id, data, false)
        }
        function settleObjectState(id, data) {
            ++settled
            sessionTime = tc.clock()
            link.carry(peer, id, data, true)
        }
        function _attach(id, r) { _replicas[id] = r }
        function _detach(id, r) { if (_replicas[id] === r) delete _replicas[id] }
    }

    StubNet { id: ownerNet; nodeId: "A"; peer: remoteNet }
    StubNet { id: remoteNet; nodeId: "B"; peer: ownerNet }

    Component {
        id: bodyComp
        Item {
            id: body
            property alias net: rep.network
            property alias replica: rep
            ReplicatedObject {
                id: rep
                objectId: "A:1"
                properties: ["x", "y"]
                interpolate: true
            }
        }
    }

    // The owner's item moves at speed Wu/s, once per frame, for moveMs
    property var mover: null
    property real speed: 0
    property real startedAt: 0
    property int moveMs: 0
    FrameAnimation {
        id: motion
        running: false
        onTriggered: {
            // Not clamped to moveMs: the last step is a full one, at speed
            const t = tc.clock() - tc.startedAt
            tc.mover.x = tc.speed * t / 1000
            if (t >= tc.moveMs)
                running = false
        }
    }

    function init() {
        link.queue = []
        for (const n of [ownerNet, remoteNet]) {
            n.table = {"A:1": {id: "A:1", type: "body", owner: "A", props: {}}}
            n._replicas = {}
            n.lossy = 0
            n.settled = 0
            n.sessionTime = clock()
        }
    }

    // Moves the owner's item, stops it dead, and returns how far past the
    // stop the receiver showed it before the settle
    function overshootOfAStop(remoteSetup) {
        const owner = createTemporaryObject(bodyComp, tc, {net: ownerNet})
        const remote = createTemporaryObject(bodyComp, tc, {net: remoteNet})
        verify(owner.replica.isOwner)
        verify(!remote.replica.isOwner)
        compare(owner.replica.settleMs, 200)
        remoteSetup(remote.replica.interpolator)

        // A lunge: 6 Wu/s - 1.2 Wu in a settle of 200 ms
        mover = owner
        speed = 6
        moveMs = 600
        startedAt = clock()
        motion.running = true
        tryVerify(() => !motion.running, 2000)
        const stoppedAt = owner.x
        verify(stoppedAt > 3, "the owner moved " + stoppedAt)
        const settledBefore = ownerNet.settled

        // Follow the receiver until the settled state has arrived and
        // been shown: the largest x it reaches is the overshoot
        let most = remote.x
        const follow = () => { most = Math.max(most, remote.x) }
        remote.xChanged.connect(follow)
        tryVerify(() => ownerNet.settled > settledBefore, 1000)
        wait(remote.replica.interpolator.effectiveDelayMs + transitMs + 100)
        remote.xChanged.disconnect(follow)

        fuzzyCompare(remote.x, stoppedAt, 1e-6)
        return most - stoppedAt
    }

    function test_a_stop_overshoots_less_than_a_tenth_with_a_fixed_delay() {
        const over = overshootOfAStop(interp => {})
        console.log("fixed delay: overshoot " + over.toFixed(3) + " Wu")
        verify(over < 0.1, "overshoot " + over.toFixed(3) + " Wu")
    }

    function test_a_stop_overshoots_less_than_a_tenth_with_auto_delay() {
        const over = overshootOfAStop(interp => { interp.autoDelay = true })
        console.log("auto delay: overshoot " + over.toFixed(3) + " Wu")
        verify(over < 0.1, "overshoot " + over.toFixed(3) + " Wu")
    }
}
