// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Character3D

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
        
        // Camera
        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(0, 15, 30)
            eulerRotation.x: -20
            fieldOfView: 60
            clipNear: 0.1
            clipFar: 1000
        }
        
        // Ground
        Box3D {
            y: -0.5
            width: 50
            height: 1
            depth: 50
            color: "#4a4a4a"
            showEdges: true
            edgeColorFactor: 0.8
        }
        
        // Basic character with default settings
        Character {
            id: character
            name: "BasicCharacter"
            
            // Simple color scheme
            headSkinColor: "#fdbcb4"
            headHairColor: "#8b4513"
            torsoColor: "#4169e1"
            handsColor: "#fdbcb4"
            feetColor: "#8b4513"
            
            // Start with walking animation
            activity: Character.Walking
        }
        
        // Rotate character to show it from different angles
        NumberAnimation on eulerRotation.y {
            target: character
            from: 0
            to: 360
            duration: 10000
            loops: Animation.Infinite
        }
    }
    
    // Info text
    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 20
        text: "Basic Character with default proportions\nRotating to show all angles"
        font.pixelSize: 16
        color: "#333"
        style: Text.Outline
        styleColor: "white"
    }
}