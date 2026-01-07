// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorld3d
    \inqmlmodule Clayground.World
    \inherits ClayWorldBase
    \brief Complete 3D game world with physics, camera, and scene loading.

    ClayWorld3d provides a 3D game world with Qt Quick 3D physics, automatic
    camera following or free WASD camera control, and SVG-based scene loading
    where rectangles become 3D objects.

    Example usage:
    \qml
    import Clayground.World

    ClayWorld3d {
        anchors.fill: parent
        xWuMax: 200; zWuMax: 200
        observedObject: player

        Box3DBody {
            id: player
            position: Qt.vector3d(50, 10, 50)
            width: 20; height: 20; depth: 20
        }
    }
    \endqml

    \qmlproperty Node ClayWorld3d::root
    \readonly
    \brief Root 3D scene node for adding entities.

    \qmlproperty PhysicsWorld ClayWorld3d::physics
    \readonly
    \brief The Qt Quick 3D physics world.

    \qmlproperty Node ClayWorld3d::observedObject
    \brief Object the camera follows. Set to null for free camera.

    \qmlproperty vector3d ClayWorld3d::observationOffset
    \brief Camera offset from observed object.

    \qmlproperty PerspectiveCamera ClayWorld3d::camera
    \brief The main camera.

    \qmlproperty bool ClayWorld3d::freeCamera
    \readonly
    \brief True when WASD camera control is active.

    \qmlproperty real ClayWorld3d::xWuMin
    \readonly
    \brief Minimum X coordinate (always 0).

    \qmlproperty real ClayWorld3d::xWuMax
    \brief Maximum X world size.

    \qmlproperty real ClayWorld3d::zWuMin
    \readonly
    \brief Minimum Z coordinate (always 0).

    \qmlproperty real ClayWorld3d::zWuMax
    \brief Maximum Z world size.

    \qmlproperty StaticRigidBody ClayWorld3d::floor
    \brief The ground plane physics body.
*/
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
    property vector3d observationOffset: Qt.vector3d(0,100,0)
    property alias camera: _camera
    // If true the camera can be moved around with WASD keys
    readonly property bool freeCamera: observedObject == _freeCamEnabled
    onObservedObjectChanged: {
        if (observedObject != _freeCamEnabled)
        {
           camera.position = Qt.binding(function() { return _clayWorld3d.observationOffset; })
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
