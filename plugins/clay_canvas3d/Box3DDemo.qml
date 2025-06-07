// Box3D Examples - Demonstrates various Box3D features

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

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

    // Lighting
    DirectionalLight {
        eulerRotation.x: -30
        eulerRotation.y: -70
    }

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
            edgeColorFactor: 1.5
            edgeThickness: 8
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
            edgeColorFactor: 1.5
            
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
            edgeColorFactor: 1.5
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
            edgeColorFactor: 1.5
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
            edgeColorFactor: 1.5
            edgeThickness: 10
            edgeMask: 0x00F  // Only top edges
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
            edgeColorFactor: 1.5
            
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

    // Overlay with labels
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
    }
}
