// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A PhysicsTimer on a ClayWorld2d is held by what holds the world: the
// global pause, the single step that advances it, a hit stop that slows it.
// Simulated time is measured by summing timeStep over the stepped signals,
// the same quantity the timer counts.

import QtQuick
import QtTest
import Box2D
import Clayground.Common
import Clayground.Physics
import Clayground.World

Item {
    id: root
    width: 400; height: 300

    ClayWorld2d {
        id: world
        components: new Map()
        anchors.fill: parent
        gravity: Qt.point(0, 0)
        xWuMin: 0; xWuMax: 40
        yWuMin: 0; yWuMax: 30
        pixelPerUnit: 10
    }

    PhysicsTimer {
        id: timer
        world: world.physics
        property int fired: 0
        onTriggered: fired += 1
    }

    // Simulated milliseconds and steps while recording is on.
    QtObject {
        id: meter
        property bool recording: false
        property real simMs: 0
        property int steps: 0
        function measure(ms) {
            simMs = 0; steps = 0;
            var t0 = Date.now();
            recording = true;
            testCase.wait(ms);
            recording = false;
            return {"wallMs": Date.now() - t0, "simMs": simMs, "steps": steps};
        }
    }
    // The simulated milliseconds of the first step after a resume.
    QtObject {
        id: resume
        property bool armed: false
        property real firstStepMs: -1
    }
    Connections {
        target: world.physics
        function onStepped() {
            if (resume.armed) {
                resume.armed = false;
                resume.firstStepMs = world.physics.timeStep * 1000;
            }
            if (!meter.recording) return;
            meter.simMs += world.physics.timeStep * 1000;
            meter.steps += 1;
        }
    }

    TestCase {
        id: testCase
        name: "PhysicsTimerWorld"
        when: windowShown

        function init() {
            Clayground.paused = false;
            tryCompare(world, "hitStopActive", false, 2000);
            timer.stop();
            timer.repeat = false;
            timer.interval = 1000;
            timer.fired = 0;
        }

        function cleanup() {
            Clayground.paused = false;
        }

        function test_runsOnTheWorldsSteps() {
            timer.interval = 100000;
            timer.start();
            var m = meter.measure(300);
            verify(m.steps > 3, "the world steps on its own: " + JSON.stringify(m));
            verify(Math.abs(timer.elapsed - m.simMs) < 1,
                   "elapsed " + timer.elapsed + " vs simulated " + JSON.stringify(m));
        }

        function test_pausedDoesNotFireAndSingleStepCountsSteps() {
            Clayground.paused = true;
            verify(!world.physics.running);
            timer.interval = 100;
            timer.start();
            wait(400);
            compare(timer.fired, 0, "paused, the timer does not fire");
            compare(timer.elapsed, 0);
            // The dojo's single step: 1/60 s per frame, so 100 ms is six.
            Clayground.physicsStep(5);
            compare(timer.fired, 0, "five steps are 83 ms");
            Clayground.physicsStep(1);
            compare(timer.fired, 1, "the sixth step reaches 100 ms");
        }

        // Resuming must not simulate the pause in one step (#338): the first
        // step after it is a frame's step, and a timer whose interval is
        // shorter than the pause does not fire on it.
        function test_resumeAfterPauseTakesANormalStep_data() {
            return [{tag: "700 ms", pauseMs: 700}, {tag: "1500 ms", pauseMs: 1500}];
        }
        function test_resumeAfterPauseTakesANormalStep(data) {
            timer.interval = 300;
            var running = meter.measure(200);
            verify(running.steps > 3, "the world steps before the pause: "
                   + JSON.stringify(running));
            timer.start();
            Clayground.paused = true;
            verify(!world.physics.running);
            wait(data.pauseMs);
            resume.firstStepMs = -1;
            resume.armed = true;
            Clayground.paused = false;
            tryVerify(function() { return resume.firstStepMs >= 0; }, 1000,
                      "the world steps again after the pause");
            verify(resume.firstStepMs < 100,
                   "the first step after a " + data.pauseMs + " ms pause simulated "
                   + resume.firstStepMs + " ms");
            compare(timer.fired, 0, "the timer does not fire on the first step");
            verify(timer.elapsed < timer.interval, "elapsed " + timer.elapsed);
        }

        function test_fullHitStopHoldsIt() {
            timer.interval = 100;
            timer.start();
            world.hitStop(400, 0);
            var m = meter.measure(300);
            verify(world.hitStopActive, "the measurement ran inside the stop");
            verify(m.steps > 3, "the world keeps stepping, with a zero step: "
                   + JSON.stringify(m));
            compare(timer.fired, 0);
            verify(timer.elapsed < 1, "elapsed " + timer.elapsed);
        }

        function test_slowHitStopSlowsItWithTheSimulation() {
            timer.interval = 100000;
            timer.start();
            var before = meter.measure(300);
            var elapsedBefore = timer.elapsed;
            world.hitStop(800, 0.25);
            var during = meter.measure(400);
            verify(world.hitStopActive, "the measurement ran inside the stop");
            var counted = timer.elapsed - elapsedBefore;
            verify(Math.abs(counted - during.simMs) < 1,
                   "the timer counted " + counted + " ms of " + JSON.stringify(during));
            var rateBefore = before.simMs / before.wallMs;
            var rateDuring = during.simMs / during.wallMs;
            verify(rateDuring < 0.5 * rateBefore,
                   "slowed from " + rateBefore + " to " + rateDuring);
        }
    }
}
