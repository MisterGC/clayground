// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Box2D
import Clayground.Physics

// PhysicsTimer counts the time of the steps a World takes, nothing else.
// The World is stepped by hand (running: false + step()), which is what the
// dojo's pause and single-step do to a ClayWorld2d: wall time passing
// without a step must not move the timer, and each step moves it by exactly
// its timeStep - scaled down under a hit stop, 1/60 s on a single step.
TestCase {
    id: testCase
    name: "PhysicsTimer"

    World {
        id: physicsWorld
        gravity: Qt.point(0, 0)
        timeStep: 1/60
        running: false
    }

    PhysicsTimer {
        id: timer
        world: physicsWorld
        property int fired: 0
        onTriggered: fired += 1
    }

    function init() {
        timer.stop();
        timer.interval = 1000;
        timer.repeat = false;
        timer.triggeredOnStart = false;
        timer.world = physicsWorld;
        timer.fired = 0;
        physicsWorld.timeStep = 1/60;
    }

    function stepWorld(n) {
        for (var i = 0; i < n; ++i) physicsWorld.step();
    }

    // Steps until the timer fires; -1 if it has not after maxSteps.
    function stepsUntilFired(maxSteps) {
        for (var i = 1; i <= maxSteps; ++i) {
            physicsWorld.step();
            if (timer.fired > 0) return i;
        }
        return -1;
    }

    function test_noStepNoTrigger() {
        timer.interval = 50;
        timer.start();
        wait(300);
        compare(timer.fired, 0, "wall time alone does not move the timer");
        compare(timer.elapsed, 0);
    }

    function test_singleStepFiresAfterTheStepsOfItsInterval_data() {
        return [
            {tag: "one step", interval: 16, steps: 1},
            {tag: "50 ms", interval: 50, steps: 3},
            {tag: "100 ms", interval: 100, steps: 6},
            {tag: "101 ms", interval: 101, steps: 7},
            {tag: "1 s", interval: 1000, steps: 60}
        ];
    }
    function test_singleStepFiresAfterTheStepsOfItsInterval(data) {
        timer.interval = data.interval;
        timer.start();
        compare(stepsUntilFired(200), data.steps);
        verify(!timer.running, "a timer that does not repeat stops when it fires");
        stepWorld(100);
        compare(timer.fired, 1);
    }

    function test_elapsedIsTheSimulatedTime() {
        timer.start();
        stepWorld(30);
        verify(Math.abs(timer.elapsed - 500) < 1e-3, "elapsed " + timer.elapsed);
    }

    function test_hitStopScaleSlowsIt() {
        // A hit stop at scale 0.2 makes each step simulate a fifth of the
        // time, so the interval takes five times the steps.
        physicsWorld.timeStep = 0.2 / 60;
        timer.interval = 100;
        timer.start();
        compare(stepsUntilFired(200), 30);
    }

    function test_fullHitStopHoldsIt() {
        physicsWorld.timeStep = 0;
        timer.interval = 50;
        timer.start();
        stepWorld(120);
        compare(timer.fired, 0);
        compare(timer.elapsed, 0);
    }

    function test_repeatKeepsItsPace() {
        timer.interval = 50;
        timer.repeat = true;
        timer.start();
        stepWorld(60);
        compare(timer.fired, 20, "one second of steps holds twenty 50 ms intervals");
        verify(timer.running);
    }

    function test_repeatCarriesTheOvershoot() {
        // 40 ms steps against a 100 ms interval: fires at 120, 200, 320,
        // 400 ms - the 20 ms overshoot counts toward the next interval.
        physicsWorld.timeStep = 0.04;
        timer.interval = 100;
        timer.repeat = true;
        timer.start();
        var firedAt = [];
        for (var i = 1; i <= 10; ++i) {
            var before = timer.fired;
            physicsWorld.step();
            if (timer.fired > before) firedAt.push(i);
        }
        compare(firedAt, [3, 5, 8, 10]);
    }

    function test_stopHoldsAndStartBeginsAtZero() {
        timer.interval = 100;
        timer.start();
        stepWorld(3);
        timer.stop();
        stepWorld(10);
        compare(timer.fired, 0);
        timer.start();
        compare(timer.elapsed, 0);
        compare(stepsUntilFired(200), 6);
    }

    function test_restartBeginsAtZeroWhileRunning() {
        timer.interval = 100;
        timer.start();
        stepWorld(5);
        timer.restart();
        compare(timer.elapsed, 0);
        compare(stepsUntilFired(200), 6);
    }

    function test_triggeredOnStart() {
        timer.triggeredOnStart = true;
        timer.interval = 50;
        timer.start();
        compare(timer.fired, 1);
        stepWorld(3);
        compare(timer.fired, 2);
    }

    function test_noWorldNeverFires() {
        timer.world = null;
        timer.interval = 16;
        timer.start();
        stepWorld(10);
        compare(timer.fired, 0);
    }
}
