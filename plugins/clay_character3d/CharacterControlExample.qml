// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.GameController

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
        
        // Lighting for toon shading
        DirectionalLight {
            eulerRotation.x: -35
            castsShadow: true
            shadowMapQuality: Light.ShadowMapQualityHigh
        }
        
        AmbientLight {
            brightness: 0.3
        }
        
        // Character with camera following
        Character {
            id: character
            name: "PlayerCharacter"
            headSkinColor: "#fdbcb4"
            headHairColor: "#8b4513"
            torsoColor: "#ff4500"
            handsColor: "#fdbcb4"
            feetColor: "#8b4513"
        }
        
        // Character camera that follows the character
        CharacterCamera {
            id: charCamera
            character: character
            orbitDistance: 40
            orbitPitch: 25
            orbitYawOffset: 180
        }
        
        // Ground with grid pattern
        Repeater {
            model: 20
            Repeater {
                model: 20
                property int row: index
                Box3D {
                    x: (index - 10) * 5
                    y: -0.5
                    z: (row - 10) * 5
                    width: 4.8
                    height: 1
                    depth: 4.8
                    color: (index + row) % 2 === 0 ? "#4a4a4a" : "#5a5a5a"
                    showEdges: true
                    edgeColorFactor: 0.8
                }
            }
        }
        
        // Some obstacles
        Repeater {
            model: 5
            Box3D {
                x: Math.random() * 60 - 30
                y: 2.5
                z: Math.random() * 60 - 30
                width: 3
                height: 5
                depth: 3
                color: Qt.hsla(Math.random(), 0.7, 0.5, 1)
                showEdges: true
            }
        }
    }
    
    // Character controller
    CharacterController {
        id: charController
        character: character
        enabled: true
        turnSpeed: 2.5
        walkSpeed: 0.4
    }
    
    // Game controller for input
    GameController {
        id: gameController
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.4
        height: 120
        opacity: 0.85
        
        Component.onCompleted: {
            // Use arrow keys or WASD
            selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_Space, Qt.Key_Shift)
            // Bind to character controller
            charController.bindToGameController(gameController)
        }
        
        showDebugOverlay: true
    }
    
    // Camera control
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        spacing: 10
        
        Button {
            text: "Reset Camera"
            onClicked: {
                charCamera.orbitYawOffset = 180
                charCamera.orbitPitch = 25
                charCamera.orbitDistance = 40
            }
        }
        
        Button {
            text: "Top View"
            onClicked: {
                charCamera.orbitPitch = 89
                charCamera.orbitDistance = 60
            }
        }
        
        Button {
            text: "Close Up"
            onClicked: {
                charCamera.orbitPitch = 10
                charCamera.orbitDistance = 20
            }
        }
    }
    
    // Info panel
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        width: 250
        height: infoColumn.height + 20
        color: "#f0f0f0"
        opacity: 0.9
        radius: 10
        
        Column {
            id: infoColumn
            anchors.centerIn: parent
            spacing: 5
            width: parent.width - 20
            
            Text {
                text: "Character Control"
                font.pixelSize: 16
                font.bold: true
            }
            
            Text {
                text: "Use WASD or Arrow Keys to move"
                font.pixelSize: 12
                wrapMode: Text.Wrap
                width: parent.width
            }
            
            Text {
                text: "\nPosition: " + 
                      "X: " + character.position.x.toFixed(1) + 
                      " Z: " + character.position.z.toFixed(1)
                font.pixelSize: 11
            }
            
            Text {
                text: "Rotation: " + character.eulerRotation.y.toFixed(1) + "°"
                font.pixelSize: 11
            }
            
            Text {
                text: "State: " + (character.activity === Character.Walking ? "Walking" : "Idle")
                font.pixelSize: 11
                color: character.activity === Character.Walking ? "green" : "gray"
            }
        }
    }
}