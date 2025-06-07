// Voxel Examples - Demonstrates DynamicVoxelMap and StaticVoxelMap

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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
        position: Qt.vector3d(0, 300, 500)
        eulerRotation.x: -30

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("voxel_camPos"))
                position = JSON.parse(cameraStore.get("voxel_camPos"))
            if (cameraStore && cameraStore.has("voxel_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("voxel_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("voxel_camPos", JSON.stringify(position))
                cameraStore.set("voxel_camRot", JSON.stringify(eulerRotation))
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
    // Demo Components
    // ========================================

    Component {
        id: terrainDemo

        Node {
            x: -300
            z: -100

            DynamicVoxelMap {
                width: 40
                height: 20
                depth: 40
                voxelSize: 5
                spacing: 0.5
                showEdges: true
                edgeColorFactor: 0.8

                Component.onCompleted: {
                    // Create a simple terrain
                    for (var x = 0; x < width; x++) {
                        for (var z = 0; z < depth; z++) {
                            // Generate height using sine waves
                            var height = Math.floor(
                                5 +
                                3 * Math.sin(x * 0.3) * Math.cos(z * 0.3) +
                                2 * Math.sin(x * 0.7) * Math.sin(z * 0.7)
                            )

                            for (var y = 0; y < height && y < height; y++) {
                                var color = y < 3 ? "#8B4513" :  // Brown (dirt)
                                           y < 6 ? "#228B22" :  // Green (grass)
                                           y < 9 ? "#808080" :  // Gray (stone)
                                                   "#FFFFFF"    // White (snow)
                                set(x, y, z, color)
                            }
                        }
                    }
                    model.commit()
                }
            }
        }
    }

    Component {
        id: waveDemo

        Node {
            x: 100
            z: -100

            DynamicVoxelMap {
                id: waveMap
                width: 30
                height: 15
                depth: 30
                voxelSize: 5
                spacing: 1
                showEdges: false

                property real time: 0

                Timer {
                    interval: 30
                    running: true
                    repeat: true
                    onTriggered: {
                        waveMap.time += 0.08
                        waveMap.updateWave()
                    }
                }

                function updateWave() {
                    // Clear all voxels first
                    for (var x = 0; x < width; x++) {
                        for (var y = 0; y < height; y++) {
                            for (var z = 0; z < depth; z++) {
                                set(x, y, z, "#00000000")
                            }
                        }
                    }

                    // Create smooth, calm water wave
                    for (var x = 0; x < width; x++) {
                        for (var z = 0; z < depth; z++) {
                            // Single smooth wave moving diagonally across the surface
                            var waveHeight = Math.floor(
                                7 + 3 * Math.sin((x + z) * 0.3 + time)
                            )
                            
                            for (var y = 0; y < waveHeight && y < height; y++) {
                                // Water-like blue color palette - consistent blues only
                                var depthRatio = y / waveHeight
                                var lightness = 0.4 + (1.0 - depthRatio) * 0.3  // Lighter at surface, darker at depth
                                var saturation = 0.8  // Consistent saturation
                                var hue = 0.55  // True blue hue (not purple)
                                
                                set(x, y, z, Qt.hsla(hue, saturation, lightness, 1.0))
                            }
                        }
                    }
                }

                Component.onCompleted: updateWave()
            }
        }
    }

    Component {
        id: shapesDemo

        Node {
            x: -300
            z: 100

            StaticVoxelMap {
                width: 50
                height: 50
                depth: 50
                voxelSize: 4
                showEdges: true
                edgeColorFactor: 1.3
                edgeThickness: 0.2

                Component.onCompleted: {
                    fill([
                        // Sphere
                        {
                            sphere: {
                                pos: Qt.vector3d(15, 15, 15),
                                radius: 12,
                                colors: [
                                    { color: "#e74c3c", weight: 1.0 }
                                ]
                            }
                        },
                        // Box
                        {
                            box: {
                                pos: Qt.vector3d(30, 5, 10),
                                width: 15,
                                height: 15,
                                depth: 15,
                                colors: [
                                    { color: "#3498db", weight: 1.0 }
                                ]
                            }
                        },
                        // Cylinder
                        {
                            cylinder: {
                                pos: Qt.vector3d(15, 0, 35),
                                radius: 8,
                                height: 25,
                                colors: [
                                    { color: "#f39c12", weight: 1.0 }
                                ]
                            }
                        }
                    ])

                    model.commit()
                }
            }
        }
    }


    Component {
        id: textDemo

        Node {
            x: -100
            z: 250

            StaticVoxelMap {
                width: 50
                height: 20
                depth: 10
                voxelSize: 4
                spacing: 0.5
                showEdges: true

                Component.onCompleted: {
                    // Create "3D" text using voxels
                    var pattern = [
                        "  333  DDD  ",
                        "    3  D  D ",
                        "  333  D  D ",
                        "    3  D  D ",
                        "  333  DDD  "
                    ]

                    // Draw the text pattern
                    for (var row = 0; row < pattern.length; row++) {
                        for (var col = 0; col < pattern[row].length; col++) {
                            if (pattern[row][col] !== " ") {
                                var color = pattern[row][col] === "3" ? "#e74c3c" : "#3498db"
                                // Create 3D depth for each character
                                for (var z = 0; z < 6; z++) {
                                    // X position based on column
                                    var x = col * 3 + 5
                                    // Y position based on inverted row (top to bottom)
                                    var y = (pattern.length - 1 - row) * 3 + 5
                                    set(x, y, z, color)
                                    set(x + 1, y, z, color)  // Make chars 2 voxels wide
                                    set(x, y + 1, z, color)  // Make chars 2 voxels tall
                                    set(x + 1, y + 1, z, color)
                                }
                            }
                        }
                    }

                    model.commit()
                }
            }
        }
    }

    // Demo loader - only loads the active demo
    Loader3D {
        id: demoLoader
        asynchronous: true

        property int currentDemoIndex: 0
        property var demoComponents: [
            terrainDemo,
            waveDemo,
            shapesDemo,
            textDemo
        ]

        sourceComponent: demoComponents[currentDemoIndex]

        onStatusChanged: {
            if (status === Loader.Loading) {
                loadingIndicator.visible = true
            } else {
                loadingIndicator.visible = false
            }
        }
    }

    // Loading indicator
    Rectangle {
        id: loadingIndicator
        anchors.centerIn: parent
        width: 200
        height: 60
        color: "#2c3e50"
        radius: 5
        visible: false

        Text {
            anchors.centerIn: parent
            text: "Loading voxels..."
            color: "white"
            font.pixelSize: 16
        }
    }

    // Overlay with controls and info
    Item {
        anchors.fill: parent

        // Demo selector
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 200
            height: demoColumn.height + 20
            color: "#2c3e50"
            radius: 5

            Column {
                id: demoColumn
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "Select Demo:"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 14
                }

                Repeater {
                    model: [
                        "Static Terrain",
                        "Dynamic Wave",
                        "Shape Filling",
                        "Voxel Text"
                    ]

                    Rectangle {
                        width: 180
                        height: 30
                        color: demoLoader.currentDemoIndex === index ? "#3498db" :
                               mouseArea.containsMouse ? "#34495e" : "transparent"
                        radius: 3

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: "white"
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: demoLoader.currentDemoIndex = index
                        }
                    }
                }
            }
        }

        // Info text
        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            spacing: 5

            Text {
                text: "Voxel Examples - Click and drag to rotate view, scroll to zoom"
                color: "white"
                font.pixelSize: 14
            }

            Text {
                text: "StaticVoxelMap: Best for large, unchanging structures (terrain, buildings)"
                color: "#95a5a6"
                font.pixelSize: 12
            }

            Text {
                text: "DynamicVoxelMap: Best for animated or frequently changing voxels"
                color: "#95a5a6"
                font.pixelSize: 12
            }

        }
    }

}
