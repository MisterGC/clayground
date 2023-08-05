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
        onPositionChanged: {
            //console.log(position)
        }

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
            position.z: 10
            source: "#Cube"
            materials: PrincipledMaterial {
                baseColor: Qt.rgba(0, 0, 1, 1)
            }
//            onBoundsChanged: {
//                console.log("BOUNDS")
//                console.log(bounds.minimum + " -> " + bounds.maximum)
//                console.log("scale: " + parent.scale)
//                console.log("pos: " + parent.position)
//                console.log(
//                            "l: " + dim.x * scale.x +
//                            "w: " + dim.z * scale.z +
//                            "h: " + dim.y * scale.y)
//            }
//            onScaleChanged: {
//                console.log("SCALE")
//                console.log(bounds.minimum + " -> " + bounds.maximum)
//                let dim = bounds.maximum - bounds.minimum
//                console.log("scale: " + scale)
//                console.log(
//                            "l: " + dim.x * scale.x +
//                            "w: " + dim.z * scale.z +
//                            "h: " + dim.y * scale.y)

//            }

            castsShadows: true
        }
    }

    ClayWorld3d {
        id: _world
        anchors.fill: parent
        //observedObject: _cubus
        showFloorGrid: true
        size: 100


        scene: ""
        Component.onCompleted: scene = "map.svg"
        components: new Map([
                                ['Wall', wallComp]
                            ])
        onMapEntityCreated: (obj, groupId, compName) => {
                                console.log("Blub " + obj)
                                let model = obj.model
                                let max = model.bounds.maximum
                                let min = model.bounds.minimum
                                console.log(max)
                                console.log(min)
                            }
        Component { id: wallComp; WallElement {} }
    }

    Node {
        id: _scene
        parent: _world.sceneNode

//        Node { property int size: 1000
//            Node {
//                y: 100
//                Rectangle{
//                    color: white
//                    width: txt.width * 1.1
//                    height: txt.height * 1.1
//                    Text{
//                        id: txt
//                        text: "min: " + _cubus.bounds.minimum + "\n" +
//                              "max: " + _cubus.bounds.maximum + "\n"
//                    }
//                }
//            }
//            Model {
//                id: _cubus
//                property real size: parent.size / 100
//                position: Qt.vector3d(parent.size * .5, 0, parent.size * .5)
//                scale: Qt.vector3d(size, size, size)
//                source: "#Cube"
//                materials: PrincipledMaterial {
//                    baseColor: Qt.rgba(1, 0, 0, 1)
//                }
//                castsShadows: true
//            }
//        }


        Repeater3D {
            model: 0
            delegate: WallElement {
                position: Qt.vector3d(
                              2000 * Math.random() * (Math.random() > .5 ? -1 : 1),
                              100 ,
                              2000 * Math.random() * (Math.random() > .5 ? -1 : 1))

            }
        }
    }
}
