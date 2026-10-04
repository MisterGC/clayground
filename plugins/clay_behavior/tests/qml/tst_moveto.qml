// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// MoveTo re-aims on the steps of its world's physics, not on wall clock
// (#340): a paused world holds the actor's heading however long the pause
// lasts, a single step advances the re-aim clock by one frame, and a world
// single-stepped from the same start takes the same path every time.

import QtQuick
import QtTest
import Box2D
import Clayground.Common
import Clayground.Physics
import Clayground.World
import Clayground.Behavior

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

    RectBoxBody {
        id: actor
        parent: world.room
        world: world.physics
        pixelPerUnit: world.pixelPerUnit
        xWu: 5; yWu: 5
        widthWu: 1; heightWu: 1
        bodyType: Body.Kinematic
        sensor: true

        MoveTo {
            id: moveTo
            world: world
            anchors.centerIn: parent
            desiredSpeed: 10
        }
    }

    TestCase {
        id: testCase
        name: "MoveTo"
        when: windowShown

        function init() {
            Clayground.paused = true;
            verify(!world.physics.running);
            moveTo.running = false;
            actor.xWu = 5;
            actor.yWu = 5;
            moveTo.destXWu = 30;
            moveTo.destYWu = 5;
        }

        function cleanup() {
            moveTo.running = false;
            Clayground.paused = false;
        }

        function heading() {
            return {"x": actor.linearVelocity.x, "y": actor.linearVelocity.y};
        }

        function test_pausedWorldHoldsTheHeadingAndStepsReAim() {
            moveTo.running = true;
            var h = heading();
            verify(h.x > 10 * Math.abs(h.y),
                   "starting, it heads right to the first destination: " + JSON.stringify(h));

            // Up from the actor: a re-aim turns the heading vertical.
            moveTo.destXWu = 5;
            moveTo.destYWu = 25;
            wait(500);
            compare(heading(), h, "paused for 500 ms, it does not re-aim");
            compare(actor.xWu, 5, "paused, the actor does not move");

            // The dojo's single step is 1/60 s, so 100 ms is six steps.
            Clayground.physicsStep(5);
            compare(heading(), h, "five steps are 83 ms, short of the re-aim");
            Clayground.physicsStep(1);
            var turned = heading();
            verify(Math.abs(turned.y) > Math.abs(turned.x),
                   "the sixth step re-aims at the new destination: " + JSON.stringify(turned));
        }

        // One run from the start in init(): 90 single steps, the destination
        // moved after 40 of them so the path bends on a re-aim.
        function steppedPath() {
            var path = [];
            moveTo.running = true;
            for (var i = 0; i < 90; ++i) {
                if (i === 40) {
                    moveTo.destXWu = 10;
                    moveTo.destYWu = 25;
                }
                Clayground.physicsStep(1);
                path.push([actor.xWu, actor.yWu]);
            }
            moveTo.running = false;
            return path;
        }

        function test_singleSteppedWorldTakesTheSamePathTwice() {
            var first = steppedPath();
            init();
            var second = steppedPath();

            verify(first[39][0] > 5 + 1 && Math.abs(first[39][1] - 5) < 0.5,
                   "it heads right first: " + JSON.stringify(first[39]));
            verify(first[89][1] > first[45][1] + 1,
                   "after the destination moved it heads up: "
                   + JSON.stringify(first[45]) + " -> " + JSON.stringify(first[89]));
            compare(second.length, first.length);
            for (var i = 0; i < first.length; ++i)
                compare(second[i], first[i], "step " + (i + 1) + " of the second run");
        }
    }
}
