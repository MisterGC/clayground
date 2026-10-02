// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// StateInterpolator against a stub network (#304).
//
// Given a network and a nodeId, an interpolator takes the clock offset of
// that node's stream from Network.transitMs - estimated once per sender -
// and keeps no estimate of its own: two interpolators on one sender, fed
// states that would each give another estimate, both report the network's.
// Without a network each one estimates on the wall clock, as before. The
// stub answers sessionTime and transitMs and nothing else, so this needs no
// built module and runs on Windows (#192).
//
// Cheap with many of them (#305): an interpolator whose value has come to
// rest stops its frame loop until the next push, and blending hands out
// one of two value objects in turn rather than a new one per frame. The
// stub's session time only moves when a test moves it, so a test decides
// where on the buffer the interpolator renders.

import QtQuick
import QtTest
import "../.."

TestCase {
    id: tc
    name: "StateInterpolatorSessionClock"

    QtObject {
        id: stubNet
        property real sessionTime: 10000
        property var transit: ({A: 80})
        function transitMs(nodeId) {
            return transit[nodeId] !== undefined ? transit[nodeId] : NaN
        }
    }

    Component {
        id: interpComp
        StateInterpolator {}
    }

    function make(props) {
        let i = createTemporaryObject(interpComp, tc, props)
        verify(i !== null)
        return i
    }

    function init() {
        stubNet.sessionTime = 10000
        stubNet.transit = {A: 80}
    }

    function test_two_interpolators_take_the_senders_offset_from_the_network() {
        let a = make({network: stubNet, nodeId: "A"})
        let b = make({network: stubNet, nodeId: "A"})
        // Arrived 30 and 50 ms after they were sent: on their own the two
        // would estimate 30 and 50
        a.push({x: 1}, stubNet.sessionTime - 30)
        b.push({x: 1}, stubNet.sessionTime - 50)
        compare(a.clockOffsetMs, 80)
        compare(b.clockOffsetMs, 80)
        // The network's estimate moves, both follow with their next push
        stubNet.transit = {A: 95}
        stubNet.sessionTime += 50
        a.push({x: 2}, stubNet.sessionTime - 10)
        b.push({x: 2}, stubNet.sessionTime - 70)
        compare(a.clockOffsetMs, 95)
        compare(b.clockOffsetMs, 95)
    }

    function test_without_a_network_each_estimates_its_own() {
        let a = make({})
        let now = Date.now()
        a.push({x: 1}, now - 40)
        verify(a.clockOffsetMs >= 40 && a.clockOffsetMs < 60, "offset " + a.clockOffsetMs)
    }

    function test_a_network_without_node_estimates_on_the_session_clock() {
        // No nodeId: the network's clock, but the interpolator's estimate
        let a = make({network: stubNet})
        a.push({x: 1}, stubNet.sessionTime - 30)
        compare(a.clockOffsetMs, 30)
    }

    function test_an_unknown_sender_falls_back_to_its_own_estimate() {
        let a = make({network: stubNet, nodeId: "Z"})
        a.push({x: 1}, stubNet.sessionTime - 25)
        compare(a.clockOffsetMs, 25)
    }

    // The interpolator's frame loop, found among its children
    function frameLoop(i) {
        for (let k = 0; k < i.data.length; ++k)
            if (i.data[k].frameTime !== undefined) return i.data[k]
        return null
    }

    // Two snapshots 50 ms apart, rendered (delay 120) halfway between them
    function blending(props) {
        let i = make(Object.assign({network: stubNet, nodeId: "A"}, props || {}))
        stubNet.sessionTime = 10000
        // transit 80: t = 9880 and 9930
        i.push({x: 0, y: 4}, 9800)
        i.push({x: 10, y: 8}, 9850)
        stubNet.sessionTime = 9905 + 120
        return i
    }

    function test_a_resting_value_stops_the_frame_loop() {
        let i = blending()
        let loop = frameLoop(i)
        verify(loop !== null)
        tryVerify(() => i.value.x === 5, 1000, "blends halfway: " + JSON.stringify(i.value))
        verify(loop.running)
        // Past the newest snapshot by the extrapolation: the value rests
        stubNet.sessionTime = 9930 + 120 + i.maxExtrapolationMs
        tryVerify(() => !loop.running, 1000)
        // Extrapolated by 200 ms at 10 per 50 ms
        compare(i.value.x, 50)
        let updates = 0
        let count = () => updates++
        i.updated.connect(count)
        wait(100)
        i.updated.disconnect(count)
        compare(updates, 0)
    }

    function test_a_single_snapshot_rests_at_once() {
        let i = make({network: stubNet, nodeId: "A"})
        let loop = frameLoop(i)
        i.push({x: 3}, stubNet.sessionTime - 80)
        verify(loop.running)
        tryVerify(() => !loop.running, 1000)
        compare(i.value.x, 3)
    }

    function test_a_push_starts_the_loop_again() {
        let i = blending()
        let loop = frameLoop(i)
        stubNet.sessionTime = 9930 + 120 + i.maxExtrapolationMs
        tryVerify(() => !loop.running, 1000)
        i.push({x: 20, y: 12}, 9900)
        verify(loop.running)
        // t = 9980: renders halfway between x 10 and 20 at 9955
        stubNet.sessionTime = 9955 + 120
        tryVerify(() => i.value.x === 15, 1000, JSON.stringify(i.value))
        verify(loop.running)
    }

    function test_no_value_object_per_frame() {
        let i = blending()
        let seen = []
        let note = () => { if (seen.indexOf(i.value) < 0) seen.push(i.value) }
        i.updated.connect(note)
        // The session clock moves on every frame, the value with it
        let loop = frameLoop(i)
        let step = () => stubNet.sessionTime += 1
        loop.triggered.connect(step)
        wait(200)
        loop.triggered.disconnect(step)
        i.updated.disconnect(note)
        verify(loop.running)
        verify(seen.length === 2, seen.length + " value objects")
        fuzzyCompare(i.value.y, 4 + i.value.x * 0.4, 1e-9)
    }

    function test_angles_blend_the_short_way_after_angle_keys_change() {
        let i = make({network: stubNet, nodeId: "A"})
        stubNet.sessionTime = 10000
        i.push({a: 350}, 9800)
        i.push({a: 10}, 9850)
        stubNet.sessionTime = 9905 + 120
        tryVerify(() => i.value.a === 180, 1000, "the long way without angleKeys")
        i.angleKeys = ["a"]
        stubNet.sessionTime += 0.0001
        tryVerify(() => Math.abs(i.value.a - 360) < 0.01, 1000, JSON.stringify(i.value))
    }

    function test_a_new_key_reaches_the_value() {
        let i = blending()
        tryVerify(() => i.value.x === 5, 1000)
        i.push({x: 20, y: 12, hp: 3}, 9900)
        stubNet.sessionTime = 9955 + 120
        tryVerify(() => i.value.hp === 3 && i.value.x === 15, 1000, JSON.stringify(i.value))
    }

    function test_session_time_zero_is_a_send_time() {
        // The host's first state goes out at session time 0
        stubNet.sessionTime = 80
        let a = make({network: stubNet, nodeId: "A"})
        a.push({x: 1}, 0)
        compare(a.clockOffsetMs, 80)
        verify(a.active)
    }
}
