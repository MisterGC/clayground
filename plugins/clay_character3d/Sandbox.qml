// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.GameController

Item {
    id: root
    anchors.fill: parent
    Keys.forwardTo: [gameController]
    Component.onCompleted: root.forceActiveFocus()
    
    View3D {
        id: view3d
        anchors.fill: parent
        
        environment: SceneEnvironment {
            clearColor: "#87CEEB"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
            
            // Enable toon shading
            tonemapMode: SceneEnvironment.TonemapModeNone
        }
        
        // Lighting setup for toon shading
        DirectionalLight {
            id: mainLight
            eulerRotation.x: -35
            eulerRotation.y: -70
            
            // Shadow configuration for toon shading effect
            castsShadow: true
            shadowFactor: 78  // Strong shadows for toon effect
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            pcfFactor: 2  // Minimal softening to keep shadows crisp
            shadowBias: 18
            csmNumSplits: 3
            
            brightness: 1.0
            ambientColor: Qt.rgba(0.1, 0.1, 0.1, 1.0)
        }
        
        // Character camera that follows the character
        CharacterCamera {
            id: charCamera
            character: character
            orbitDistance: 30
            orbitPitch: 25
            orbitYawOffset: 180
        }
        
        // Ground plane with toon shading
        Box3D {
            y: -0.5
            width: 100
            height: 1
            depth: 100
            color: "#4a9c4a"
            showEdges: true
            edgeColorFactor: 0.8
            edgeThickness: 1.0
        }
        
        // Create a basic character
        Character {
            id: character
            name: "DemoCharacter"
            
            // Default colors
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
            turnSpeed: 2.0
            walkSpeed: 0.4
            axisX: gameController.axisX
            axisY: gameController.axisY
        }
        
        // Add some objects for reference
        Repeater3D {
            model: 5
            Box3D {
                x: Math.cos(index * 72 * Math.PI / 180) * 20
                y: 2.5
                z: Math.sin(index * 72 * Math.PI / 180) * 20
                width: 3
                height: 5
                depth: 3
                color: Qt.hsla((index * 0.2) % 1, 0.7, 0.5, 1)
                showEdges: true
                edgeColorFactor: 0.7
            }
        }
    }

    // Game controller for WASD input
    GameController {
        id: gameController
        width: parent.width * .25
        height: parent.height * .25
        anchors.bottom: parent.bottom
        showDebugOverlay: true

        Component.onCompleted: {
            selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_Space, Qt.Key_Shift)
            charController.bindToGameController(gameController)
        }
    }


    // Info panel
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        width: 220
        height: infoColumn.height + 20
        color: "#f0f0f0"
        opacity: 0.9
        radius: 10
        
        Column {
            id: infoColumn
            anchors.centerIn: parent
            spacing: 5
            
            Text {
                text: "Character3D Plugin"
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                text: "Controls:"
                font.pixelSize: 14
                font.bold: true
            }
            
            Text {
                text: "• WASD: Move character"
                font.pixelSize: 12
            }
            
            Text {
                text: "\nCharacter State: " + (character.activity === Character.Walking ? "Walking" : "Idle")
                font.pixelSize: 12
                color: character.activity === Character.Walking ? "green" : "gray"
            }
        }
    }
}
