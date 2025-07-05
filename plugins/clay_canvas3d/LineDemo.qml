// Line Examples - Demonstrates Line3D, MultiLine3D, and BoxLine3D

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
            if (cameraStore && cameraStore.has("line_camPos"))
                position = JSON.parse(cameraStore.get("line_camPos"))
            if (cameraStore && cameraStore.has("line_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("line_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("line_camPos", JSON.stringify(position))
                cameraStore.set("line_camRot", JSON.stringify(eulerRotation))
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
    // DEMO 1: Simple Line3D
    // ========================================
    Node {
        x: -300

        Line3D {
            coords: [
                Qt.vector3d(0, 0, 0),
                Qt.vector3d(50, 100, 0),
                Qt.vector3d(100, 50, 0),
                Qt.vector3d(150, 80, 0)
            ]
            color: "#e74c3c"
            width: 5
        }
    }

    // ========================================
    // DEMO 2: MultiLine3D - coordinate axes
    // ========================================
    Node {
        x: 0

        MultiLine3D {
            coords: [
                [Qt.vector3d(0, 0, 0), Qt.vector3d(100, 0, 0)],    // X axis - red
                [Qt.vector3d(0, 0, 0), Qt.vector3d(0, 100, 0)],    // Y axis - green
                [Qt.vector3d(0, 0, 0), Qt.vector3d(0, 0, 100)]     // Z axis - blue
            ]
            color: "#3498db"
            width: 3
        }

        // Axis indicators
        Box3D {
            x: 110
            width: 10
            height: 10 
            depth: 10
            color: "#e74c3c"
        }
        Box3D {
            y: 110
            width: 10
            height: 10
            depth: 10
            color: "#2ecc71"
        }
        Box3D {
            z: 110
            width: 10
            height: 10
            depth: 10
            color: "#3498db"
        }
    }

    // ========================================
    // DEMO 3: BoxLine3D
    // ========================================
    Node {
        x: 300

        BoxLine3D {
            positions: [
                Qt.vector3d(0, 0, 0),
                Qt.vector3d(30, 40, 20),
                Qt.vector3d(60, 20, 40),
                Qt.vector3d(90, 50, 60),
                Qt.vector3d(120, 30, 80)
            ]
            width: 8
            color: "#f39c12"
        }
    }

    // ========================================
    // DEMO 4: Animated spiral
    // ========================================
    Node {
        x: -300
        z: 200

        Line3D {
            id: spiralLine
            color: "#9b59b6"
            width: 4

            property real time: 0
            
            coords: {
                var points = []
                var steps = 50
                for (var i = 0; i <= steps; i++) {
                    var t = i / steps * Math.PI * 4
                    var r = 50 * (1 - i / steps)
                    points.push(Qt.vector3d(
                        r * Math.cos(t + time),
                        i * 2,
                        r * Math.sin(t + time)
                    ))
                }
                return points
            }

            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 5000
                loops: Animation.Infinite
            }
        }
    }

    // ========================================
    // DEMO 5: MultiLine3D grid
    // ========================================
    Node {
        x: 0
        z: 200

        MultiLine3D {
            coords: {
                var lineArray = []
                var size = 100
                var step = 20
                
                // Horizontal lines
                for (var z = -size/2; z <= size/2; z += step) {
                    lineArray.push([
                        Qt.vector3d(-size/2, 0, z),
                        Qt.vector3d(size/2, 0, z)
                    ])
                }
                
                // Vertical lines
                for (var x = -size/2; x <= size/2; x += step) {
                    lineArray.push([
                        Qt.vector3d(x, 0, -size/2),
                        Qt.vector3d(x, 0, size/2)
                    ])
                }
                
                return lineArray
            }
            color: "#16a085"
            width: 2
        }
    }

    // ========================================
    // DEMO 6: 3D graph plot
    // ========================================
    Node {
        x: 300
        z: 200

        MultiLine3D {
            coords: {
                var lineArray = []
                var size = 100
                var step = 10
                
                // Create a 3D sine wave surface
                for (var x = -size/2; x <= size/2; x += step) {
                    var line = []
                    for (var z = -size/2; z <= size/2; z += step/2) {
                        var y = 20 * Math.sin(x * 0.05) * Math.cos(z * 0.05)
                        line.push(Qt.vector3d(x, y, z))
                    }
                    lineArray.push(line)
                }
                
                return lineArray
            }
            color: "#e74c3c"
            width: 2
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
            text: "Line Examples - Click and drag to rotate view, scroll to zoom"
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
                text: "1. Line3D | 2. MultiLine3D axes (X=red, Y=green, Z=blue) | 3. BoxLine3D"
                color: "white"
                font.pixelSize: 12
            }
            Text {
                text: "4. Animated spiral | 5. Grid | 6. 3D function plot"
                color: "white"
                font.pixelSize: 12
            }
        }
    }
}
