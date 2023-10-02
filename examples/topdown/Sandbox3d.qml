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

    onMapEntityCreated: (obj, groupId, compName) => {
        if (obj instanceof Player3d) {
            player = obj;
            player.maxSpeed = 100
            observedObject = player;
            camera.position = Qt.vector3d(0, player.dimensions.y * 100, 0)
        }
    }

    Component { id: playerComp; Player3d {} }
    components: new Map([
                            ['Wall', wallComp],
                            ['Player', playerComp]
                        ])

    Component { id: wallComp; Wall3d {} }
}
