// Example showing Box3D with edge shader
import QtQuick
import QtQuick3D
import QtQuick.Layouts
import QtQuick.Controls

import Clayground.Canvas3D

// Import Screen for getting viewport height
import QtQuick.Window

View3D {
    id: view
    anchors.fill: parent

    environment: SceneEnvironment {
        clearColor: "#f0f0f0"
        backgroundMode: SceneEnvironment.Color
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 3, 10)
        eulerRotation: Qt.vector3d(-15, 0, 0)
        clipNear: 0.1
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(-30, -70, 0)
        brightness: 1.0
        ambientColor: Qt.rgba(0.1, 0.1, 0.1, 1.0)
    }

    // Regular box without scaled face
    Box3D {
        id: regularBox
        position: Qt.vector3d(-3, 0, 0)
        width: 2
        height: 2
        depth: 2
        color: "#40a0ff"

        // Edge settings matching VoxelMap style
        edgeThickness: 0.03
        edgeColorFactor: 0.4

        // Auto-rotate animation
        NumberAnimation on eulerRotation.y {
            from: 0
            to: 360
            duration: 10000
            loops: Animation.Infinite
            running: animateCheckbox.checked
        }
    }

    // Box with scaled top face
    Box3D {
        id: topScaledBox
        position: Qt.vector3d(0, 0, 0)
        width: 2
        height: 2
        depth: 2
        color: "#ff8040"

        // Scale the top face
        scaledFace: Box3DGeometry.TopFace
        faceScale: Qt.vector2d(0.7, 0.7)

        // Edge settings
        edgeThickness: 0.03
        edgeColorFactor: 0.4

        // Auto-rotate animation
        NumberAnimation on eulerRotation.y {
            from: 0
            to: 360
            duration: 12000
            loops: Animation.Infinite
            running: animateCheckbox.checked
        }
    }

    // Box with scaled side face
    Box3D {
        id: sideScaledBox
        position: Qt.vector3d(3, 0, 0)
        width: 1
        height: 1
        depth: 1
        color: "#40ff80"

        // Scale the right face
        scaledFace: Box3DGeometry.RightFace
        faceScale: Qt.vector2d(0.5, 0.8)

        // Edge settings
        edgeThickness: 0.03
        edgeColorFactor: 0.4

        // Auto-rotate animation
        NumberAnimation on eulerRotation.y {
            from: 0
            to: 360
            duration: 14000
            loops: Animation.Infinite
            running: animateCheckbox.checked
        }
    }

    // Add a VoxelMap for comparison
    VoxelMap {
        id: voxelMapSphere
        position: Qt.vector3d(0, -4, 0)
        voxelSize: 0.4
        edgeThickness: 0.03
        edgeColorFactor: 0.4

        Component.onCompleted: {
            // Create a simple sphere shape
            fill({
                sphere: [0, 0, 0, 4, "#ffdd00", 0.0]
            });
        }
    }

    // Controls
    Rectangle {
        color: Qt.rgba(1, 1, 1, 0.8)
        border.color: "gray"
        border.width: 1
        radius: 5
        width: column.width + 20
        height: column.height + 20
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10

        ColumnLayout {
            id: column
            anchors.centerIn: parent
            spacing: 10

            Text { text: "Edge Controls"; font.bold: true; Layout.alignment: Qt.AlignHCenter }

            CheckBox {
                id: animateCheckbox
                text: "Animate Rotation"
                checked: true
            }

            CheckBox {
                text: "Show Edges"
                checked: true
                onCheckedChanged: {
                    regularBox.showEdges = checked
                    topScaledBox.showEdges = checked
                    sideScaledBox.showEdges = checked
                    voxelMapSphere.showEdges = checked
                }
            }

            Text { text: "Edge Thickness" }
            Slider {
                from: 0.01
                to: 0.1
                value: 0.03
                onValueChanged: {
                    regularBox.edgeThickness = value
                    topScaledBox.edgeThickness = value
                    sideScaledBox.edgeThickness = value
                    voxelMapSphere.edgeThickness = value
                }
            }

            Text { text: "Edge Color Factor" }
            Slider {
                from: 0.2
                to: 0.8
                value: 0.4
                onValueChanged: {
                    regularBox.edgeColorFactor = value
                    topScaledBox.edgeColorFactor = value
                    sideScaledBox.edgeColorFactor = value
                    voxelMapSphere.edgeColorFactor = value
                }
            }
        }
    }
}
