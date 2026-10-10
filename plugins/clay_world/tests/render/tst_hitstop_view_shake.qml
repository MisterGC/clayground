// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A view-only hit stop holds the picture, but not the camera: shake and kick
// keep moving the held frame, and a stop with a scale above 0 captures the
// canvas again at that rate (#415). The world is larger than the view, so
// the viewport has room to shake.

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
        xWuMin: 0; xWuMax: 80
        yWuMin: 0; yWuMax: 60
        pixelPerUnit: 10
        hitStopMode: "view"

        camera: ClayWorld2dCamera {
            id: cam
            target: anchor
            maxShakeWu: 2
        }

        RectBoxBody {
            id: anchor
            bodyType: Body.Static
            xWu: 40; yWu: 30
            widthWu: 2; heightWu: 2
            color: "#2060ff"
        }

        RectBoxBody {
            id: box
            bodyType: Body.Kinematic
            xWu: 25; yWu: 30
            widthWu: 3; heightWu: 3
            color: "#ff4020"
        }
    }

    TestCase {
        id: testCase
        name: "HitStopViewShake"
        when: windowShown

        function init() {
            tryCompare(world, "hitStopActive", false, 2000);
            cam.resetShake();
            box.linearVelocity = Qt.point(0, 0);
            box.xWu = 25;
            wait(50);
        }

        // Pictures that differ from each other among the grabs.
        function distinct(images) {
            var seen = [];
            for (var i = 0; i < images.length; ++i) {
                var known = false;
                for (var k = 0; k < seen.length && !known; ++k)
                    known = seen[k].equals(images[i]);
                if (!known) seen.push(images[i]);
            }
            return seen.length;
        }

        function test_heldFrameFollowsTheShake() {
            cam.addTrauma(1);
            world.hitStop(200, 0);
            wait(40);
            var first = grabImage(root);
            verify(first.width > 0, "the platform renders pixels - see RENDERS in claytest.cmake");
            var shiftFirst = world.clayInspect().hitStop.heldShiftPx;
            var posFirst = world.picture.mapToItem(root, 0, 0);
            wait(40);
            verify(world.hitStopActive, "both frames are inside the stop");
            var second = grabImage(root);
            var shiftSecond = world.clayInspect().hitStop.heldShiftPx;
            var posSecond = world.picture.mapToItem(root, 0, 0);
            verify(!first.equals(second), "the two frames differ");
            verify(posFirst.x !== posSecond.x || posFirst.y !== posSecond.y,
                   "the held item moves on screen: " + posFirst + " -> " + posSecond);
            verify(shiftFirst[0] !== shiftSecond[0] || shiftFirst[1] !== shiftSecond[1],
                   "the shake moves the held frame: " + shiftFirst + " -> " + shiftSecond);
            compare(world.clayInspect().hitStop.heldCaptures, 1, "a stop at 0 captures once");
        }

        function test_heldFrameFollowsTheKick() {
            world.hitStop(200, 0);
            wait(40);
            compare(world.clayInspect().hitStop.heldShiftPx, [0, 0]);
            cam.kick(1, 0);
            wait(1);
            // The viewport moved right by the kick (spring back included),
            // so the held content moves left by the same amount.
            var expected = -cam.kickXWu * world.pixelPerUnit;
            var shift = world.clayInspect().hitStop.heldShiftPx;
            verify(shift[0] < 0, "the kick moves the frame against it: " + shift);
            fuzzyCompare(shift[0], expected, 0.01);
        }

        function test_withoutShakeTheFrameStands() {
            world.hitStop(200, 0);
            wait(40);
            var first = grabImage(root);
            wait(80);
            verify(world.hitStopActive);
            compare(world.clayInspect().hitStop.heldShiftPx, [0, 0]);
            verify(first.equals(grabImage(root)), "no shake, no kick: the frame holds still");
        }

        function test_slowedStopAdvancesThePicture() {
            box.linearVelocity = Qt.point(30, 0);
            wait(50);
            world.hitStop(200, 0.25);
            var images = [];
            for (var i = 0; i < 6; ++i) {
                wait(25);
                images.push(grabImage(root));
            }
            verify(world.hitStopActive, "all grabs are inside the stop");
            var n = distinct(images);
            verify(n >= 2, "a slowed stop shows the world moving on, " + n + " pictures");
            verify(world.clayInspect().hitStop.heldCaptures >= 2,
                   "captured again: " + world.clayInspect().hitStop.heldCaptures);
        }

        function test_frozenStopShowsOnePicture() {
            box.linearVelocity = Qt.point(30, 0);
            wait(50);
            world.hitStop(200, 0);
            var images = [];
            for (var i = 0; i < 6; ++i) {
                wait(25);
                images.push(grabImage(root));
            }
            verify(world.hitStopActive, "all grabs are inside the stop");
            compare(distinct(images), 1, "a stop at 0 holds one picture");
        }
    }
}
