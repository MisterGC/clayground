// 3D Graphics Showcase - Box3D, Lines, VoxelMaps
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

Item {
    anchors.fill: parent
    focus: true
    Component.onCompleted: forceActiveFocus()

    // Simple keyboard camera controls
    property real cameraSpeed: 5
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_W) camera.z -= cameraSpeed
        else if (event.key === Qt.Key_S) camera.z += cameraSpeed
        else if (event.key === Qt.Key_A) camera.x -= cameraSpeed
        else if (event.key === Qt.Key_D) camera.x += cameraSpeed
        else if (event.key === Qt.Key_Q) camera.y -= cameraSpeed
        else if (event.key === Qt.Key_E) camera.y += cameraSpeed
    }

    View3D {
        id: view
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#1a1a2e"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(-40, 120, 470)
            eulerRotation: Qt.vector3d(-15, 0, 0)
        }

        DirectionalLight {
            color: Qt.rgba(1, 0.98, 0.95, 1)
            brightness: 0.7
            eulerRotation: Qt.vector3d(-45, 0, 0)
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1)
        }

        // Ground plane
        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(20, 20, 1)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            materials: DefaultMaterial { diffuseColor: "white" }
        }

        // Box3D demo
        Box3D {
            x: -100; y: 0; z: 50
            width: 80
        }

        // MultiLine3D - batch of random lines
        MultiLine3D {
            coords: {
                let lines = [];
                for (let i = 0; i < 200; i++) {
                    lines.push([
                        Qt.vector3d(Math.random()*100, Math.random()*100, Math.random()*100),
                        Qt.vector3d(Math.random()*100, Math.random()*100, Math.random()*100)
                    ]);
                }
                return lines;
            }
            color: "blue"
            width: 3
        }

        // DynamicVoxelMap with animation
        DynamicVoxelMap {
            id: voxelMap
            x: 100; y: 0; z: 100
            voxelCountX: 20; voxelCountY: 20; voxelCountZ: 20
            voxelSize: 3.0; spacing: 0.0

            SequentialAnimation {
                loops: Animation.Infinite
                running: true
                NumberAnimation { target: voxelMap; property: "spacing"; to: 1.5; duration: 2000 }
                NumberAnimation { target: voxelMap; property: "spacing"; to: 0; duration: 2000 }
            }

            Component.onCompleted: {
                voxelMap.fill([
                    { sphere: { pos: Qt.vector3d(10, 10, 10), radius: 8,
                        colors: [
                            { color: "#2D5A27", weight: 0.4 },
                            { color: "#4C9A2A", weight: 0.4 },
                            { color: "red", weight: 0.2 }
                        ], noise: 0.3
                    }}
                ]);
            }
        }
    }

    Text {
        anchors { top: parent.top; left: parent.left; margins: 10 }
        color: "white"
        text: "3D Demo - WASD/QE to move camera"
        font.pixelSize: 14
    }
}
