// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers
import QtQuick.Window

import Clayground.GameController

Rectangle {
    id: name
    color: "green"

    Keys.forwardTo: theGameCtrl
    GameController {
        id: theGameCtrl;
        anchors.fill: parent;
        Component.onCompleted: {
            selectKeyboard(Qt.Key_W, Qt.Key_S,
                           Qt.Key_A, Qt.Key_D,
                           Qt.Key_J, Qt.Key_K);
        }
    }

    Vehicle {
        id: _vehicle
        parent: _scene

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

    ClayWorld3d {
        id: _world
        anchors.fill: parent
        observedObject: _vehicle
        showFloorGrid: true
        floorSize: 100
    }

    Node {
        id: _scene
        parent: _world.sceneNode

        component WallElement : DynamicRigidBody {
            scale: Qt.vector3d(.5, .5, .5)
            collisionShapes: BoxShape { id: boxShape }
            Model {
                source: "#Cube"
                materials: PrincipledMaterial {
                    baseColor: Qt.rgba(Math.random(),
                                       Math.random(),
                                       Math.random(), 1)
                }
                castsShadows: true
            }
        }

        Repeater3D {
            model: 100
            delegate: WallElement {
                position: Qt.vector3d(
                              2000 * Math.random() * (Math.random() > .5 ? -1 : 1),
                              100 ,
                              2000 * Math.random() * (Math.random() > .5 ? -1 : 1))

            }
        }
    }
}
