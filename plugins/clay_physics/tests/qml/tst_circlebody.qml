// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtTest
import Box2D
import Clayground.Physics

// A circle fixture rolls down an incline; a box fixture of the same size and
// friction stays where it landed. That difference is the whole reason for
// CircleBody to exist, and it is the one thing a rounded-corner Rectangle
// over a Box fixture could not reproduce.
//
// The World is stepped by hand (running: false + step()) so the outcome does
// not depend on frame timing or on how long the test host takes per frame.
TestCase {
    id: testCase
    name: "CircleBody"

    readonly property real ppu: 20          // pixels per world unit
    readonly property real rampAngleDeg: 20 // screen-clockwise: downhill is +x
    readonly property int stepCount: 120    // 2 s at 1/60

    World {
        id: physicsWorld
        gravity: Qt.point(0, 9.81)  // metres/s^2, +y is screen-down
        timeStep: 1/60
        // 1 world unit = 1 metre, which keeps the expected roll distance
        // computable from the incline angle alone.
        pixelsPerMeter: testCase.ppu
        running: false
    }

    // Two identical ramps side by side, so the rolling body can never reach
    // the other one; each body starts at the same place on its own ramp.
    Item {
        id: room
        width: 40 * testCase.ppu
        height: 20 * testCase.ppu

        RectBoxBody {
            id: rampA
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 1; yWu: 10
            widthWu: 16; heightWu: 0.5
            rotation: testCase.rampAngleDeg
            bodyType: Body.Static
            friction: 1.0
        }

        RectBoxBody {
            id: rampB
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            xWu: 21; yWu: 10
            widthWu: 16; heightWu: 0.5
            rotation: testCase.rampAngleDeg
            bodyType: Body.Static
            friction: 1.0
        }

        CircleBody {
            id: ball
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            radiusWu: 0.5
            xWu: 2.5
            yWu: testCase.dropYWu(rampA, 3.0, 1.0)
            bodyType: Body.Dynamic
            density: 1; friction: 1.0; restitution: 0
        }

        RectBoxBody {
            id: crate
            world: physicsWorld
            pixelPerUnit: testCase.ppu
            widthWu: 1; heightWu: 1
            xWu: 22.5
            yWu: testCase.dropYWu(rampB, 23.0, 1.0)
            bodyType: Body.Dynamic
            density: 1; friction: 1.0; restitution: 0
            // Laid flush with the incline rather than axis-aligned: a box
            // dropped on one corner tips itself flat, and that settling moves
            // x for reasons that have nothing to do with rolling. Assigned
            // rather than bound because Box2D writes rotation back on every
            // step and a binding would be fighting it.
            Component.onCompleted: rotation = testCase.rampAngleDeg
        }
    }

    // World-unit y of the top edge of a sizeWu x sizeWu body whose underside
    // hovers a tenth of a unit over the ramp's upper surface at xWu. yWu
    // addresses the bounding box's top edge, so the body centre is derived
    // first: rotation happens about that centre and leaves it in place.
    function dropYWu(ramp, xWu, sizeWu) {
        var rad = rampAngleDeg * Math.PI / 180;
        var rampCentreXWu = ramp.xWu + ramp.widthWu * 0.5;
        var rampCentreYWu = ramp.yWu - ramp.heightWu * 0.5;
        // Downhill is +x, so a point left of the ramp's centre sits higher.
        var midlineYWu = rampCentreYWu + (rampCentreXWu - xWu) * Math.tan(rad);
        // Half the ramp's thickness plus half the body, both measured along
        // the surface normal and then expressed as a vertical offset.
        var clearanceWu = (ramp.heightWu * 0.5 + sizeWu * 0.5) / Math.cos(rad);
        return midlineYWu + clearanceWu + 0.1 + sizeWu * 0.5;
    }

    function stepWorld(n) {
        for (var i = 0; i < n; ++i) physicsWorld.step();
    }

    function test_circleRollsDownAnInclineWhereABoxDoesNot() {
        var ballStartXWu = ball.xWu;
        var crateStartXWu = crate.xWu;

        stepWorld(stepCount);

        var ballTravel = Math.abs(ball.xWu - ballStartXWu);
        var crateTravel = Math.abs(crate.xWu - crateStartXWu);

        verify(ballTravel > 2.0,
               "circle should roll down the incline, moved " + ballTravel + " wu");
        verify(crateTravel < 0.5,
               "box should stay put on the incline, moved " + crateTravel + " wu");
        // Not merely "the circle moved more": the two outcomes have to differ
        // in kind, or a slightly slipperier box would also pass.
        verify(ballTravel > 4 * crateTravel,
               "circle " + ballTravel + " wu vs box " + crateTravel + " wu");
    }

    // The fixture has to be a real Circle sized from radiusWu - a Box fixture
    // behind a round Rectangle would pass the rolling test only by accident.
    function test_fixtureIsACircleSizedFromRadiusWu() {
        compare(ball.fixture.radius, ball.radiusWu * testCase.ppu);
        compare(ball.widthWu, ball.radiusWu * 2);
        compare(ball.heightWu, ball.radiusWu * 2);
    }
}
