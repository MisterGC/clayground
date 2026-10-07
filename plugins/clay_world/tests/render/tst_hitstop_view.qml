// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A view-only hit stop holds the picture while the simulation runs on. Rates
// are measured as simulated seconds per wall second: the step driver fires
// stepped even at time scale 0, only with a zero time step, so counting the
// signal alone cannot tell a halted simulation from a running one.

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

        RectBoxBody {
            id: box
            bodyType: Body.Kinematic
            xWu: 5; yWu: 15
            widthWu: 3; heightWu: 3
            color: "#ff4020"
        }

        ScreenFx2d { id: fx; world: world }
    }

    // Simulated seconds and stepped signals while recording is on.
    QtObject {
        id: meter
        property bool recording: false
        property real simSec: 0
        property int steps: 0
        function measure(ms) {
            simSec = 0; steps = 0;
            var t0 = Date.now();
            recording = true;
            testCase.wait(ms);
            recording = false;
            return {"wallSec": (Date.now() - t0) / 1000,
                    "simSec": simSec, "steps": steps};
        }
    }
    Connections {
        target: world.physics
        function onStepped() {
            if (!meter.recording) return;
            meter.simSec += world.physics.timeStep;
            meter.steps += 1;
        }
    }

    TestCase {
        id: testCase
        name: "HitStopView"
        when: windowShown

        function init() {
            world.hitStopMode = "physics";
            tryCompare(world, "hitStopActive", false, 2000);
            box.linearVelocity = Qt.point(0, 0);
            box.xWu = 5;
            wait(50);
        }

        function test_physicsIsTheDefault() {
            compare(world.hitStopMode, "physics");
            compare(world.picture, world.canvas);
            world.hitStop(400, 0);
            compare(world.physics.timeScale, 0);
            compare(world.picture, world.canvas, "the default does not hold the picture");
            var during = meter.measure(250);
            verify(during.simSec < 0.01,
                   "physics mode halts the simulation: " + JSON.stringify(during));
            compare(world.clayInspect().hitStop.mode, "physics");
        }

        function test_viewKeepsSteppingAtFullRate() {
            var before = meter.measure(250);
            world.hitStopMode = "view";
            world.hitStop(500, 0);
            verify(world.hitStopActive);
            compare(world.physics.timeScale, Clayground.timeScale);
            var during = meter.measure(250);
            verify(world.hitStopActive, "the measurement ran inside the stop");
            var rateBefore = before.simSec / before.wallSec;
            var rateDuring = during.simSec / during.wallSec;
            verify(rateDuring > 0.8 * Clayground.timeScale,
                   "simulated time runs at full rate: " + JSON.stringify(during));
            verify(during.steps >= 0.8 * before.steps * during.wallSec / before.wallSec,
                   "stepped keeps its rate: " + before.steps + " -> " + during.steps);
            verify(Math.abs(rateDuring - rateBefore) < 0.2 * Clayground.timeScale,
                   "rate before " + rateBefore + ", during " + rateDuring);
            compare(world.clayInspect().hitStop.mode, "view");
        }

        function test_viewHoldsThePicture() {
            box.linearVelocity = Qt.point(20, 0);
            wait(100);
            world.hitStopMode = "view";
            world.hitStop(500, 0);
            verify(world.picture !== world.canvas, "the held frame is shown");
            wait(80);
            var held = grabImage(root);
            verify(held.width > 0, "the platform renders pixels - see RENDERS in claytest.cmake");
            var xHeld = box.xWu;
            wait(250);
            verify(world.hitStopActive);
            var later = grabImage(root);
            verify(box.xWu - xHeld > 3, "the body moves on: " + xHeld + " -> " + box.xWu);
            verify(held.equals(later), "the drawn world holds still");
            tryCompare(world, "hitStopActive", false, 2000);
            compare(world.picture, world.canvas);
            wait(80);
            verify(!held.equals(grabImage(root)), "the live world shows again");
        }

        function test_viewGradesTheHeldFrame() {
            fx.saturation = 0.5;
            compare(fx.sourceItem, world.canvas);
            world.hitStopMode = "view";
            world.hitStop(200, 0);
            compare(fx.sourceItem, world.picture);
            verify(fx.sourceItem !== world.canvas);
            verify(fx.gradeActive);
            tryCompare(world, "hitStopActive", false, 2000);
            compare(fx.sourceItem, world.canvas);
            fx.saturation = 1;
        }
    }
}
