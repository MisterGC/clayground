// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Shake, kick and hit stop on the 2d world. Stepped through the camera's own
// _advanceJuice(dt), so the numbers do not depend on the frame rate of a
// headless runner.

import QtQuick
import QtTest
import Clayground.Common
import Clayground.World

Item {
    id: root
    width: 400; height: 300

    QtObject {
        id: target
        property real xWu: 10
        property real yWu: 20
    }

    ClayWorld2dCamera {
        id: cam
        target: target
    }

    ClayWorld2d {
        id: world
        components: new Map()
        anchors.fill: parent
        gravity: Qt.point(0, 0)
    }

    TestCase {
        name: "Camera2dJuice"
        when: windowShown

        function init() {
            cam.resetShake();
        }

        function test_restIsTheTarget() {
            compare(cam.cameraX, 10);
            compare(cam.cameraY, 20);
            compare(cam.trauma, 0);
        }

        function test_traumaClampsAndDecays() {
            cam.addTrauma(0.7);
            cam.addTrauma(0.7);
            compare(cam.trauma, 1);
            cam._advanceJuice(0.1);
            fuzzyCompare(cam.trauma, 1 - cam.traumaDecay * 0.1, 1e-6);
            for (var i = 0; i < 100; ++i) cam._advanceJuice(0.02);
            compare(cam.trauma, 0);
            compare(cam.shakeXWu, 0);
            compare(cam.shakeYWu, 0);
            compare(cam.cameraX, 10);
        }

        function test_shakeIsBoundedByTraumaSquared() {
            cam.trauma = 0.5;
            var maxSeen = 0;
            for (var i = 0; i < 20; ++i) {
                cam._advanceJuice(0.005);
                var bound = cam.trauma * cam.trauma * cam.maxShakeWu;
                verify(Math.abs(cam.shakeXWu) <= bound + 1e-9);
                verify(Math.abs(cam.shakeYWu) <= bound + 1e-9);
                maxSeen = Math.max(maxSeen, Math.abs(cam.shakeXWu), Math.abs(cam.shakeYWu));
                fuzzyCompare(cam.cameraX, 10 + cam.shakeXWu, 1e-9);
            }
            verify(maxSeen > 0, "a shake moves the camera");
        }

        function test_shakeIsSmooth() {
            // Consecutive samples 1/120 s apart stay close: noise, not jitter.
            cam.trauma = 1;
            cam._advanceJuice(1 / 120);
            var prev = cam.shakeXWu;
            for (var i = 0; i < 30; ++i) {
                cam.trauma = 1;
                cam._advanceJuice(1 / 120);
                verify(Math.abs(cam.shakeXWu - prev) < 0.35 * cam.maxShakeWu,
                       "step " + i + ": " + prev + " -> " + cam.shakeXWu);
                prev = cam.shakeXWu;
            }
        }

        function test_kickSpringsBack() {
            cam.kick(1, -0.5);
            compare(cam.kickXWu, 1);
            compare(cam.kickYWu, -0.5);
            fuzzyCompare(cam.cameraX, 11, 1e-9);
            cam._advanceJuice(0.05);
            verify(cam.kickXWu < 1, "the spring pulls back");
            for (var i = 0; i < 200; ++i) cam._advanceJuice(1 / 60);
            compare(cam.kickXWu, 0);
            compare(cam.kickYWu, 0);
            compare(cam.cameraX, 10);
        }

        function test_clayInspectReportsShake() {
            cam.addTrauma(0.4);
            cam.kick(0.2, 0);
            var info = cam.clayInspect();
            fuzzyCompare(info.shake.trauma, 0.4, 1e-6);
            compare(info.kickWu[0], 0.2);
            compare(info.baseCenterWu[0], 10);
            compare(info.shake.maxShakeWu, cam.maxShakeWu);
        }

        function test_hitStopScalesAndRestores() {
            var base = world.physics.timeScale;
            world.hitStop(150, 0);
            verify(world.hitStopActive);
            compare(world.physics.timeScale, 0);
            compare(world.clayInspect().hitStop.active, true);
            tryCompare(world, "hitStopActive", false, 2000);
            compare(world.physics.timeScale, base);
        }

        function test_hitStopCoalesces() {
            world.hitStop(300, 0.5);
            world.hitStop(40, 0.2);
            // The stronger scale and the later end win.
            fuzzyCompare(world.physics.timeScale, 0.2 * Clayground.timeScale, 1e-6);
            verify(world.clayInspect().hitStop.remainingMs > 150);
            wait(120);
            verify(world.hitStopActive, "the short call does not end the long one");
            tryCompare(world, "hitStopActive", false, 2000);
            compare(world.physics.timeScale, Clayground.timeScale);
        }

        function test_hitStopKeepsGlobalTimeScale() {
            var old = Clayground.timeScale;
            Clayground.timeScale = 0.5;
            compare(world.physics.timeScale, 0.5);
            world.hitStop(60, 0.5);
            fuzzyCompare(world.physics.timeScale, 0.25, 1e-6);
            tryCompare(world, "hitStopActive", false, 2000);
            compare(world.physics.timeScale, 0.5);
            Clayground.timeScale = old;
        }
    }
}
