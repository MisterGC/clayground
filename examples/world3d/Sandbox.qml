// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers
import QtQuick.Window

import Clayground.GameController

Rectangle {
    id: _mainItem
    color: "green"

    Component.onCompleted: {
        if (!_world.freeCamera)
            theGameCtrl.forceActiveFocus();
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

    Vehicle {
        id: _vehicle
        parent: _world.root

        // physics
        position: Qt.vector3d(800, 175, -850)

        gravity: _world.physics.gravity
        sendTriggerReports: true

        // movement configuration
        maxSpeed: 500
        speedDesire: -theGameCtrl.axisY
        maxTurnSpeed: 10
        turnDesire: -theGameCtrl.axisX
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

    ClayWorld3d {
        id: _world
        anchors.fill: parent

        //observedObject: _vehicle
        showFloorGrid: true
        size: 100

        Component.onCompleted: {
            if (_world.freeCamera) {
                const wSizeHalf = _world.size * .5
                _world.camera.position = Qt.vector3d(1020, 2184 , 1150)
                _world.camera.lookAt(Qt.vector3d(1020,0,1150))
            }
            scene = "map.svg"
        }

        scene: ""
        components: new Map([
                                ['Wall', wallComp]
                            ])
        onMapEntityCreated: (obj, groupId, compName) => {
                                let model = obj.model
                                let max = model.bounds.maximum
                                let min = model.bounds.minimum
                                console.log(max)
                                console.log(min)
                            }
        Component { id: wallComp; WallElement {} }
    }
}
