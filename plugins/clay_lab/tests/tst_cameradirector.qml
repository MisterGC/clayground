// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The shot grammar, checked the way a shot is judged: by what ends up in the
// picture. Every case reads the rig back through covers(), so a director
// that moved the camera somewhere clever but lost the subject fails here.
//
// The presenter is a stand-in - a stand, a height and a travelling flag -
// because that is all the director is allowed to know about one.

import QtQuick
import QtTest
import Clayground.Canvas3D
import Clayground.Lab

Item {
    width: 50; height: 50

    // electronics-101's rig, snapping so a shot can be read on the next line
    OrbitCamera3D {
        id: rig
        pitch: 48; distance: 80
        minPitch: 22; maxPitch: 84
        minDistance: 20; maxDistance: 170; minHeight: 9
        smoothMs: 0; travelMs: 0
        homePivot: Qt.vector3d(0, 2, 0)
    }

    QtObject {
        id: prof
        property vector3d stand: Qt.vector3d(-37.5, 0, -9)
        property real standHeight: 8
        property bool travelling: false
        property bool present: true
    }

    CameraDirector {
        id: director
        rig: rig
        presenter: prof
        cutMs: 0
        safe: ({ top: 0.1, bottom: 0.18, left: 0.03, right: 0.03 })
    }

    TestCase {
        name: "CameraDirector"
        when: windowShown

        readonly property var part: [Qt.vector3d(-44, 2, -30), Qt.vector3d(-30, 2, -16)]

        function reset() {
            director.release()
            prof.travelling = false
            prof.stand = Qt.vector3d(-37.5, 0, -9)
            rig.applyState({ yaw: 0, pitch: 48, distance: 80, px: 0, py: 2, pz: 0 })
        }

        function test_two_shot_holds_the_part_and_the_presenter() {
            reset()
            verify(director.twoShot(part))
            compare(director.shot, "two")
            verify(rig.covers(part, 0.05, true), "the part is in the picture")
            verify(rig.covers(director.presenterPoints(), 0.05, true), "and so is the presenter")
            compare(rig.goalPitch, director.widePitch, "from the presenting angle")
        }

        function test_portrait_relaxes_the_floors_and_the_next_shot_restores_them() {
            reset()
            verify(director.portrait())
            compare(director.shot, "portrait")
            compare(rig.minPitch, 6, "the board floor is off for the portrait")
            compare(rig.goalPitch, director.portraitPitch, "level with the face")
            verify(rig.covers(director.shotPoints, 0.02, true), "the figure is in the picture")
            director.twoShot(part)
            compare(rig.minPitch, 22, "and back for anything else")
            compare(rig.minHeight, 9)
        }

        function test_journey_holds_both_ends_and_follows_until_landing() {
            reset()
            const to = Qt.vector3d(32.5, 0, -14)
            verify(director.journey(to, part))
            compare(director.shot, "journey")
            verify(rig.covers(director.presenterPoints(), 0.02, true), "where it stands")
            verify(rig.covers(director.presenterPoints(to), 0.02, true), "where it is going")
            verify(rig.covers(part, 0.02, true), "what it will talk about")
            verify(typeof rig.follow === "function", "the follow is on")
            prof.travelling = true
            prof.stand = to
            prof.travelling = false
            compare(rig.follow, null, "and off again once it has landed")
        }

        function test_cutaway_comes_back_to_the_shot_before() {
            reset()
            director.twoShot(part)
            const before = rig.state()
            const led = Qt.vector3d(-7.5, 2, -1)
            verify(director.cutaway([led], 60))
            compare(director.shot, "cutaway")
            verify(rig.covers([led], 0.3, true), "the insert is close on the thing")
            verify(rig.goalDistance < before.distance, "closer than the two-shot was")
            wait(200)
            compare(director.shot, "two", "the two-shot is back")
            fuzzyCompare(rig.goalDistance, before.distance, 1e-3)
            fuzzyCompare(rig.goalPivot.x, before.px, 1e-3)
        }

        function test_a_new_shot_cancels_a_pending_return() {
            reset()
            director.twoShot(part)
            director.cutaway([Qt.vector3d(0, 2, 0)], 60)
            director.portrait()
            wait(200)
            compare(director.shot, "portrait", "the later shot wins, the return is forgotten")
        }

        function test_establish_shows_the_title_for_the_hold_and_frames_it_all() {
            reset()
            const board = [Qt.vector3d(-70, 2, -40), Qt.vector3d(70, 2, 40)]
            verify(director.establish(board, "AND gate", 80))
            compare(director.shot, "wide")
            compare(director.title, "AND gate")
            verify(rig.covers(board, 0.02, true), "the whole setup is in the picture")
            wait(200)
            compare(director.title, "", "the card comes down after the hold")
            compare(director.shot, "wide", "and the shot stays")
        }

        function test_release_hands_the_camera_back() {
            reset()
            director.journey(Qt.vector3d(10, 0, 10), part)
            director.portrait()
            director.establish([Qt.vector3d(0, 0, 0), Qt.vector3d(10, 0, 10)], "x", 5000)
            director.release()
            compare(director.shot, "")
            compare(director.title, "")
            compare(rig.follow, null)
            compare(rig.minPitch, 22)
            compare(rig.minHeight, 9)
        }

        function test_nothing_to_direct_does_nothing() {
            reset()
            const s = rig.state()
            verify(!director.wide([]))
            verify(!director.twoShot(null))
            compare(director.shot, "")
            compare(rig.state().distance, s.distance)
        }
    }
}
