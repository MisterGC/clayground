// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ClayWorld3d's built-in camera control, which was dead for as long as
// nobody looked (#189).
//
// The binding that chooses between the two controllers named an id that does
// not exist, so it threw, the Loader3D never resolved a component, and
// neither WasdController nor OrbitCameraController was ever instantiated.
// freeCamera selected nothing and a sandbox relying on the world for
// navigation got a camera it could not move.
//
// The failure mode is SILENCE: a binding that throws leaves an empty loader,
// and nothing anywhere says so. Only an assertion on the loaded item catches
// it, which is what this is. Every demo declares its own controller, which is
// why it survived so long.

import QtQuick
import QtTest
import QtQuick3D
import Clayground.World

Item {
    id: root
    width: 200; height: 200

    ClayWorld3d {
        id: world
        components: new Map()
        anchors.fill: parent
    }

    // The world nests its controller in a Loader3D inside the viewport. What
    // it is called is nobody's business but the world's; that one exists is.
    function controllerCount() {
        return countIn(world, 0)
    }
    function countIn(node, depth) {
        if (!node || depth > 8) return 0
        let n = 0
        const kids = node.children ? node.children : []
        for (let i = 0; i < kids.length; ++i) {
            const c = kids[i]
            const t = "" + c
            if (t.indexOf("WasdController") === 0
                || t.indexOf("OrbitCameraController") === 0)
                ++n
            n += countIn(c, depth + 1)
        }
        return n
    }

    TestCase {
        name: "ClayWorld3dCamera"
        when: windowShown

        function test_a_controller_is_loaded_for_either_mode() {
            // Orbit by default: observedObject is not the free-cam node.
            tryVerify(function() { return root.controllerCount() > 0 }, 4000,
                      "no camera controller was instantiated - has the "
                      + "sourceComponent binding lost its id again?")
        }

        function test_freeCamera_reports_the_mode_it_is_in() {
            // The property the binding reads. If this is not reachable the
            // binding cannot be either.
            verify(world.freeCamera === true || world.freeCamera === false,
                   "freeCamera did not evaluate: " + world.freeCamera)
        }
    }
}
