// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// GazeAnim, driven against a STUB head rather than a real one.
//
// The component only ever asks its head for two things: eyeLine, and where a
// scene point lands in the head's own frame. A stub can answer both, and
// answering them from a script rather than from a transform is what lets
// this suite state the residual it is testing against instead of arranging
// a 3D scene that happens to produce one - and lets it run with no built
// module, no window and no GPU.
//
// `import "../../animation"` picks up the plugin's QML directly.

import QtQuick
import QtTest
import "../../animation"

Item {
    id: root
    width: 50; height: 50

    // Stands in for a Head. residual is what mapPositionFromScene will imply:
    // a point at that angle, expressed in the head's own frame.
    component StubHead: QtObject {
        property real eyeLine: 0.8
        // Degrees the head has NOT covered - what the real thing computes
        // from its own rotation.
        property real yawLeft: 0
        property real pitchLeft: 0
        property int mapped: 0
        function mapPositionFromScene(p) {
            mapped++
            const yr = yawLeft * Math.PI / 180
            const pr = pitchLeft * Math.PI / 180
            const d = 10
            // Inverse of GazeAnim's own solve, so a stated angle comes back out.
            const y = eyeLine + d * Math.sin(pr)
            const h = d * Math.cos(pr)
            return Qt.vector3d(h * Math.sin(yr), y, h * Math.cos(yr))
        }
    }

    property var target: Qt.vector3d(1, 1, 1)   // any non-null vector will do

    TestCase {
        id: tc
        name: "GazeAnim"
        when: windowShown

        // Every test leaves the object as it found it. Without this a test
        // that fails mid-way never runs its own teardown, and the aversion or
        // target it left behind fails every test after it - which is how the
        // first run of this suite turned one real failure into five.
        function init() {
            head.yawLeft = 0
            head.pitchLeft = 0
            gaze.averting = false
            gaze.target = null
            gaze.running = false
        }
        function cleanup() {
            gaze.running = false
            gaze.averting = false
            gaze.target = null
        }

        StubHead { id: head }

        GazeAnim {
            id: gaze
            head: head
            running: false
            seed: 4
        }

        // tryVerify rather than wait-then-check: the ticker runs at 30 Hz in a
        // window that is never shown, and how many ticks land inside a fixed
        // wait is the runner's business, not this suite's. Asserting on the
        // settled value and letting it take as long as it takes is the only
        // version of these that is not quietly timing-dependent.
        readonly property int settleMs: 3000

        function test_centred_when_the_head_has_arrived() {
            head.yawLeft = 0; head.pitchLeft = 0
            gaze.target = root.target
            gaze.running = true
            // Micro-saccades keep it off exact zero, and that is their point -
            // a gaze pinned dead centre is a stare.
            tryVerify(function() { return Math.abs(gaze.gaze.x) < 0.12 }, settleMs)
            tryVerify(function() { return Math.abs(gaze.gaze.y) < 0.12 }, settleMs)
        }

        function test_eyes_cover_what_the_head_has_not() {
            head.yawLeft = gaze.yawRange * 0.5
            gaze.target = root.target
            gaze.running = true
            tryVerify(function() {
                return gaze.gaze.x > 0.35 && gaze.gaze.x < 0.65
            }, settleMs, "x=" + gaze.gaze.x)
        }

        function test_residual_is_clamped_to_the_eyes_own_travel() {
            // Past the head's limit the eyes take the rest - and stop.
            head.yawLeft = gaze.yawRange * 4
            gaze.target = root.target
            gaze.running = true
            tryVerify(function() { return gaze.gaze.x > 0.85 }, settleMs)
            verify(gaze.gaze.x <= 1.0001, "x=" + gaze.gaze.x)
        }

        function test_sign_of_the_axes() {
            // Positive yaw is the character's right, positive pitch is UP.
            // Getting either backwards produces a face that is unmistakably
            // wrong and impossible to name.
            head.yawLeft = -gaze.yawRange * 0.5
            head.pitchLeft = gaze.pitchRange * 0.5
            gaze.target = root.target
            gaze.running = true
            tryVerify(function() {
                return gaze.gaze.x < -0.3 && gaze.gaze.y > 0.3
            }, settleMs, "x=" + gaze.gaze.x + " y=" + gaze.gaze.y)
        }

        function test_no_target_wanders_within_bounds() {
            gaze.target = null
            gaze.running = true
            // A wander is a third of the eye's travel sideways and much less
            // vertically - a wander with equal vertical travel reads as seasick.
            // Bounds, not just "it moves". The offsets are generated from a
            // pseudo-random stream, and a stream that leaves 0..1 puts every
            // one of them outside the cap it was written against - which is
            // exactly what this caught the first time it ran.
            for (var i = 0; i < 14; ++i) {
                wait(120)
                verify(Math.abs(gaze.gaze.x) <= 0.4, "x=" + gaze.gaze.x)
                verify(Math.abs(gaze.gaze.y) <= 0.2, "y=" + gaze.gaze.y)
            }
        }

        function test_averting_leaves_the_target_and_looks_up() {
            head.yawLeft = 0
            gaze.target = root.target
            gaze.running = true
            tryVerify(function() { return Math.abs(gaze.gaze.x) < 0.12 }, settleMs)
            gaze.averting = true
            // Off to a side, and UP: down reads as shame rather than thought.
            tryVerify(function() {
                return Math.abs(gaze.gaze.x) > 0.35 && gaze.gaze.y > 0.2
            }, settleMs, "x=" + gaze.gaze.x + " y=" + gaze.gaze.y)
            gaze.averting = false
            tryVerify(function() { return Math.abs(gaze.gaze.x) < 0.12 }, settleMs)
        }

        // The bug this suite exists for as much as any: the wander offset and
        // the micro-saccade offset are sized an order of magnitude apart and
        // once shared a variable. Acquiring a target while a wander dwell had
        // time left applied a wander-sized offset on top of the residual, and
        // the eyes swung half their travel away from something they had just
        // locked onto, for as long as that dwell had left.
        function test_a_wander_offset_does_not_bleed_into_tracking() {
            gaze.target = null
            gaze.running = true
            wait(700)                        // let a wander dwell get going
            head.yawLeft = 0
            gaze.target = root.target        // acquire mid-dwell
            tryVerify(function() { return Math.abs(gaze.gaze.x) < 0.12 },
                      settleMs, "bled x=" + gaze.gaze.x)
        }

        function test_not_running_stops_asking_the_head_anything() {
            gaze.target = root.target
            gaze.running = false
            const before = head.mapped
            wait(300)
            compare(head.mapped, before)
        }

        function test_same_seed_same_wander() {
            // Determinism is what keeps a clayrender comparison meaningful.
            const a = sample(11)
            const b = sample(11)
            const c = sample(12)
            compare(a, b)
            verify(a !== c, "two seeds produced the same wander: " + a)
        }

        function sample(seed) {
            const o = comp.createObject(root, {head: head, seed: seed, target: null})
            o.running = true
            wait(600)
            const s = o.gaze.x.toFixed(4) + "," + o.gaze.y.toFixed(4)
            o.running = false
            o.destroy()
            return s
        }

        property Component comp: Component { GazeAnim {} }
    }
}
