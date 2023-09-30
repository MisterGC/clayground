// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.Svg
import Clayground.Common

ClayWorldBase {
    id: _clayWorld3d

    readonly property Node root: _daScene

    // Physics properties
    readonly property PhysicsWorld physics: _physicsWorld
    property alias debugPhysics: _physicsWorld.forceDebugDraw

    property alias observedObject: _cameraRoot.parent
    property alias camera: _camera

    // Floor configuration
    // Size of the quadratic floor in world units
    property real size: 100
    // Wether to show a grid or not
    property alias showFloorGrid: _axisHelper.enableXZGrid

    _sceneLoader: SceneLoader3d {
        world: _clayWorld3d
    }

    PhysicsWorld {
        id: _physicsWorld
        running: true
        scene: _daScene
    }

    View3D {
        id: _viewport
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#d6dbdf"
            backgroundMode: SceneEnvironment.Color
        }
        camera: _camera
        AxisHelper { id: _axisHelper }

        Node {
            id: _cameraRoot
            PerspectiveCamera {
                id: _camera
                z: 700
                y: 200
                clipFar: 5000
                clipNear: 1
            }
        }

        OrbitCameraController {
            camera: _camera
            origin: _cameraRoot
            anchors.fill: parent
            panEnabled: false
        }

        Node {
            id: _daScene

            DirectionalLight {
                eulerRotation: Qt.vector3d(-75, 0, 0)
                position: Qt.vector3d(-100, 400, -100)
                castsShadow: true
                brightness: 2
                shadowFactor: 100
            }

            DirectionalLight {
                parent: _camera
                position: Qt.vector3d(100, 400, -100)
                castsShadow: false
                brightness: 0.3
                shadowFactor: 100
            }

            component Floor : StaticRigidBody {

                eulerRotation: Qt.vector3d(-90, 0, 0)
                collisionShapes: PlaneShape {}
                Model {
                    id: _floorModel
                    source: "#Rectangle"
                    position: Qt.vector3d(_clayWorld3d.size * .5,
                                          -_clayWorld3d.size * .5, 0)
                    scale: Qt.vector3d(_clayWorld3d.size / 100,
                                       _clayWorld3d.size / 100,
                                       1)
                    materials: DefaultMaterial {
                        diffuseColor: "#214478"

                    }
                    castsShadows: true
                    receivesShadows: true
                }
            }
            Floor {}
        }
    }


}
