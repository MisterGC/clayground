// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers
import QtQuick.Window

Rectangle {
    id: name
    color: "green"

    PhysicsWorld {
            id: _physicsWorld
            running: true
            scene: daScene
    }

    component Wheel: Model {
        id: _wheel
        source: "#Cylinder"
        eulerRotation.z: 90

        Connections {
            target: wasd
            function onMoveForwardsChanged()
            {
                if (wasd.moveForwards)
                {
                    _wheelRotator.forward = true;
                    _wheelRotator.start()
                }
                else
                    _wheelRotator.stop()
            }
            function onMoveBackwardsChanged()
            {
                if (wasd.moveBackwards)
                {
                    _wheelRotator.forward = false;
                    _wheelRotator.start()
                }
                else
                    _wheelRotator.stop()
            }
        }
        Timer {
            id: _wheelRotator
            property bool forward: true
            interval: 100
            repeat: true
            onTriggered: {
                let delta = forward ? -60 : 60
                _wheel.eulerRotation.x = (_wheel.eulerRotation.x + delta) % 360
            }
        }


        scale: Qt.vector3d(.25, .1, .25)
        materials: PrincipledMaterial { baseColor: "gray"}
        Model {
                id: _profile
                source: "#Cube"
                scale: Qt.vector3d(.25, .5, .5)
                position: Qt.vector3d(25, -15, -50)
                materials: PrincipledMaterial {
                        baseColor: "black"
                }
        }
    }

    component Player: CharacterController {
        id: _car
            position: Qt.vector3d(800, 175, -850)
            collisionShapes: CapsuleShape {
                    id: capsuleShape
                    diameter: 50
                    height: 45
            }


            Model {
                    id: _front
                    source: "#Cube"
                    scale: Qt.vector3d(.5, .5, .5)
                    materials: PrincipledMaterial {
                            baseColor: "yellow"
                    }

            }
            Model {
                    id: _back
                    source: "#Cube"
                    scale: Qt.vector3d(.49999, .25, .75)
                    position: Qt.vector3d(0, -14, 60)
                    materials: PrincipledMaterial {
                            baseColor: "yellow"
                    }

            }

            Wheel {position: Qt.vector3d(30, -30, -10) }
            Wheel {position: Qt.vector3d(30, -30, 65) }
            Wheel {position: Qt.vector3d(-30, -30, -10) }
            Wheel {position: Qt.vector3d(-30, -30, 65) }

            property real characterHeight: capsuleShape.height + capsuleShape.diameter

            sendTriggerReports: true

            movement: Qt.vector3d(0, 0, wasd.forwardSpeed)
            Behavior on movement {
                    PropertyAnimation { duration: 100 }
            }
        Connections {
            target: wasd
            function onMoveLeftChanged()
            {
                if (wasd.moveLeft)
                {
                    _carRotator.left = true;
                    _carRotator.start()
                }
                else
                    _carRotator.stop()
            }
            function onMoveRightChanged()
            {
                if (wasd.moveRight)
                {
                    _carRotator.left = false;
                    _carRotator.start()
                }
                else
                    _carRotator.stop()
            }
        }
        Timer {
            id: _carRotator
            property bool left: true
            interval: 100
            repeat: true
            onTriggered: {
                let delta = left ? 15 : -15
                _car.eulerRotation.y = (_car.eulerRotation.y + delta) % 360
            }
        }
        Behavior on eulerRotation.y {
            NumberAnimation{duration: 100}
        }

            gravity: _physicsWorld.gravity
    }

    View3D {
            id: viewport
            anchors.fill: parent

            environment: SceneEnvironment {
                    clearColor: "#d6dbdf"
                    backgroundMode: SceneEnvironment.Color
            }
            camera: _camera

            OrbitCameraController {
                    camera: _camera
                    origin: _cameraRoot
                    anchors.fill: parent
                    panEnabled: false
                    Keys.forwardTo: wasd
            }

            DirectionalLight {
                    eulerRotation: Qt.vector3d(-75, 0, 0)
                    position: Qt.vector3d(-100, 400, -100)
                    castsShadow: true
                    brightness: 1
                    shadowFactor: 100
            }

            PointLight {
                    z: 300
            }

            Node {
                    id: daScene

                    Model {
                            scale: Qt.vector3d(1000, 1000, 1000)
                            eulerRotation: Qt.vector3d(-90, 0, 0)
                            position: Qt.vector3d(0, -20, 0)
                            geometry: GridGeometry {
                                    horizontalLines: 100
                                    verticalLines: 100
                            }
                            materials: [ DefaultMaterial { } ]
                            castsShadows: false
                    }


                    component Floor : StaticRigidBody {
                            position: Qt.vector3d(0, -25, 0)
                            eulerRotation: Qt.vector3d(-90, 0, 0)
                            collisionShapes: PlaneShape {}
                            Model {
                                    source: "#Rectangle"
                                    scale: Qt.vector3d(100, 100, 100)
                                    materials: DefaultMaterial {
                                            diffuseColor: "#214478"
                                    }
                                    castsShadows: false
                                    receivesShadows: true
                            }
                    }

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


                    Floor {

                    }

                    Repeater3D {
                            model: 20
                            delegate: WallElement {
                                    position: Qt.vector3d(
                                                      2000 * Math.random() * (Math.random() > .5 ? -1 : 1),
                                                      100 ,
                                                      2000 * Math.random() * (Math.random() > .5 ? -1 : 1))

                            }
                    }

                    Player {
                            id: _player
                            Node {
                                    id: _cameraRoot
                                    PerspectiveCamera {
                                            id: _camera
                                            z: 100
                                            clipFar: 5000
                                            clipNear: 1
                                    }
                            }

                    }
            }
    }
    component Wasd: Item {
            id: _wasdCtrl

            property real xSpeed: 0.1
            property real ySpeed: 0.1

            property bool mouseEnabled: true
            property bool keysEnabled: true

            implicitWidth: parent.width
            implicitHeight: parent.height
            focus: keysEnabled

            property bool moveForwards: false
            property bool moveBackwards: false
            property bool moveLeft: false
            property bool moveRight: false

            property vector2d cameraRotation: Qt.vector2d(0, 0)

            TapHandler { onTapped: _wasdCtrl.forceActiveFocus() }

            Keys.onPressed: (event) => { if (keysEnabled) handleKeyPress(event) }
            Keys.onReleased: (event) => { if (keysEnabled && !event.isAutoRepeat) handleKeyRelease(event) }

            function forwardPressed() {
                console.log("Pressed")
                moveForwards = true
                moveBackwards = false
            }

            function forwardReleased() {
                console.log("Released")
                    moveForwards = false
            }

            function backPressed() {
                    moveBackwards = true
                    moveForwards = false
            }

            function backReleased() {
                    moveBackwards = false
            }

            function rightPressed() {
                    moveRight = true
                    moveLeft = false
            }

            function rightReleased() {
                    moveRight = false
            }

            function leftPressed() {
                    moveLeft = true
                    moveRight = false
            }

            function leftReleased() {
                    moveLeft = false
            }

            function handleKeyPress(event) {
                    switch (event.key) {
                    case Qt.Key_W:
                    case Qt.Key_Up:
                            forwardPressed()
                            break
                    case Qt.Key_S:
                    case Qt.Key_Down:
                            backPressed()
                            break
                    case Qt.Key_A:
                    case Qt.Key_Left:
                            leftPressed()
                            break
                    case Qt.Key_D:
                    case Qt.Key_Right:
                            rightPressed()
                            break
                    }
            }

            function handleKeyRelease(event) {
                    switch (event.key) {
                    case Qt.Key_W:
                    case Qt.Key_Up:
                            forwardReleased()
                            break
                    case Qt.Key_S:
                    case Qt.Key_Down:
                            backReleased()
                            break
                    case Qt.Key_A:
                    case Qt.Key_Left:
                            leftReleased()
                            break
                    case Qt.Key_D:
                    case Qt.Key_Right:
                            rightReleased()
                            break
                    }
            }

            QtObject {
                    id: status
                    property vector2d lastPos: Qt.vector2d(0, 0)
                    property vector2d currentPos: Qt.vector2d(0, 0)
            }
    }
    Wasd {
            id: wasd
            property real walkingSpeed: 500
            property real speedFactor: 1
            property real sideSpeed: (moveLeft ? -1 : moveRight ? 1 : 0) * walkingSpeed * speedFactor
            property real forwardSpeed: (moveForwards ? -1 : moveBackwards ? 1 : 0) * walkingSpeed * speedFactor
            cameraRotation.x: 180
    }

}
