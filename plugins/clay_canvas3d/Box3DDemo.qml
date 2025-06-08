// Box3D Examples - Demonstrates various Box3D features

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import QtQuick.Controls

View3D {
    id: view3D
    anchors.fill: parent

    // Access to camera store passed from parent
    property var cameraStore: parent.cameraStore

    environment: SceneEnvironment {
        clearColor: "#1a1a1a"
        backgroundMode: SceneEnvironment.Color
    }

    // Camera with stored position
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 200, 400)
        eulerRotation.x: -20

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("box3d_camPos"))
                position = JSON.parse(cameraStore.get("box3d_camPos"))
            if (cameraStore && cameraStore.has("box3d_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("box3d_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("box3d_camPos", JSON.stringify(position))
                cameraStore.set("box3d_camRot", JSON.stringify(eulerRotation))
            }
        }
    }

    // Camera controller
    WasdController {
        controlledObject: camera
        mouseEnabled: true
        keysEnabled: true
    }

    // ========================================
    // LIGHTING SETUP FOR TOON SHADING
    // ========================================
    // Main directional light - configured for optimal toon shading effect
    // The specific shadow settings create the characteristic cartoon look
    DirectionalLight {
        id: mainLight
        eulerRotation.x: -35  // Angle optimized for toon shading (matches QtWorldSummit demo)
        eulerRotation.y: -70
        
        // Shadow configuration - critical for toon effect
        castsShadow: toonControls.enableShadows
        
        // These shadow settings create the hard light/dark transitions
        // characteristic of cartoon rendering:
        shadowFactor: toonControls.useToonShading ? 78 : 50      // Very strong shadows for toon
        shadowMapQuality: Light.ShadowMapQualityVeryHigh          // Crisp shadow edges
        pcfFactor: toonControls.useToonShading ? 2 : 8           // Minimal softening for toon
        shadowBias: 18                                            // Prevents shadow artifacts
        
        // Additional shadow settings for quality
        csmNumSplits: 3  // Cascade shadow mapping for better quality at distance
    }
    
    // Ambient light to ensure dark areas are still visible
    // Lower brightness for toon shading to emphasize the light/shadow contrast
    // AmbientLight {
    //     brightness: toonControls.useToonShading ? 0.2 : 0.3
    // }

    // ========================================
    // DEMO 1: Basic Box3D with edge rendering
    // ========================================
    Node {
        x: -300

        Box3D {
            width: 100
            height: 100
            depth: 100
            color: "#e74c3c"
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5  // Increase edge contrast for toon
            edgeThickness: 8
            useToonShading: toonControls.useToonShading
        }
    }

    // ========================================
    // DEMO 2: Animated rotating box
    // ========================================
    Node {
        x: 0

        Box3D {
            width: 80
            height: 120
            depth: 80
            color: "#3498db"
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5
            useToonShading: toonControls.useToonShading
            
            SequentialAnimation on eulerRotation {
                loops: Animation.Infinite
                PropertyAnimation {
                    from: Qt.vector3d(0, 0, 0)
                    to: Qt.vector3d(0, 360, 0)
                    duration: 4000
                }
            }

            SequentialAnimation on y {
                loops: Animation.Infinite
                NumberAnimation {
                    from: 0
                    to: 50
                    duration: 2000
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: 50
                    to: 0
                    duration: 2000
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }

    // ========================================
    // DEMO 3: Pyramid using scale properties
    // ========================================
    Node {
        x: 300

        Box3D {
            width: 100
            height: 100
            depth: 100
            color: "#f39c12"
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5
            useToonShading: toonControls.useToonShading
            scaledFace: Box3DGeometry.TopFace
            faceScale: Qt.vector2d(0.1, 0.1)
        }
    }

    // ========================================
    // DEMO 4: Complex shape with multiple scales
    // ========================================
    Node {
        x: -300
        z: 200

        Box3D {
            width: 120
            height: 80
            depth: 120
            color: "#9b59b6"
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5
            useToonShading: toonControls.useToonShading
            scaledFace: Box3DGeometry.TopFace
            faceScale: Qt.vector2d(0.6, 0.6)
        }
    }

    // ========================================
    // DEMO 5: Edge mask demonstration
    // ========================================
    Node {
        x: 0
        z: 200

        Box3D {
            width: 100
            height: 100
            depth: 100
            color: "#16a085"
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5
            edgeThickness: 10
            edgeMask: 0x00F  // Only top edges
            useToonShading: toonControls.useToonShading
        }
    }

    // ========================================
    // DEMO 6: Color cycling box
    // ========================================
    Node {
        x: 300
        z: 200

        Box3D {
            id: interactiveBox
            width: 100
            height: 100
            depth: 100
            
            property var colors: ["#e74c3c", "#3498db", "#2ecc71", "#f39c12", "#9b59b6"]
            property int colorIndex: 0
            
            color: colors[colorIndex]
            edgeColorFactor: toonControls.useToonShading ? 2.0 : 1.5
            useToonShading: toonControls.useToonShading
            
            // Animate color changes
            SequentialAnimation on colorIndex {
                loops: Animation.Infinite
                NumberAnimation { to: 1; duration: 1000 }
                NumberAnimation { to: 2; duration: 1000 }
                NumberAnimation { to: 3; duration: 1000 }
                NumberAnimation { to: 4; duration: 1000 }
                NumberAnimation { to: 0; duration: 1000 }
            }
        }
    }

    // Overlay with labels and controls
    Item {
        anchors.fill: parent
        
        // Info text
        Text {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            text: "Box3D Examples - Click and drag to rotate view, scroll to zoom"
            color: "white"
            font.pixelSize: 14
        }
        
        // Demo labels
        Column {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 20
            spacing: 5
            
            Text {
                text: "1. Basic Box3D | 2. Animated | 3. Pyramid"
                color: "white"
                font.pixelSize: 12
            }
            Text {
                text: "4. Complex scaling | 5. Edge mask | 6. Color cycling"
                color: "white"
                font.pixelSize: 12
            }
        }
        
        // ========================================
        // TOON SHADING CONTROL PANEL
        // ========================================
        // This panel demonstrates the toon shading feature
        // and allows real-time comparison with standard rendering
        Rectangle {
            id: toonControls
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 250
            height: 200
            color: "#2c3e50"
            border.color: "#34495e"
            border.width: 2
            radius: 5
            
            // Control properties that affect the scene
            property bool useToonShading: false
            property bool enableShadows: true
            property real shadowStrength: 78
            
            Column {
                anchors.fill: parent
                anchors.margins: 15
                spacing: 10
                
                // Title
                Text {
                    text: "Toon Shading Controls"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                }
                
                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#34495e"
                }
                
                // Toon shading toggle
                Row {
                    spacing: 10
                    CheckBox {
                        id: toonCheckBox
                        checked: toonControls.useToonShading
                        onCheckedChanged: {
                            toonControls.useToonShading = checked
                            // When enabling toon shading, also enable shadows for best effect
                            if (checked && !shadowCheckBox.checked) {
                                shadowCheckBox.checked = true
                            }
                        }
                    }
                    Text {
                        text: "Enable Toon Shading"
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Shadows toggle
                Row {
                    spacing: 10
                    CheckBox {
                        id: shadowCheckBox
                        checked: toonControls.enableShadows
                        onCheckedChanged: toonControls.enableShadows = checked
                    }
                    Text {
                        text: "Enable Shadows"
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                // Shadow strength slider (only visible when shadows are enabled)
                Column {
                    width: parent.width
                    spacing: 5
                    visible: toonControls.enableShadows
                    
                    Text {
                        text: "Shadow Strength: " + Math.round(shadowSlider.value)
                        color: "white"
                        font.pixelSize: 12
                    }
                    
                    Slider {
                        id: shadowSlider
                        width: parent.width
                        from: 0
                        to: 100
                        value: toonControls.shadowStrength
                        onValueChanged: {
                            toonControls.shadowStrength = value
                            mainLight.shadowFactor = value
                        }
                    }
                }
                
                // Info text
                Text {
                    width: parent.width
                    text: toonControls.useToonShading ? 
                          "Cartoon-style rendering with\nhard shadows and flat shading" : 
                          "Standard PBR rendering with\nrealistic lighting"
                    color: "#ecf0f1"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
