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

    function test_session_time_zero_is_a_send_time() {
        // The host's first state goes out at session time 0
        stubNet.sessionTime = 80
        let a = make({network: stubNet, nodeId: "A"})
        a.push({x: 1}, 0)
        compare(a.clockOffsetMs, 80)
        verify(a.active)
    }
}
