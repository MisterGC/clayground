// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.GameController

ClayWorld3d {
    id: _world
    anchors.fill: parent

    property var player: null
    onMapAboutToBeLoaded: player = null;
    Component.onCompleted: {
        theGameCtrl.forceActiveFocus();
        const wSizeHalf = _world.xWuMax * .5;
        _world.camera.position = Qt.vector3d(1020, 2184 , 1150);
        _world.camera.lookAt(Qt.vector3d(1020,0,1150));
        scene = "map2d.svg";
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

    // Vehicle {
    //     id: _vehicle
    //     parent: _world.root

    //     // physics
    //     position: Qt.vector3d(800, 175, -850)

    //     gravity: _world.physics.gravity
    //     sendTriggerReports: true

    //     // movement configuration
    //     maxSpeed: 500
    //     speedDesire: -theGameCtrl.axisY
    //     maxTurnSpeed: 10
    //     turnDesire: -theGameCtrl.axisX
    // }

    onMapEntityCreated: (obj, groupId, compName) => {
        if (obj instanceof Player3d) {
            player = obj;
            // movement configuration
            //bind speedDesire to -theGameCtrl.axis
            player.maxSpeed = 500
            observedObject = player;
        }
    }

    component WallElement : StaticRigidBody {
        scale: Qt.vector3d(.5, .5, .5)
        collisionShapes: BoxShape { id: boxShape }
        readonly property Model model: _wallElementModel
        Model {
            id: _wallElementModel
            source: "#Cube"
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0, 0, 1, 1)
            }
            castsShadows: true
        }
    }

    //observedObject: _vehicle
    showFloorGrid: true
    xWuMax: 100

    Component { id: playerComp; Player3d {} }
    components: new Map([
                            ['Wall', wallComp],
                            ['Player', playerComp]
                        ])

    Component { id: wallComp; WallElement {} }
}
