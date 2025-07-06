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
            position: Qt.vector3d(0, 15, 35)
            eulerRotation.x: -20
            fieldOfView: 60
            clipNear: 0.1
            clipFar: 1000
        }
        
        // Ground
        Box3D {
            y: -0.5
            width: 100
            height: 1
            depth: 50
            color: "#4a4a4a"
            showEdges: true
            edgeColorFactor: 0.8
        }
        
        // Multiple characters showing different animations
        Row {
            spacing: 15
            
            // Walking character
            Character {
                id: walkingChar
                name: "Walker"
                headSkinColor: "#fdbcb4"
                headHairColor: "#8b4513"
                torsoColor: "#ff6347"
                handsColor: "#fdbcb4"
                feetColor: "#8b4513"
                activity: Character.Walking
                walkCycleDuration: 1000
            }
            
            // Idle character
            Character {
                id: idleChar
                name: "Idler"
                headSkinColor: "#fdbcb4"
                headHairColor: "#000000"
                torsoColor: "#4169e1"
                handsColor: "#fdbcb4"
                feetColor: "#000000"
                activity: Character.Idle
            }
            
            // Character with face animations
            Character {
                id: emotionalChar
                name: "Emotional"
                headSkinColor: "#fdbcb4"
                headHairColor: "#ffd700"
                torsoColor: "#32cd32"
                handsColor: "#fdbcb4"
                feetColor: "#32cd32"
                activity: Character.Idle
                
                // Cycle through face activities
                Timer {
                    interval: 2000
                    repeat: true
                    running: true
                    property int currentEmotion: 0
                    onTriggered: {
                        const emotions = [Head.Idle, Head.Joy, Head.Anger, Head.Sadness, Head.Talk]
                        currentEmotion = (currentEmotion + 1) % emotions.length
                        emotionalChar.faceActivity = emotions[currentEmotion]
                    }
                }
            }
        }
    }
    
    // Control panel
    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        width: 300
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
                text: "Animation Showcase"
                font.pixelSize: 18
                font.bold: true
            }
            
            Text {
                text: "Walk Cycle Speed:"
                font.pixelSize: 14
            }
            
            Slider {
                width: parent.width
                from: 500
                to: 2000
                value: walkingChar.walkCycleDuration
                onValueChanged: walkingChar.walkCycleDuration = value
            }
            
            Text {
                text: "Current Face Emotion: " + getFaceEmotionName(emotionalChar.faceActivity)
                font.pixelSize: 14
                
                function getFaceEmotionName(activity) {
                    switch(activity) {
                        case Head.Idle: return "Idle"
                        case Head.Joy: return "Joy"
                        case Head.Anger: return "Anger"
                        case Head.Sadness: return "Sadness"
                        case Head.Talk: return "Talk"
                        default: return "Unknown"
                    }
                }
            }
            
            CheckBox {
                text: "Show thought bubble"
                checked: emotionalChar.thoughts !== ""
                onCheckedChanged: {
                    emotionalChar.thoughts = checked ? "Hmm..." : ""
                }
            }
        }
    }
}