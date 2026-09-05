// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// MarkLayer, against a stub view and a stub camera.
//
// Two claims are worth a suite here, and both are the kind that fail
// invisibly. The first is the projection dependency: a screen-space overlay
// over a 3D scene has to re-project when the camera moves, and a binding that
// forgot to name `camera.scenePosition` looks perfect until the rig does -
// which, in a lab whose lessons move the camera for every step, means every
// mark sits on the wrong part. The second is the keep-out: a ring drawn where
// the presenter is standing marks the presenter's coat, and there is no depth
// test in screen space to stop it.
//
// Neither needs a GPU, a window or a real View3D: the layer only ever asks
// its view to map one point, so a stub answers.

import QtQuick
import QtTest
import Clayground.Lab

Item {
    id: root
    width: 200; height: 200

    // Stands in for a camera. The values are only ever read as binding
    // dependencies, so what they hold does not matter - that they CHANGE does.
    QtObject {
        id: cam
        property vector3d scenePosition: Qt.vector3d(0, 0, 0)
        property var sceneRotation: null
    }

    // Stands in for a View3D: a projection that moves with the camera, so a
    // mark that does not follow it can be told from one that does.
    // It counts nothing: a stub that wrote a property of its own inside the
    // call would be read AND written by the projection binding, and QML calls
    // that a binding loop.
    QtObject {
        id: view
        function mapFrom3DScene(p) {
            return Qt.vector3d(p.x - cam.scenePosition.x,
                               p.y - cam.scenePosition.y,
                               1)          // in front of the camera
        }
    }

    MarkLayer {
        id: layer
        anchors.fill: parent
        view: view
        camera: cam
        pulseMs: 0            // no animation to wait on
    }

    TestCase {
        name: "MarkLayer"
        when: windowShown

        function markItems() {
            const out = []
            for (let i = 0; i < layer.children.length; ++i)
                if (layer.children[i].objectName === "mark")
                    out.push(layer.children[i])
            return out
        }

        function init() {
            layer.keepOut = null
            layer.marks = []
            cam.scenePosition = Qt.vector3d(0, 0, 0)
        }

        function test_empty_draws_nothing() {
            compare(layer.count, 0)
            compare(markItems().length, 0)
        }

        function test_both_spellings_are_accepted() {
            layer.marks = [Qt.vector3d(10, 20, 0),
                           { at: Qt.vector3d(30, 40, 0), label: "collector" }]
            compare(layer.count, 2)
            const items = markItems()
            compare(items.length, 2)
            compare(items[0].modelData.label, "", "a bare point has no caption")
            compare(items[1].modelData.label, "collector")
        }

        function test_entries_without_a_point_are_dropped() {
            // What an unresolved name used to look like: a ring at the origin.
            layer.marks = [null, {}, { at: null, label: "nowhere" },
                           Qt.vector3d(1, 2, 0)]
            compare(layer.count, 1)
            compare(markItems().length, 1)
        }

        function test_marks_are_placed_where_they_project() {
            layer.marks = [Qt.vector3d(10, 20, 0)]
            const m = markItems()[0]
            compare(m.x, 10)
            compare(m.y, 20)
            compare(layer.screenOf(0).x, 10)
            compare(layer.screenOf(0).y, 20)
        }

        // The one this component exists to get right.
        function test_a_mark_survives_the_camera_moving() {
            layer.marks = [Qt.vector3d(10, 20, 0)]
            const m = markItems()[0]
            compare(m.x, 10)
            cam.scenePosition = Qt.vector3d(4, 0, 0)
            compare(m.x, 6, "the mark re-projected when the camera moved")
            cam.scenePosition = Qt.vector3d(-6, 0, 0)
            compare(m.x, 16)
        }

        function test_a_point_behind_the_camera_is_not_drawn() {
            layer.marks = [Qt.vector3d(10, 20, 0)]
            compare(markItems()[0].shown, true)
            // The stub reports z = 1; a real view reports <= 0 behind it.
            layer.view = null
            compare(markItems()[0].shown, false)
            layer.view = view
        }

        function test_keep_out_answers_for_a_point() {
            compare(layer.clear(10, 10), true, "no box: everything is clear")
            layer.keepOut = ({ x: 0, y: 0, width: 50, height: 50 })
            compare(layer.clear(10, 10), false)
            compare(layer.clear(60, 10), true)
            compare(layer.clear(10, 60), true)
            compare(layer.clear(50, 50), false, "the edge belongs to the box")
        }

        // Never sits on the presenter: a mark whose point lands inside the
        // box goes to zero opacity, and comes back when it leaves.
        function test_a_mark_on_the_presenter_fades_out() {
            layer.keepOut = ({ x: 0, y: 0, width: 50, height: 50 })
            layer.marks = [Qt.vector3d(10, 20, 0), Qt.vector3d(120, 120, 0)]
            const items = markItems()
            compare(items[0].shown, false, "inside the presenter's box")
            compare(items[1].shown, true, "well clear of it")
            tryCompare(items[0], "opacity", 0)
            tryCompare(items[1], "opacity", 1)
            // The presenter walks off: the mark comes back.
            layer.keepOut = null
            compare(items[0].shown, true)
            tryCompare(items[0], "opacity", 1)
        }

        function test_replacing_the_list_replaces_the_marks() {
            layer.marks = [Qt.vector3d(1, 1, 0), Qt.vector3d(2, 2, 0)]
            compare(layer.count, 2)
            layer.marks = [Qt.vector3d(3, 3, 0)]
            compare(layer.count, 1)
            compare(markItems().length, 1)
            layer.marks = []
            compare(layer.count, 0)
            compare(markItems().length, 0)
        }

        function test_screenOf_is_bounds_checked() {
            layer.marks = [Qt.vector3d(1, 1, 0)]
            compare(layer.screenOf(-1).x, 0)
            compare(layer.screenOf(7).x, 0)
        }
    }
}
