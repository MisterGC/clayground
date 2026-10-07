// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ReplicatedObject and Replicas against a stub network (#306).
//
// The stub keeps an object table and records what goes out: an owner's
// ReplicatedObject sends its properties when they change - once per pass
// of the event loop, or once per sendInterval - and, when they rest for
// settleMs, once more as a settled state; anyone else's applies what the
// Network hands it, numbers and strings alike, and starts from the
// object's last state. Replicas makes a delegate per object of its type,
// with the spawn props, and destroys it on despawn. No built module is
// needed, so this runs on Windows too (#192).

import QtQuick
import QtTest
import "../.."

TestCase {
    id: tc
    name: "ReplicatedObject"
    when: windowShown

    QtObject {
        id: stubNet
        property string nodeId: "me"
        property real sessionTime: 1000
        property var table: ({})
        property var sent: []
        property var settled: []
        property var _replicas: ({})
        signal objectSpawned(string id, string type, string owner, var props)
        signal objectDespawned(string id, string type)

        function transitMs(nodeId) { return 20 }
        function objectInfo(id) { return table[id] || ({}) }
        function objects() { return Object.keys(table).map(id => table[id]) }
        function sendObjectState(id, data) { sent.push({id: id, data: data}) }
        function settleObjectState(id, data) { settled.push({id: id, data: data}) }
        function _attach(id, r) { _replicas[id] = r }
        function _detach(id, r) { if (_replicas[id] === r) delete _replicas[id] }

        // What Network does when the backend reports these
        function spawn(id, type, owner, props, state) {
            const o = {id: id, type: type, owner: owner, props: props || {}}
            if (state)
                o.state = state
            table[id] = o
            objectSpawned(id, type, owner, o.props)
        }
        function despawn(id) {
            const o = table[id]
            delete table[id]
            if (_replicas[id])
                _replicas[id]._despawned()
            objectDespawned(id, o.type)
        }
        function receive(id, data, sentAt) {
            if (_replicas[id])
                _replicas[id]._receive(data, sentAt)
        }
        function changeOwner(id, owner) {
            table[id].owner = owner
            if (_replicas[id])
                _replicas[id]._setOwner(owner)
        }
    }

    Component {
        id: ballComp
        Item {
            id: ball
            property string objectId: ""
            property string mood: "calm"
            property alias replica: rep
            ReplicatedObject {
                id: rep
                network: stubNet
                objectId: ball.objectId
                properties: ["x", "y", "mood"]
                settleMs: 50
            }
        }
    }

    Component {
        id: replicasComp
        Item {
            property alias replicas: reps
            Replicas {
                id: reps
                network: stubNet
                type: "ball"
                delegate: Item {
                    required property string objectId
                    required property int spawnIndex
                }
            }
        }
    }

    function init() {
        stubNet.table = {}
        stubNet.sent = []
        stubNet.settled = []
        stubNet._replicas = {}
        stubNet.nodeId = "me"
    }

    function test_the_owner_sends_once_per_pass_and_settles_when_it_rests() {
        stubNet.spawn("me:1", "ball", "me", {})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "me:1"})
        verify(ball.replica.isOwner)
        // Becoming owner, it speaks for the object once
        compare(stubNet.sent.length, 1)
        ball.x = 5
        ball.y = 6
        ball.mood = "angry"
        compare(stubNet.sent.length, 1)
        tryCompare(stubNet.sent, "length", 2)
        compare(stubNet.sent[1].data.x, 5)
        compare(stubNet.sent[1].data.y, 6)
        compare(stubNet.sent[1].data.mood, "angry")
        // At rest, the last state goes once more, reliably
        tryCompare(stubNet.settled, "length", 1)
        compare(stubNet.settled[0].data.mood, "angry")
        wait(120)
        compare(stubNet.settled.length, 1)
        // What arrives for its own object, it does not apply
        stubNet.receive("me:1", {x: 99, y: 99, mood: "x"}, 900)
        compare(ball.x, 5)
    }

    function test_a_send_interval_spaces_the_states() {
        stubNet.spawn("me:2", "ball", "me", {})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "me:2"})
        ball.replica.sendInterval = 100
        stubNet.sent = []
        for (let i = 1; i <= 10; ++i)
            ball.x = i
        // The first at once, the rest held for the interval
        compare(stubNet.sent.length, 1)
        tryVerify(() => stubNet.sent.length >= 2)
        compare(stubNet.sent[1].data.x, 10)
        verify(!stubNet.sent[1].data["$rest"], "the held state is not a rest copy")
        // A slow machine may already see the stop copy that follows the
        // held state 1.5 intervals later; nothing else may follow it
        for (let i = 2; i < stubNet.sent.length; ++i)
            verify(stubNet.sent[i].data["$rest"], "only rest copies follow the held state")
    }

    function test_others_apply_the_owners_state_numbers_and_strings() {
        stubNet.spawn("A:1", "ball", "A", {})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "A:1"})
        verify(!ball.replica.isOwner)
        compare(ball.replica.owner, "A")
        stubNet.receive("A:1", {x: 3, y: 4, mood: "hunting"}, 990)
        compare(ball.x, 3)
        compare(ball.y, 4)
        compare(ball.mood, "hunting")
        // A state without a property leaves it as it is
        stubNet.receive("A:1", {x: 7}, 995)
        compare(ball.x, 7)
        compare(ball.mood, "hunting")
        // Applying sends nothing
        wait(80)
        compare(stubNet.sent.length, 0)
        compare(stubNet.settled.length, 0)
    }

    function test_interpolated_strings_switch_with_their_snapshot() {
        stubNet.spawn("A:3", "ball", "A", {})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "A:3"})
        ball.replica.interpolate = true
        ball.replica.interpolator.delayMs = 0
        stubNet.receive("A:3", {x: 10, y: 0, mood: "hunting"}, stubNet.sessionTime - 20)
        tryCompare(ball, "mood", "hunting")
        compare(ball.x, 10)
    }

    function test_a_late_item_starts_from_the_last_state() {
        stubNet.spawn("A:4", "ball", "A", {}, {x: 42, y: 43, mood: "asleep"})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "A:4"})
        compare(ball.x, 42)
        compare(ball.y, 43)
        compare(ball.mood, "asleep")
    }

    function test_ownership_turns_sender_and_receiver_around() {
        stubNet.spawn("A:5", "ball", "A", {})
        const ball = createTemporaryObject(ballComp, tc, {objectId: "A:5"})
        verify(!ball.replica.isOwner)
        stubNet.changeOwner("A:5", "me")
        verify(ball.replica.isOwner)
        compare(stubNet.sent.length, 1)
        stubNet.changeOwner("A:5", "B")
        verify(!ball.replica.isOwner)
        stubNet.receive("A:5", {x: 8}, 990)
        compare(ball.x, 8)
        // Despawned, nobody owns it
        stubNet.despawn("A:5")
        compare(ball.replica.owner, "")
    }

    function test_replicas_make_and_destroy_an_item_per_object_of_their_type() {
        stubNet.spawn("A:6", "ball", "A", {spawnIndex: 1})
        stubNet.spawn("A:7", "wall", "A", {spawnIndex: 2})
        const holder = createTemporaryObject(replicasComp, tc)
        const reps = holder.replicas
        // What was there before it, it makes an item for too
        compare(reps.count, 1)
        compare(reps.itemFor("A:6").spawnIndex, 1)
        compare(reps.itemFor("A:6").parent, holder)
        verify(reps.itemFor("A:7") === null)
        stubNet.spawn("me:8", "ball", "me", {spawnIndex: 3})
        compare(reps.count, 2)
        compare(reps.itemFor("me:8").objectId, "me:8")
        compare(reps.itemFor("me:8").spawnIndex, 3)
        stubNet.despawn("A:6")
        compare(reps.count, 1)
        verify(reps.itemFor("A:6") === null)
        compare(reps.ids(), ["me:8"])
    }
}
