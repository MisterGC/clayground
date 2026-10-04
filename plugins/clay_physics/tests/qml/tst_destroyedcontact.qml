// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Box2D
import Clayground.Physics
import Clayground.Canvas

// An item destroyed while its body touches a sensor has to end that contact
// with its item named (#371): a knight's in-range set otherwise keeps a dead
// enemy. Box2D ends the contacts of a body only when it destroys the body,
// after the item is gone, and qml-box2d drops those events, so the sensor
// heard nothing at all.
//
// The World is stepped by hand (running: false + step()) so the outcome does
// not depend on frame timing.
TestCase {
    id: testCase
    name: "DestroyedContact"

    readonly property real ppu: 20

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
    }

    // The knight's attack range: a sensor that records whom it gains and
    // loses, as the item its handler reads at that moment.
    Component {
        id: sensorComp
        RectBoxBody {
            id: sensorItem
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 10; yWu: 10
            widthWu: 4; heightWu: 4
            bodyType: Body.Static
            sensor: true
            objectName: "sensor"
            property var begun: []
            property var ended: []
            Connections {
                target: sensorItem.fixture
                function onBeginContact(other) { sensorItem.begun.push(other.getBody().target); }
                function onEndContact(other) { sensorItem.ended.push(other.getBody().target); }
            }
        }
    }

    // An enemy that stands inside the sensor until it is destroyed.
    Component {
        id: enemyComp
        RectBoxBody {
            id: enemyItem
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 11; yWu: 9
            widthWu: 1; heightWu: 1
            bodyType: Body.Dynamic
            density: 1
            objectName: "enemy"
            property var ended: []
            Connections {
                target: enemyItem.fixture
                function onEndContact(other) { enemyItem.ended.push(other.getBody().target); }
            }
        }
    }

    Component {
        id: trackerComp
        CollisionTracker {}
    }

    function stepWorld(n) {
        for (var i = 0; i < n; ++i) physicsWorld.step();
    }

    // Lets the deferred deletion of destroy() run.
    function flush() {
        wait(0);
    }

    function cleanup() {
        for (var i = room.children.length - 1; i >= 0; --i)
            room.children[i].destroy();
        flush();
    }

    function test_aDestroyedBodyEndsItsContactWithItsItem() {
        var sensor = createTemporaryObject(sensorComp, room);
        var enemy = enemyComp.createObject(room);
        stepWorld(2);
        compare(sensor.begun.length, 1, "the sensor should have seen the enemy arrive");
        verify(sensor.begun[0] === enemy, "the sensor's begin should name the enemy");

        // What the sensor's handler reads, checked against the live enemy.
        var namedTheEnemy = false;
        sensor.fixture.endContact.connect(function(other) {
            namedTheEnemy = other.getBody().target === enemy;
        });
        enemy.destroy();
        flush();

        compare(sensor.ended.length, 1, "the sensor should see one end of contact");
        verify(namedTheEnemy, "the end of contact should name the destroyed enemy");
        stepWorld(2);
        compare(sensor.ended.length, 1, "the world should not end that contact again");
    }

    function test_aCollisionTrackerDropsADestroyedEntity() {
        var sensor = createTemporaryObject(sensorComp, room);
        var tracker = createTemporaryObject(trackerComp, testCase);
        tracker.fixture = sensor.fixture;
        var enemy = enemyComp.createObject(room);
        var left = [];
        tracker.endContact.connect(function(entity) { left.push(entity === enemy); });
        stepWorld(2);
        verify(tracker.entities.has(enemy), "the tracker should hold the enemy");

        enemy.destroy();
        flush();

        compare(tracker.entities.size, 0, "the tracker should hold nobody");
        compare(left, [true], "the tracker should report the enemy leaving once");
    }

    function test_aContactThatEndedBeforeIsNotEndedAgain() {
        var sensor = createTemporaryObject(sensorComp, room);
        var enemy = enemyComp.createObject(room);
        stepWorld(2);
        enemy.xWu = 30;
        stepWorld(2);
        compare(sensor.ended.length, 1, "walking out should end the contact");

        enemy.destroy();
        flush();

        compare(sensor.ended.length, 1, "destroying it outside should end nothing");
    }

    function test_aDestroyedSensorEndsItsContactWithTheBodyInIt() {
        var sensor = sensorComp.createObject(room);
        var enemy = createTemporaryObject(enemyComp, room);
        stepWorld(2);
        var namedTheSensor = false;
        enemy.fixture.endContact.connect(function(other) {
            namedTheSensor = other.getBody().target === sensor;
        });

        sensor.destroy();
        flush();

        compare(enemy.ended.length, 1, "the enemy should see one end of contact");
        verify(namedTheSensor, "the end of contact should name the destroyed sensor");
    }

    // A raw Body has no PhysicsItem around it: destroyed, it ends nothing,
    // and the sensor still counts it as touching. Destroying the sensor
    // afterwards must not trip over the fixture that is gone.
    Component {
        id: rawEnemyComp
        Item {
            id: rawEnemy
            x: 11 * testCase.ppu; y: room.height - 9 * testCase.ppu
            width: testCase.ppu; height: testCase.ppu
            Body {
                target: rawEnemy
                world: physicsWorld
                bodyType: Body.Dynamic
                fixtures: Box {
                    width: rawEnemy.width; height: rawEnemy.height
                    density: 1
                }
            }
        }
    }

    function test_aSensorOutlivingARawBodyEndsCleanly() {
        failOnWarning(/.*/);
        var sensor = sensorComp.createObject(room);
        var raw = rawEnemyComp.createObject(room);
        stepWorld(2);
        compare(sensor.begun.length, 1, "the sensor should have seen the raw body arrive");

        raw.destroy();
        flush();
        sensor.destroy();
        flush();
    }

    // VisualizedPolyBody has a body of its own, not a PhysicsItem's.
    ClayCanvas {
        id: theCanvas
        width: 40 * testCase.ppu; height: 20 * testCase.ppu
        pixelPerUnit: testCase.ppu
        worldXMin: 0; worldXMax: 40
        worldYMin: 0; worldYMax: 20
    }
    Component {
        id: polyComp
        VisualizedPolyBody {
            canvas: theCanvas
            world: physicsWorld
            bodyType: Body.Dynamic
            density: 1
            vertices: [{x: 10, y: 10}, {x: 12, y: 10}, {x: 11, y: 12}]
        }
    }

    function test_aDestroyedPolyBodyEndsItsContactWithItsItem() {
        // The whole world is the sensor, so it holds the poly wherever the
        // canvas puts it.
        var sensor = createTemporaryObject(sensorComp, theCanvas.coordSys,
                                           {xWu: 0, yWu: 20, widthWu: 40, heightWu: 20});
        var poly = polyComp.createObject(theCanvas);
        stepWorld(2);
        compare(sensor.begun.length, 1, "the sensor should have seen the poly arrive");
        var namedThePoly = false;
        sensor.fixture.endContact.connect(function(other) {
            namedThePoly = other.getBody().target === poly;
        });

        poly.destroy();
        flush();

        compare(sensor.ended.length, 1, "the sensor should see one end of contact");
        verify(namedThePoly, "the end of contact should name the destroyed poly");
    }

    // Everything goes at once: the end of contact may reach a sensor that is
    // going too, and nothing may warn.
    function test_aRoomTornDownAtOnceWarnsNothing() {
        failOnWarning(/.*/);
        var hall = Qt.createQmlObject("import QtQuick; Item { anchors.fill: parent }", room);
        var sensor = sensorComp.createObject(hall);
        var enemy = enemyComp.createObject(hall);
        stepWorld(2);
        compare(sensor.begun.length, 1, "the sensor should have seen the enemy arrive");

        hall.destroy();
        flush();
        stepWorld(2);
    }
}
