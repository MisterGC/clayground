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
//
// An object that moves, stops and is hit while it stands, again and again,
// keeps the auto delay it streams with on the receiver (#374).
//
// A health value in steppedProperties takes on the receiver only values
// the owner sent, and each at the render delay of the position it was sent
// with (#368): the owner drops it by 3 for every Wu it moves, and the
// receiver shows each value no earlier than the x of the first state that
// carried it - a value switched with the state before it, blended or not,
// would show with an x short of that. A hit while it stands arrives the
// same way.

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
        property var sentHp: []
        // The x of the first state that carried each HP
        property var hpSentAtX: ({})
        function carry(to, id, data, settled) {
            if (data.hp !== undefined && sentHp.indexOf(data.hp) < 0) {
                sentHp.push(data.hp)
                hpSentAtX[data.hp] = data.x
            }
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

    Component {
        id: fighterComp
        Item {
            id: fighter
            property real hp: 52
            property alias net: rep.network
            property alias replica: rep
            ReplicatedObject {
                id: rep
                objectId: "A:1"
                properties: ["x", "y", "hp"]
                steppedProperties: ["hp"]
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
            // A fighter loses 3 HP per Wu, in the frame it gets there
            if (tc.mover.hp !== undefined)
                tc.mover.hp = 52 - 3 * Math.floor(tc.mover.x)
            if (t >= tc.moveMs)
                running = false
        }
    }

    function init() {
        link.queue = []
        link.sentHp = []
        link.hpSentAtX = {}
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

    // The owner's item moves for a few frames, stops, is hit while it
    // stands (y jumps), stands again - five times over, like an enemy that
    // lunges and is hit (#374). Returns the receiver's auto delay target.
    function autoDelayOfAMoveStopAndHit() {
        const owner = createTemporaryObject(bodyComp, tc, {net: ownerNet})
        const remote = createTemporaryObject(bodyComp, tc, {net: remoteNet})
        const interp = remote.replica.interpolator
        interp.autoDelay = true
        mover = owner
        speed = 6
        let from = 0
        for (let round = 0; round < 5; ++round) {
            moveMs = 100
            startedAt = clock() - from * 1000 / speed
            motion.running = true
            tryVerify(() => !motion.running, 1000)
            from = owner.x
            // Past the stop and the settle
            wait(owner.replica.settleMs + 100)
            owner.y += 1
            wait(owner.replica.settleMs + 100)
        }
        tryVerify(() => link.queue.length === 0, 1000)
        // Turned off and on, the delay snaps to its target
        interp.autoDelay = false
        interp.autoDelay = true
        return interp.effectiveDelayMs
    }

    // Moves a fighter 3.6 Wu - HP 52, 49, 46, 43 on the way - stops it,
    // hits it once while it stands, and checks every HP the receiver showed
    function steppedHp(remoteSetup) {
        const owner = createTemporaryObject(fighterComp, tc, {net: ownerNet})
        const remote = createTemporaryObject(fighterComp, tc, {net: remoteNet})
        verify(!remote.replica.isOwner)
        const interp = remote.replica.interpolator
        remoteSetup(interp)
        compare(JSON.stringify(interp.stepKeys), JSON.stringify(["hp"]))

        // Each HP the receiver shows, with the x it shows with it: x is
        // applied before hp, both from one value of the interpolator
        const shown = []
        const note = () => shown.push({hp: remote.hp, x: remote.x})
        remote.hpChanged.connect(note)

        mover = owner
        speed = 6
        moveMs = 600
        startedAt = clock()
        motion.running = true
        tryVerify(() => !motion.running, 2000)
        compare(owner.hp, 52 - 3 * Math.floor(owner.x))
        wait(owner.replica.settleMs + 100)
        owner.hp = 40
        wait(owner.replica.settleMs + 100)
        tryVerify(() => link.queue.length === 0, 1000)
        wait(interp.effectiveDelayMs + interp.maxExtrapolationMs + 50)
        remote.hpChanged.disconnect(note)

        console.log("sent " + JSON.stringify(link.sentHp) + ", shown "
                    + JSON.stringify(shown.map(e => e.hp)))
        compare(remote.hp, 40)
        verify(shown.length >= 4, "the receiver showed " + JSON.stringify(shown))
        for (const e of shown) {
            verify(link.sentHp.indexOf(e.hp) >= 0,
                   "HP " + e.hp + " was never sent: " + JSON.stringify(link.sentHp))
            // Not before the position it was sent with
            verify(e.x >= link.hpSentAtX[e.hp] - 1e-9,
                   "HP " + e.hp + " shown at x " + e.x + ", sent at x "
                   + link.hpSentAtX[e.hp])
        }
    }

    function test_a_stepped_property_shows_only_sent_values_with_a_fixed_delay() {
        steppedHp(interp => {})
    }

    function test_a_stepped_property_shows_only_sent_values_with_auto_delay() {
        steppedHp(interp => { interp.autoDelay = true })
    }

    function test_an_object_that_stops_and_is_hit_keeps_its_streaming_delay() {
        const d = autoDelayOfAMoveStopAndHit()
        console.log("auto delay after five moves, stops and hits: " + d + " ms")
        // Two frame periods and the transit's jitter; the gaps around its
        // rests, taken for periods, made it two settles long
        verify(d < 100, "auto delay " + d + " ms")
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
