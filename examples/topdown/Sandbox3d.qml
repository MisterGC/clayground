// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.GameController
import Clayground.World

ClayWorld3d {
    id: _world
    anchors.fill: parent

    debugRendering: false

    // Add a ground plane to prevent falling
    StaticRigidBody {
        position: Qt.vector3d(0, -10, 0)
        collisionShapes: BoxShape {
            extents: Qt.vector3d(10000, 20, 10000)
        }
    }

    property var player: null
    onMapAboutToBeLoaded: player = null;
    Component.onCompleted: {
        theGameCtrl.forceActiveFocus();
        const wSizeHalf = _world.xWuMax * .5;
        _world.camera.position = Qt.vector3d(1020, 2184 , 1150);
        _world.camera.lookAt(Qt.vector3d(1020,0,1150));
        scene = "map.svg";
    }
    Keys.forwardTo: _world.freeCamera ? _world : theGameCtrl

    GameController {
        id: theGameCtrl;
        z: 99
        anchors.fill: parent;
        //showDebugOverlay: true
        Component.onCompleted: {
            selectKeyboard(Qt.Key_W, Qt.Key_S,
                           Qt.Key_A, Qt.Key_D,
                           Qt.Key_J, Qt.Key_K);
        }
    }

    onMapEntityCreated: (obj, groupId, cfg) => {
        if (obj instanceof Player3d) {
            player = obj;
            player.maxSpeed = 100
            observedObject = player;
        }
        else if (obj instanceof Wall3d) {
            const c = Qt.color(cfg.clayFillColor);

            // Hue is using degrees in SVG
            const HSL_HUE_MAX = 360;
            // Saturation and Lightness use percentage values
            const HSL_LIGHTNESS_MAX = 100;
            const HSL_SATURATION_MAX = 100;

            // Use hslLightness for height (multiply by 2 for more variation)
            obj.height = c.hslLightness * 100;
            // Position wall so its bottom is at y=0
            obj.position.y = obj.height * 0.5;
            // Use the color from the SVG
            obj.color = c
        }
    }

    Component { id: playerComp; Player3d {} }
    components: new Map([
                            ['Wall', wallComp],
                            ['Player', playerComp]
                        ])

    Component { id: wallComp; Wall3d {} }
}
