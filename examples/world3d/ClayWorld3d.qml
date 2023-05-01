// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

Item {
    id: _clayWorld3d

    readonly property Node sceneNode: _daScene
    readonly property PhysicsWorld physics: _physicsWorld
    property alias observedObject: _cameraRoot.parent

    // Floor configuration
    // Size of the quadratic floor in world units
    property real floorSize: 100
    // Wether to show a grid or not
    property bool showFloorGrid: false

    PhysicsWorld {
        id: _physicsWorld
        running: true
        scene: _daScene
        forceDebugDraw: true
    }

    View3D {
        id: _viewport
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#d6dbdf"
            backgroundMode: SceneEnvironment.Color
        }
        camera: _camera

        Node {
            id: _cameraRoot
            PerspectiveCamera {
                id: _camera
                z: 700
                y: 100
                clipFar: 5000
                clipNear: 1
            }
        }
        OrbitCameraController {
            camera: _camera
            origin: _cameraRoot
            anchors.fill: parent
            panEnabled: false
            Keys.forwardTo: theGameCtrl
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
                    scale: Qt.vector3d(_clayWorld3d.floorSize,
                                       _clayWorld3d.floorSize,
                                       1)
                    materials: DefaultMaterial {
                        diffuseColor: "#214478"

                    }
                    castsShadows: true
                    receivesShadows: true
                }
                Loader3D
                {
                    id: _gridLoader
                    active: _clayWorld3d.showFloorGrid
                    sourceComponent: _gridComp
                    Component {
                        id: _gridComp
                    Model {
                        scale: Qt.vector3d(_floorModel.scale.x*100,
                                           _floorModel.scale.y*100, 1)
                        position: Qt.vector3d(0, 50, 0)
                        geometry: GridGeometry {
                            horizontalLines: 10
                            verticalLines: 10
                        }
                        materials: [ DefaultMaterial { } ]
                        castsShadows: false
                    }
                    }
                }
            }
            Floor {}
        }
    }

}
