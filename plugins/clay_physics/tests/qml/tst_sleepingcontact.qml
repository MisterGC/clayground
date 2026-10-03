// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Box2D
import Clayground.Physics

// A kinematic body moved only by setting its position - what every remote
// ReplicatedObject with a body is - has to begin a contact with a body that
// sleeps (#369). Box2D's SetTransform wakes nothing, and a contact between two
// sleeping bodies is never updated, so without a wake the knight standing
// still never hits the enemy that walked into reach.
//
// The World is stepped by hand (running: false + step()) so the outcome does
// not depend on frame timing.
TestCase {
    id: testCase
    name: "SleepingContact"

    readonly property real ppu: 20
    // Box2D puts a body at rest to sleep after 0.5 s; two seconds is ample.
    readonly property int settleSteps: 120

    World {
        id: physicsWorld
        gravity: Qt.point(0, 0)
        timeStep: 1/60
        pixelsPerMeter: testCase.ppu
        running: false
    }

    Item {
        id: room
        width: 40 * testCase.ppu
        height: 20 * testCase.ppu

        // The host's enemy: a sensor, the way a hit box is one. Dynamic,
        // because Box2D never lets two kinematic bodies touch.
        RectBoxBody {
            id: enemy
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 20; yWu: 10
            widthWu: 2; heightWu: 2
            bodyType: Body.Dynamic
            density: 1
            sensor: true
            property int contacts: 0
            Connections {
                target: enemy.fixture
                function onBeginContact(other) { enemy.contacts++; }
            }
        }

        // The joiner's copy of the knight: only ever moved by position.
        RectBoxBody {
            id: knight
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 2; yWu: 10
            widthWu: 1; heightWu: 1
            bodyType: Body.Kinematic
        }

        // A solid sleeping body, to see that a touch wakes what it overlaps.
        RectBoxBody {
            id: crate
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 30; yWu: 10
            widthWu: 2; heightWu: 2
            bodyType: Body.Dynamic
            density: 1
        }

        // A dynamic body that slides to a stop under damping: waking on a
        // move must not keep a body that comes to rest from falling asleep.
        RectBoxBody {
            id: puck
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 2; yWu: 2
            widthWu: 1; heightWu: 1
            bodyType: Body.Dynamic
            density: 1
            linearDamping: 5
        }

        // The same puck on a plain Item: the world writes its position back
        // too, but nothing there wakes it - the reference for when it sleeps.
        Item {
            id: refPuck
            x: 2 * testCase.ppu; y: room.height - 4 * testCase.ppu
            width: testCase.ppu; height: testCase.ppu
            Body {
                id: refBody
                target: refPuck
                world: physicsWorld
                bodyType: Body.Dynamic
                linearDamping: 5
                fixtures: Box {
                    width: refPuck.width; height: refPuck.height
                    density: 1
                }
            }
        }
    }

    function stepWorld(n) {
        for (var i = 0; i < n; ++i) physicsWorld.step();
    }

    function init() {
        knight.xWu = 2; knight.yWu = 10;
        enemy.contacts = 0;
        stepWorld(settleSteps);
    }

    function test_aBodyMovedByPositionBeginsContactWithASleepingSensor() {
        verify(!enemy.awake, "the enemy should be asleep before the move");
        verify(!knight.awake, "the knight should be asleep before the move");

        knight.xWu = 20.5; knight.yWu = 9.5;
        stepWorld(2);

        verify(enemy.contacts > 0,
               "the sensor should see beginContact, saw " + enemy.contacts);
        verify(knight.awake, "moving the knight by position should wake it");
    }

    function test_aBodyMovedByPositionWakesTheSolidBodyItTouches() {
        verify(!crate.awake, "the crate should be asleep before the move");

        knight.xWu = 30.5; knight.yWu = 9.5;
        stepWorld(1);

        verify(crate.awake, "a touch should wake the crate it overlaps");
    }

    function test_aBodyComingToRestFallsAsleepOnTime() {
        puck.linearVelocity = Qt.point(10, 0);  // m/s, about 2 wu of slide
        refBody.linearVelocity = Qt.point(10, 0);
        var x0 = puck.x;
        var puckStep = -1, refStep = -1;
        for (var i = 1; i <= settleSteps * 2; ++i) {
            physicsWorld.step();
            if (puckStep < 0 && !puck.awake) puckStep = i;
            if (refStep < 0 && !refBody.awake) refStep = i;
        }

        verify(puck.x > x0, "the puck should have slid, x " + x0 + " -> " + puck.x);
        verify(refStep > 0, "the reference puck should fall asleep");
        compare(puckStep, refStep, "the puck should fall asleep on the reference's step");
        verify(!puck.awake, "a puck at rest should stay asleep");
    }
}
