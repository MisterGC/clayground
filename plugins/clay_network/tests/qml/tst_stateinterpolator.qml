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
//
// The auto delay takes an object's rest for neither a period nor lateness
// (#366): after the gaps a stop leaves in the stream, it aims for its
// streaming value again within a few states. Nor does it take the copies
// of its last state a ReplicatedObject sends at a stop and a settle,
// marked $rest, or the gap from them to the next state, for periods
// (#374): an enemy that stops and is hit while it stands keeps the delay
// it streams with, and a sender that repeats its states unmarked is
// still measured by them.
//
// A number under one of the stepKeys is never blended (#368): it is the
// value of the newest snapshot at or before the render time, so a health
// value going 52 -> 49 shows 52 and then 49, never 50.5, at the delay the
// blended keys are shown with.

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

    // A health value going 52 -> 49 while x moves 0 -> 10 (#368)
    function hit(props) {
        let i = make(Object.assign({network: stubNet, nodeId: "A"}, props || {}))
        stubNet.sessionTime = 10000
        // transit 80: t = 9880 and 9930
        i.push({x: 0, hp: 52}, 9800)
        i.push({x: 10, hp: 49}, 9850)
        return i
    }

    function test_numbers_blend_without_step_keys() {
        let i = hit()
        stubNet.sessionTime = 9905 + 120
        tryVerify(() => i.value.x === 5, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 50.5)
    }

    function test_a_step_key_shows_only_pushed_numbers_at_the_render_delay() {
        let i = hit({stepKeys: ["hp"]})
        // Halfway between: x blends, hp is the earlier snapshot's
        stubNet.sessionTime = 9905 + 120
        tryVerify(() => i.value.x === 5, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 52)
        // A millisecond before the second snapshot, still the first's
        stubNet.sessionTime = 9929 + 120
        tryVerify(() => Math.abs(i.value.x - 9.8) < 1e-9, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 52)
        // On it, the second's
        stubNet.sessionTime = 9930 + 120
        tryVerify(() => i.value.x === 10, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 49)
        // Extrapolated past it, x moves on and hp holds
        stubNet.sessionTime = 9955 + 120
        tryVerify(() => i.value.x === 15, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 49)
    }

    function test_step_keys_apply_to_snapshots_already_pushed() {
        let i = hit()
        stubNet.sessionTime = 9905 + 120
        tryVerify(() => i.value.hp === 50.5, 1000, JSON.stringify(i.value))
        i.stepKeys = ["hp"]
        stubNet.sessionTime += 0.0001
        tryVerify(() => i.value.hp === 52, 1000, JSON.stringify(i.value))
        fuzzyCompare(i.value.x, 5, 1e-3)
    }

    function test_a_step_key_new_in_a_snapshot_shows_from_it() {
        // The earlier snapshot has no hp: the newer one's, not undefined
        let i = make({network: stubNet, nodeId: "A", stepKeys: ["hp"]})
        stubNet.sessionTime = 10000
        i.push({x: 0}, 9800)
        i.push({x: 10, hp: 49}, 9850)
        stubNet.sessionTime = 9905 + 120
        tryVerify(() => i.value.x === 5, 1000, JSON.stringify(i.value))
        compare(i.value.hp, 49)
    }

    function test_a_new_key_reaches_the_value() {
        let i = blending()
        tryVerify(() => i.value.x === 5, 1000)
        i.push({x: 20, y: 12, hp: 3}, 9900)
        stubNet.sessionTime = 9955 + 120
        tryVerify(() => i.value.hp === 3 && i.value.x === 15, 1000, JSON.stringify(i.value))
    }

    function test_auto_delay_forgets_the_clock_it_had_before() {
        // A few states on the wall clock, then the network's clock (#363):
        // the wall clock's stamps lie far ahead of session time, and a
        // window that kept them would never prune again - after 30 s of a
        // clean stream and 3 s of a late one it would still answer mostly
        // for the clean one
        let i = make({autoDelay: true})
        for (let k = 0; k < 3; ++k)
            i.push({x: k}, Date.now() - 30)
        i.network = stubNet
        i.nodeId = "A"
        let sent = 0
        let feed = (count, late) => {
            for (let k = 0; k < count; ++k) {
                sent += 50
                stubNet.sessionTime = sent + 80 + late(k)
                i.push({x: sent / 100}, sent)
            }
        }
        feed(600, () => 0)
        feed(60, k => (k * 37) % 120)
        // Turned on again, the delay starts at its target instead of
        // gliding there: 2 x 50 + the last 3 s' 95th percentile (112) + 4
        i.autoDelay = false
        i.autoDelay = true
        compare(i.effectiveDelayMs, 216)
    }

    // The auto delay's target, as turning it off and on again snaps to it
    function autoTarget(i) {
        i.autoDelay = false
        i.autoDelay = true
        return i.effectiveDelayMs
    }

    // A ReplicatedObject's stream at 60 Hz (#366): states every 16 ms while
    // it moves, the stop 1.5 periods after the last one, the settle 200 ms
    // after it, then nothing for 5 s until it moves again. Each arrives 80 ms
    // after it went. withSentAt false pushes on arrival time only.
    function restAndMoveAgain(withSentAt) {
        let i = make({network: stubNet, nodeId: "A", autoDelay: true})
        let sent = 0
        let send = (dt) => {
            sent += dt
            stubNet.sessionTime = sent + 80
            if (withSentAt) i.push({x: sent / 100}, sent)
            else i.push({x: sent / 100})
        }
        for (let k = 0; k < 200; ++k) send(16)
        let streaming = autoTarget(i)
        send(24)
        send(176)
        // The target with each of the first states after the rest
        let after = []
        send(5000)
        after.push(autoTarget(i))
        for (let k = 0; k < 3; ++k) {
            send(16)
            after.push(autoTarget(i))
        }
        return {streaming: streaming, after: after}
    }

    function test_auto_delay_takes_no_rest_for_a_period() {
        let r = restAndMoveAgain(true)
        // 2 x 16 + no lateness + 4
        compare(r.streaming, 36)
        compare(JSON.stringify(r.after), JSON.stringify([36, 36, 36, 36]))
    }

    function test_auto_delay_takes_no_rest_for_lateness() {
        // On arrival time, the first state after the rest arrived 5 s after
        // the one before - alone in the 3 s window, it would be the 95th
        // percentile of lateness
        let r = restAndMoveAgain(false)
        compare(r.streaming, 36)
        compare(JSON.stringify(r.after), JSON.stringify([36, 36, 36, 36]))
    }

    function test_auto_delay_follows_a_slower_sender_within_five_states() {
        let i = make({network: stubNet, nodeId: "A", autoDelay: true})
        let sent = 0
        for (let k = 0; k < 50; ++k) {
            sent += 16
            stubNet.sessionTime = sent + 80
            i.push({x: k}, sent)
        }
        for (let k = 0; k < 5; ++k) {
            sent += 50
            stubNet.sessionTime = sent + 80
            i.push({x: k}, sent)
        }
        compare(autoTarget(i), 2 * 50 + 4)
    }

    // A ReplicatedObject's stream of an enemy that moves, stops and is hit
    // (#374): states every period ms while it moves; at each stop the last
    // state once more 1.5 periods later and once more, settled, 200 ms
    // after the last motion - both copies marked $rest, as ReplicatedObject
    // sends them; a hit while it stands sends the changed HP, and that
    // state twice more the same way. Stops and hits outnumber the moving
    // states of the short bursts in between, so most intervals in the
    // stream are the gaps around a rest. clock is "shared" (the network's
    // offset for the sender), "own" (an unknown sender: the interpolator's
    // own offset on the session clock) or "arrival" (no sentAt). Returns
    // the highest target after any state past the first few hundred.
    function moveStopAndHit(clock, period) {
        let i = make({network: stubNet, nodeId: clock === "own" ? "B" : "A", autoDelay: true})
        let sent = 0
        let x = 0
        let hp = 50
        let send = (dt, copy) => {
            sent += dt
            stubNet.sessionTime = sent + 80
            let state = {x: x, hp: hp, ai: "chase"}
            if (copy) state["$rest"] = true
            if (clock === "arrival") i.push(state)
            else i.push(state, sent)
        }
        let rest = () => { send(1.5 * period, true); send(200 - 1.5 * period, true) }
        for (let k = 0; k < 200; ++k) { x += 0.1; send(period) }
        let most = 0
        for (let round = 0; round < 10; ++round) {
            rest()
            most = Math.max(most, autoTarget(i))
            hp -= 3
            send(300)
            rest()
            most = Math.max(most, autoTarget(i))
            for (let k = 0; k < 3; ++k) {
                x += 0.1
                send(k === 0 ? 400 : period)
                most = Math.max(most, autoTarget(i))
            }
        }
        verify(i.value["$rest"] === undefined, "the mark reached the value")
        return most
    }

    function test_auto_delay_takes_no_rest_of_an_object_that_stops_and_is_hit() {
        // 2 x 16 + no lateness + 4, as while it streams; the gaps around
        // its rests, taken for periods, made it 2 x 176 + 4 = 356
        compare(moveStopAndHit("shared", 16), 36)
    }

    function test_auto_delay_takes_no_rest_of_an_object_that_stops_and_is_hit_for_lateness() {
        compare(moveStopAndHit("arrival", 16), 36)
    }

    function test_auto_delay_takes_no_rest_of_an_object_that_stops_and_is_hit_on_its_own_clock() {
        compare(moveStopAndHit("own", 16), 36)
    }

    function test_auto_delay_takes_no_rest_of_a_sender_at_66_ms() {
        // A 15 Hz throttle: the stop comes 99 ms after the last motion, the
        // settle 101 ms after the stop - within a quarter of each other, so
        // a rule guessing copies from their rate took the settle for a
        // period. 2 x 66 + 4
        compare(moveStopAndHit("shared", 66), 136)
        compare(moveStopAndHit("arrival", 66), 136)
    }

    function test_auto_delay_takes_no_lone_change_for_a_period_at_the_settles_spacing() {
        // An enemy that stands and changes now and then - its AI state, a
        // drift of a thousandth: each change, its stop copy 24 ms and its
        // settle 176 ms later, the next change about a settle after that
        for (let withSentAt of [true, false]) {
            let i = make({network: stubNet, nodeId: "A", autoDelay: true})
            let sent = 0
            let x = 0
            let send = (dt, copy) => {
                sent += dt
                stubNet.sessionTime = sent + 80
                let state = copy ? {x: x, "$rest": true} : {x: x}
                if (withSentAt) i.push(state, sent)
                else i.push(state)
            }
            for (let k = 0; k < 200; ++k) { x += 0.1; send(16) }
            for (let k = 0; k < 20; ++k) {
                x += 0.001
                send(170 + (k % 3) * 10)
                send(24, true)
                send(176, true)
            }
            compare(autoTarget(i), 36, withSentAt ? "on send time" : "on arrival")
        }
    }

    function test_auto_delay_measures_a_sender_that_sends_each_state_twice() {
        // A frame loop that sends every 16 ms an object physics moves every
        // other frame: A, A, B, B, ... Each interval is a period
        for (let withSentAt of [true, false]) {
            let i = make({network: stubNet, nodeId: "A", autoDelay: true})
            let sent = 0
            for (let k = 0; k < 60; ++k) {
                sent += 16
                stubNet.sessionTime = sent + 80
                let state = {x: Math.floor(k / 2)}
                if (withSentAt) i.push(state, sent)
                else i.push(state)
            }
            compare(autoTarget(i), 36, withSentAt ? "on send time" : "on arrival")
        }
    }

    function test_auto_delay_still_measures_a_sender_whose_every_state_is_new() {
        // States that differ from the one before are periods however long:
        // a sender at 10 Hz is rendered two of its periods behind
        let i = make({network: stubNet, nodeId: "A", autoDelay: true})
        let sent = 0
        for (let k = 0; k < 20; ++k) {
            sent += 100
            stubNet.sessionTime = sent + 80
            i.push({x: k}, sent)
        }
        compare(autoTarget(i), 2 * 100 + 4)
    }

    // A sender that sends every physics step whether its object moves or
    // not - an avatar broadcast each step that stands from its spawn: its
    // unchanged states come at its rate, and that is its period
    function standingAtARate(withSentAt) {
        let i = make({network: stubNet, nodeId: "A", autoDelay: true})
        let sent = 0
        for (let k = 0; k < 60; ++k) {
            sent += 16
            stubNet.sessionTime = sent + 80
            if (withSentAt) i.push({x: 5, y: 7}, sent)
            else i.push({x: 5, y: 7})
        }
        return autoTarget(i)
    }

    function test_auto_delay_measures_a_sender_that_repeats_a_standing_state_at_its_rate() {
        // 2 x 16 + 4, not the 2 x 50 + 4 of a period never measured
        compare(standingAtARate(true), 36)
        compare(standingAtARate(false), 36)
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
