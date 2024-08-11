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

    // Camera properties
    property alias observedObject: _cameraRoot.parent
    property alias camera: _camera
    // If true the camera can be moved around with WASD keys
    readonly property bool freeCamera: observedObject == _freeCamEnabled
    onObservedObjectChanged: {
        if (observedObject != _freeCamEnabled)
        {
           camera.position = Qt.vector3d(0,1200,0)
        }
    }

    // Floor configuration
    // Size of the quadratic floor in world units
    readonly property real xWuMin: 0
    property real xWuMax: 100
    readonly property real zWuMin: 0
    property real zWuMax: 100
    property alias floor: _floor

    _sceneLoader: SceneLoader3d {
        world: _clayWorld3d
        loadEntitiesAsync: _clayWorld3d.loadMapAsync
    }

    PhysicsWorld {
        id: _physicsWorld
        running: true
        scene: _daScene
        forceDebugDraw: _clayWorld3d.debugPhysics
        gravity: Qt.vector3d(0, -9.81, 0)
    }

    View3D {
        id: _viewport
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "black"
            backgroundMode: SceneEnvironment.Color
        }
        camera: _camera
        AxisHelper { id: _axisHelper; visible: _clayWorld3d.debugRendering }

        Loader3D {
            sourceComponent: _world.freeCamera ? _wasdCtrl : _orbitCtrl
            Component {
                id: _wasdCtrl
                WasdController {
                    parent: _viewport
                    controlledObject: _world.camera
                }
            }
            Component {
                id: _orbitCtrl
                OrbitCameraController {
                    parent: _viewport
                    camera: _world.camera
                    origin: _cameraRoot
                    panEnabled: false
                }
            }
        }

        Node {
            id: _freeCamEnabled
            Node {
                id: _cameraRoot
                PerspectiveCamera { id: _camera; clipFar: 5000; clipNear: 1}
            }
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
                    position: Qt.vector3d(_clayWorld3d.xWuMax * .5,
                                          -_clayWorld3d.zWuMax * .5, 0)
                    scale: Qt.vector3d(_clayWorld3d.xWuMax / 100,
                                       _clayWorld3d.zWuMax / 100,
                                       1)
                    materials: DefaultMaterial {
                        diffuseColor: "#214478"

                    }
                    castsShadows: false
                    receivesShadows: true
                }
            }
            Floor {
                id: _floor
            }
        }
    }

}
