// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// slowMotion() counts the physics clock (#506): with the world paused and
// stepped by hand, a slow motion ends on the step its length names, every
// run, and a pause or a full hit stop holds it. Its scale multiplies with the
// hit stop's and the global time scale.

import QtQuick
import QtTest
import Clayground.Common
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

    TestCase {
        id: testCase
        name: "SlowMotionWorld"
        when: windowShown

        // Steps the paused world one step at a time until the slow motion
        // ends, and returns on which step it did; -1 if it outlasts limit.
        // "dojo" is the dojo's single step, 1/60 s whatever the time scale;
        // "scaled" is a frame of 1/60 s at the world's time scale, the step
        // the running world takes.
        function stepsUntilEnd(kind, limit) {
            for (var i = 1; i <= limit; ++i) {
                if (kind === "dojo") {
                    Clayground.physicsStep(1);
                } else {
                    world.physics.timeStep = world.physics.timeScale / 60;
                    world.physics.step();
                }
                if (!world.slowMotionActive) return i;
            }
            return -1;
        }

        function init() {
            Clayground.paused = true;
            Clayground.timeScale = 1;
            world.hitStopMode = "physics";
            tryCompare(world, "hitStopActive", false, 2000);
            // No slow motion is left over from the previous test.
            stepsUntilEnd("dojo", 10000);
            verify(!world.slowMotionActive);
        }

        function cleanup() {
            Clayground.paused = false;
            Clayground.timeScale = 1;
            world.hitStopMode = "physics";
        }

        function test_endsOnTheSameStepEveryRun_data() {
            return [
                // 300 ms of 1/60 s steps.
                {tag: "dojo step", kind: "dojo", ms: 300, scale: 0.25,
                 timeScale: 1, steps: 18},
                // 300 ms at 0.25 of 1/60 s: 1.2 s, 72 frames.
                {tag: "scaled step", kind: "scaled", ms: 300, scale: 0.25,
                 timeScale: 1, steps: 72},
                // The global time scale multiplies in: 144 frames.
                {tag: "scaled step, time scale 0.5", kind: "scaled", ms: 300,
                 scale: 0.25, timeScale: 0.5, steps: 144},
                // 100 ms are six steps of 1/60 s, which sum to 99.99999 ms
                // in float: the slow motion still ends on the sixth.
                {tag: "float sum", kind: "dojo", ms: 100, scale: 0.5,
                 timeScale: 1, steps: 6}
            ];
        }
        function test_endsOnTheSameStepEveryRun(data) {
            Clayground.timeScale = data.timeScale;
            var ends = [];
            for (var run = 0; run < 3; ++run) {
                world.slowMotion(data.ms, data.scale);
                verify(world.slowMotionActive);
                fuzzyCompare(world.physics.timeScale, data.timeScale * data.scale, 1e-6);
                ends.push(stepsUntilEnd(data.kind, 1000));
                fuzzyCompare(world.physics.timeScale, data.timeScale, 1e-6);
            }
            compare(ends, [data.steps, data.steps, data.steps]);
        }

        function test_scalesMultiply() {
            Clayground.timeScale = 0.5;
            world.hitStop(600, 0.5);
            world.slowMotion(100, 0.4);
            fuzzyCompare(world.physics.timeScale, 0.5 * 0.5 * 0.4, 1e-6);
            compare(world.clayInspect().slowMotion.active, true);
            fuzzyCompare(world.clayInspect().slowMotion.scale, 0.4, 1e-6);
            // The slow motion ends on the physics clock, the hit stop runs on.
            compare(stepsUntilEnd("dojo", 100), 6);
            verify(world.hitStopActive);
            fuzzyCompare(world.physics.timeScale, 0.5 * 0.5, 1e-6);
            tryCompare(world, "hitStopActive", false, 2000);
            fuzzyCompare(world.physics.timeScale, 0.5, 1e-6);
        }

        function test_pauseHoldsIt() {
            world.slowMotion(100, 0.5);
            wait(300);
            verify(world.slowMotionActive, "paused, the slow motion does not end");
            compare(world.clayInspect().slowMotion.remainingMs, 100);
        }

        function test_fullHitStopHoldsIt() {
            world.slowMotion(100, 0.5);
            world.hitStop(300, 0);
            compare(world.physics.timeScale, 0);
            compare(stepsUntilEnd("scaled", 20), -1);
            compare(world.clayInspect().slowMotion.remainingMs, 100,
                    "a frame of a full hit stop simulates nothing");
            tryCompare(world, "hitStopActive", false, 2000);
            compare(stepsUntilEnd("scaled", 100), 12);
        }

        function test_runningWorldEndsItOnItsOwn() {
            Clayground.paused = false;
            world.slowMotion(100, 0.5);
            verify(world.slowMotionActive);
            tryCompare(world, "slowMotionActive", false, 2000);
            compare(world.physics.timeScale, 1);
        }

        function test_overlappingCallsMerge() {
            world.slowMotion(300, 0.5);
            world.slowMotion(100, 0.2);
            fuzzyCompare(world.physics.timeScale, 0.2, 1e-6);
            compare(world.clayInspect().slowMotion.remainingMs, 300,
                    "the short call does not end the long one");
            compare(stepsUntilEnd("dojo", 100), 18);
        }

        function test_zeroLengthOrScaleDoesNothing() {
            world.slowMotion(0, 0.5);
            world.slowMotion(100, 0);
            world.slowMotion(-50, 0.5);
            verify(!world.slowMotionActive);
            compare(world.physics.timeScale, 1);
            world.slowMotion(100, 3);
            fuzzyCompare(world.clayInspect().slowMotion.scale, 1, 1e-6);
        }

        // In view mode the simulation keeps its speed, the picture is held,
        // and the slow motion counts the step times its scale: as long as in
        // physics mode.
        function test_viewModeHoldsThePictureForTheSameSteps() {
            world.hitStopMode = "view";
            world.slowMotion(300, 0.25);
            compare(world.physics.timeScale, 1);
            verify(world.picture !== world.canvas, "the picture is held");
            compare(stepsUntilEnd("scaled", 1000), 72);
            verify(world.picture === world.canvas, "the live canvas is back");
        }
    }
}
