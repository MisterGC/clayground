// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls
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
            position: Qt.vector3d(0, 15, 40)
            eulerRotation.x: -20
            fieldOfView: 60
            clipNear: 0.1
            clipFar: 1000
        }
        
        // Ground
        Box3D {
            y: -0.5
            width: 80
            height: 1
            depth: 50
            color: "#4a4a4a"
            showEdges: true
            edgeColorFactor: 0.8
        }
        
        // Show different character proportions
        Row {
            spacing: 10
            x: -20
            
            // Child proportions
            RatioBasedCharacter {
                id: childChar
                name: "Child"
                bodyHeight: 6
                headsTall: 4  // Larger head ratio
                headSkinColor: "#fdbcb4"
                headHairColor: "#ffd700"
                torsoColor: "#ff69b4"
                handsColor: "#fdbcb4"
                feetColor: "#ff69b4"
                activity: Character.Walking
            }
            
            // Normal proportions
            RatioBasedCharacter {
                id: normalChar
                name: "Adult"
                bodyHeight: 10
                headsTall: 7.5  // Standard proportions
                headSkinColor: "#fdbcb4"
                headHairColor: "#8b4513"
                torsoColor: "#4169e1"
                handsColor: "#fdbcb4"
                feetColor: "#8b4513"
                activity: Character.Walking
            }
            
            // Heroic proportions
            RatioBasedCharacter {
                id: heroChar
                name: "Hero"
                bodyHeight: 12
                headsTall: 8.5  // Smaller head ratio
                shoulderWidthToHeadWidth: 3  // Broader shoulders
                headSkinColor: "#fdbcb4"
                headHairColor: "#000000"
                torsoColor: "#dc143c"
                handsColor: "#fdbcb4"
                feetColor: "#000000"
                activity: Character.Walking
            }
        }
    }
    
    // Control panel
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 350
        height: controlColumn.height + 20
        color: "#f0f0f0"
        opacity: 0.9
        radius: 10
        
        Column {
            id: controlColumn
            anchors.centerIn: parent
            spacing: 10
            width: parent.width - 20
            
            Text {
                text: "Ratio-Based Characters"
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                text: "Adjust proportions to see how ratios work:"
                font.pixelSize: 14
                wrapMode: Text.Wrap
                width: parent.width
            }
            
            // Body Height
            Text { text: "Body Height: " + normalChar.bodyHeight.toFixed(1); font.pixelSize: 12 }
            Slider {
                width: parent.width
                from: 5
                to: 15
                value: normalChar.bodyHeight
                onValueChanged: normalChar.bodyHeight = value
            }
            
            // Heads Tall
            Text { text: "Heads Tall: " + normalChar.headsTall.toFixed(1); font.pixelSize: 12 }
            Slider {
                width: parent.width
                from: 4
                to: 9
                value: normalChar.headsTall
                onValueChanged: normalChar.headsTall = value
            }
            
            // Shoulder Width
            Text { text: "Shoulder Width Ratio: " + normalChar.shoulderWidthToHeadWidth.toFixed(1); font.pixelSize: 12 }
            Slider {
                width: parent.width
                from: 1.5
                to: 3.5
                value: normalChar.shoulderWidthToHeadWidth
                onValueChanged: normalChar.shoulderWidthToHeadWidth = value
            }
            
            // Leg Length
            Text { text: "Leg Length Ratio: " + normalChar.legLengthToHeadHeight.toFixed(1); font.pixelSize: 12 }
            Slider {
                width: parent.width
                from: 3
                to: 5
                value: normalChar.legLengthToHeadHeight
                onValueChanged: normalChar.legLengthToHeadHeight = value
            }
        }
    }
}