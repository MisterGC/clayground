// (c) Clayground Contributors - MIT License, see "LICENSE" file
// Full 3D graphics showcase for WASM (no physics)

import QtQuick
import QtQuick.Controls
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: forceActiveFocus()

    // Restore focus when clicked (for WASM embedding)
    MouseArea {
        anchors.fill: parent
        onPressed: (mouse) => {
            root.forceActiveFocus()
            mouse.accepted = false
        }
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

        PointLight {
            position: Qt.vector3d(0, 500, 0)
            brightness: 0.1
            quadraticFade: 0.0001
        }

        // Ground plane
        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(20, 20, 1)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            materials: DefaultMaterial { diffuseColor: "white" }
        }

        // Helper functions for line generation
        function generateRandomLineData(anchorPoint, dimensions, maxNumPoints) {
            let numPoints = Math.floor(Math.random() * (maxNumPoints - 2)) + 2;
            let vertices = [];
            for (let i = 0; i < numPoints; i++) {
                vertices.push(Qt.vector3d(
                    anchorPoint.x + Math.random() * dimensions.x,
                    anchorPoint.y + Math.random() * dimensions.y,
                    anchorPoint.z + Math.random() * dimensions.z
                ));
            }
            return vertices;
        }

        function generateRandomLineBatch(numLines, anchorPoint, dimensions, maxNumPoints) {
            let allLines = [];
            for (let i = 0; i < numLines; i++) {
                let lineData = generateRandomLineData(anchorPoint, dimensions, maxNumPoints);
                allLines.push(lineData);
            }
            return allLines;
        }

        // MultiLine3D - batch of lines
        MultiLine3D {
            coords: view.generateRandomLineBatch(500, Qt.vector3d(0,0,0), Qt.vector3d(100,100,100), 2)
            color: "blue"
            width: 3
            Node {
                x: 50; y: 50; z: 100.1
                Label {
                    color: "black"
                    background: Rectangle { opacity: .75 }
                    text: "MultiLine3D"
                    anchors.centerIn: parent
                }
            }
        }

        // Individual lines with Repeater3D
        Node {
            Repeater3D {
                model: 10
                delegate: Line3D {
                    coords: view.generateRandomLineData(Qt.vector3d(-110,0,0), Qt.vector3d(100,100,100), 100)
                    color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0)
                    width: 2
                }
            }
            Node {
                x: -60; y: 50; z: 100.1
                Label {
                    color: "black"
                    background: Rectangle { opacity: .75 }
                    text: "Repeater3D(Line3D)"
                    anchors.centerIn: parent
                }
            }
        }

        // Box3D
        Box3D {
            x: -200; y: 0; z: 50
            width: 100
            Node {
                x: 0; y: 10; z: 50.1
                Label {
                    color: "black"
                    background: Rectangle { opacity: .75 }
                    text: "Box3D"
                    anchors.centerIn: parent
                }
            }
        }

        // DynamicVoxelMap with animation
        DynamicVoxelMap {
            id: _voxelMapInst
            x: -200; y: 0; z: 300
            voxelCountX: 30; voxelCountY: 30; voxelCountZ: 30
            voxelSize: 2.0; spacing: 0.0

            SequentialAnimation {
                loops: Animation.Infinite
                running: true
                NumberAnimation { target: _voxelMapInst; property: "spacing"; to: 2; duration: 3000 }
                NumberAnimation { target: _voxelMapInst; property: "spacing"; to: 0; duration: 3000 }
            }

            Component.onCompleted: {
                _voxelMapInst.fill([
                    { sphere: { pos: Qt.vector3d(10, 15, 10), radius: 8,
                        colors: [
                            { color: "#2D5A27", weight: 0.3 }, { color: "#3A7729", weight: 0.3 },
                            { color: "#4C9A2A", weight: 0.15 }, { color: "red", weight: 0.05 },
                            { color: "#68B030", weight: 0.15 }, { color: "#89C34A", weight: 0.05 }
                        ], noise: 0.3
                    }},
                    { cylinder: { pos: Qt.vector3d(10, 0, 10), radius: 2, height: 10,
                        colors: [
                            { color: "#5C4033", weight: 0.4 }, { color: "#8B4513", weight: 0.4 },
                            { color: "#A0522D", weight: 0.2 }
                        ]
                    }}
                ]);
            }
        }

        // StaticVoxelMap with instancing
        StaticVoxelMap {
            id: _voxelMap
            instancing: InstanceList {
                instances: [
                    InstanceListEntry { position: Qt.vector3d(-300, 0, 100); scale: Qt.vector3d(1, 1, 1) },
                    InstanceListEntry { position: Qt.vector3d(-320, 0, 200); scale: Qt.vector3d(0.9, 0.9, 0.9) },
                    InstanceListEntry { position: Qt.vector3d(-400, 0, 150); scale: Qt.vector3d(1.1, 1.1, 1.1) }
                ]
            }
            voxelCountX: 30; voxelCountY: 30; voxelCountZ: 30
            voxelSize: 5.0; spacing: 0.0
            Component.onCompleted: {
                _voxelMap.fill([
                    { sphere: { pos: Qt.vector3d(10, 15, 10), radius: 8,
                        colors: [
                            { color: "#2D5A27", weight: 0.3 }, { color: "#3A7729", weight: 0.3 },
                            { color: "#4C9A2A", weight: 0.15 }, { color: "red", weight: 0.05 },
                            { color: "#68B030", weight: 0.15 }, { color: "#89C34A", weight: 0.05 }
                        ], noise: 0.3
                    }},
                    { cylinder: { pos: Qt.vector3d(10, 0, 10), radius: 2, height: 10,
                        colors: [
                            { color: "#5C4033", weight: 0.4 }, { color: "#8B4513", weight: 0.4 },
                            { color: "#A0522D", weight: 0.2 }
                        ]
                    }}
                ]);
            }
        }

        Node {
            x: -400; y: 10; z: 200
            Label {
                color: "black"
                background: Rectangle { opacity: .75 }
                text: "VoxelMap + Instancing"
                anchors.centerIn: parent
            }
        }

        // Pyramid DynamicVoxelMap
        DynamicVoxelMap {
            id: _pyramid
            x: 50; y: 0; z: 300
            voxelCountX: 40; voxelCountY: 20; voxelCountZ: 40
            voxelSize: 5.0; spacing: 0.0
            Component.onCompleted: {
                _pyramid.fill([
                    { box: { pos: Qt.vector3d(0, 0, 0), width: 40, height: 4, depth: 40,
                             colors: [{ color: "#FF8C00", weight: 1 }] }},
                    { box: { pos: Qt.vector3d(5, 4, 5), width: 30, height: 4, depth: 30,
                             colors: [{ color: "#FFA500", weight: 1 }] }},
                    { box: { pos: Qt.vector3d(10, 8, 10), width: 20, height: 4, depth: 20,
                             colors: [{ color: "#FFB52E", weight: 1 }] }},
                    { box: { pos: Qt.vector3d(15, 12, 15), width: 10, height: 4, depth: 10,
                             colors: [{ color: "#FFD700", weight: 1 }] }}
                ]);
            }
        }

        WasdController {
            controlledObject: camera
            forwardSpeed: .5
            backSpeed: .5
        }
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        color: "white"
        text: "Voxelworld - Qt Quick 3D WASM Showcase\nWASD to move camera"
        font.pixelSize: 16
    }
}
