// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.GameController
import Clayground.Storage

Item {
    id: root
    anchors.fill: parent
    
    // Store camera position between sessions
    KeyValueStore {
        id: kvStore
        name: "Clayground.Character3D.Sandbox"
    }
    
    // Main layout with sidebar and content
    RowLayout {
        anchors.fill: parent
        spacing: 0
        
        // Left sidebar menu
        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            color: "#2c3e50"
            
            Column {
                width: parent.width
                padding: 10
                spacing: 5
                
                // Title
                Text {
                    text: "Character3D Demos"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    padding: 10
                }
                
                // Menu items
                Repeater {
                    model: [
                        { name: "Basic Character", component: "BasicCharacterExample.qml" },
                        { name: "Character Control", component: "CharacterControlExample.qml" },
                        { name: "Animation Showcase", component: "AnimationShowcase.qml" },
                        { name: "Ratio-Based Character", component: "RatioBasedExample.qml" },
                        { name: "Multiple Characters", component: "MultipleCharactersExample.qml" },
                        { name: "Character Customization", component: "CharacterCustomization.qml" }
                    ]
                    
                    Rectangle {
                        width: parent.width - 20
                        height: 40
                        color: mouseArea.containsMouse ? "#34495e" : "transparent"
                        radius: 5
                        
                        Text {
                            text: modelData.name
                            color: "white"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 15
                        }
                        
                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                contentLoader.source = modelData.component
                                kvStore.set("lastDemo", modelData.component)
                            }
                        }
                    }
                }
            }
        }
        
        // Content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ecf0f1"
            
            Loader {
                id: contentLoader
                anchors.fill: parent
                source: kvStore.get("lastDemo", "BasicCharacterExample.qml")
                
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.error("Failed to load:", source)
                        // Fallback to embedded example if external file fails
                        contentLoader.sourceComponent = basicExample
                    }
                }
            }
        }
    }
    
    // Embedded basic example as fallback
    Component {
        id: basicExample
        
        Item {
            anchors.fill: parent
            
            View3D {
                id: view3d
                anchors.fill: parent
                
                environment: SceneEnvironment {
                    clearColor: "#87CEEB"
                    backgroundMode: SceneEnvironment.Color
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.High
                }
                
                // Lighting setup for toon shading
                DirectionalLight {
                    eulerRotation.x: -35
                    castsShadow: true
                    shadowMapQuality: Light.ShadowMapQualityHigh
                }
                
                
                // Camera with orbit controls
                Node {
                    id: cameraController
                    property real orbitDistance: 30
                    property real orbitYaw: 0
                    property real orbitPitch: 20
                    
                    PerspectiveCamera {
                        id: camera
                        position: Qt.vector3d(0, 10, cameraController.orbitDistance)
                        eulerRotation.x: -cameraController.orbitPitch
                        
                        property real fov: 60
                        fieldOfView: fov
                        clipNear: 0.1
                        clipFar: 1000
                    }
                    
                    eulerRotation.y: cameraController.orbitYaw
                }
                
                // Ground plane
                Box3D {
                    y: -0.5
                    width: 100
                    height: 1
                    depth: 100
                    color: "#4a4a4a"
                    showEdges: true
                    edgeColorFactor: 0.8
                }
                
                // Create a basic character
                Character {
                    id: character
                    name: "DemoCharacter"
                    
                    // Basic colors
                    headSkinColor: "#fdbcb4"
                    headHairColor: "#8b4513"
                    torsoColor: "#4169e1"
                    handsColor: "#fdbcb4"
                    feetColor: "#8b4513"
                    
                    // Start with idle animation
                    activity: Character.Idle
                }
                
                // Character controller
                CharacterController {
                    id: charController
                    character: character
                    enabled: true
                }
                
                // Game controller for input
                GameController {
                    id: gameController
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.3
                    height: 100
                    opacity: 0.8
                    
                    Component.onCompleted: {
                        // Use arrow keys for movement
                        selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Space, Qt.Key_Shift)
                        // Bind to character controller
                        charController.bindToGameController(gameController)
                    }
                    
                    showDebugOverlay: true
                }
                
                // Camera controls
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    
                    property real lastX: 0
                    property real lastY: 0
                    
                    onPressed: {
                        lastX = mouseX
                        lastY = mouseY
                    }
                    
                    onPositionChanged: {
                        if (pressed) {
                            const deltaX = mouseX - lastX
                            const deltaY = mouseY - lastY
                            
                            if (pressedButtons & Qt.LeftButton) {
                                cameraController.orbitYaw += deltaX * 0.5
                                cameraController.orbitPitch = Math.max(-89, Math.min(89, cameraController.orbitPitch - deltaY * 0.5))
                            }
                            
                            lastX = mouseX
                            lastY = mouseY
                        }
                    }
                    
                    onWheel: {
                        cameraController.orbitDistance = Math.max(10, Math.min(100, cameraController.orbitDistance - wheel.angleDelta.y * 0.05))
                    }
                }
            }
            
            // Info panel
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 20
                width: 300
                height: infoColumn.height + 20
                color: "#f0f0f0"
                opacity: 0.9
                radius: 10
                
                Column {
                    id: infoColumn
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "Basic Character Example"
                        font.pixelSize: 18
                        font.bold: true
                    }
                    
                    Text {
                        text: "Controls:"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    
                    Text {
                        text: "• Arrow Keys: Move character"
                        font.pixelSize: 12
                    }
                    
                    Text {
                        text: "• Left Mouse: Rotate camera"
                        font.pixelSize: 12
                    }
                    
                    Text {
                        text: "• Mouse Wheel: Zoom"
                        font.pixelSize: 12
                    }
                    
                    Text {
                        text: "\nCharacter State: " + (character.activity === Character.Walking ? "Walking" : "Idle")
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
