// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import QtQuick
import QtQuick3D
import Clayground.World

View3D {
    id: view
    anchors.fill: parent


    environment: SceneEnvironment {
        clearColor: "#d6dbdf"
        backgroundMode: SceneEnvironment.Color
    }

    DebugSettings{
        wireframeEnabled: true
    }

    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(-40, 120, 470)
        eulerRotation: Qt.vector3d(-15, 0, 0)
    }

    Node {
        id: _lighting

        // Main directional light (sun)
        DirectionalLight {
            id: mainLight
            color: Qt.rgba(1, 0.98, 0.95, 1)
            brightness: 0.7
            eulerRotation: Qt.vector3d(-45, 0, 0)
            castsShadow: true
            shadowFactor: 50
            shadowMapQuality: Light.ShadowMapQualityHigh
            shadowMapFar: 2000
            shadowBias: 5
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1) // White light
        }

        // Add ambient point light for general illumination
        PointLight {
            position: Qt.vector3d(0, 10000, 0)  // Position above the scene
            brightness: 0.1                    // Low intensity to just fill shadows
            quadraticFade: 0.0001             // Very gradual falloff
            castsShadow: true                // No shadows from ambient light
        }

        // DirectionalLight {
        //     //color: Qt.rgba(1, 1, 0, 1)  // Slightly cool fill light
        //     brightness: 0.2
        //     eulerRotation: Qt.vector3d(0, 45, 0)
        //     castsShadow: true
        // }

        // DirectionalLight {
        //     //color: Qt.rgba(0, 1, 0, 1)  // Slightly cool fill light
        //     brightness: 0.2
        //     eulerRotation: Qt.vector3d(0, -45, 0)
        //     castsShadow: true
        // }

        // DirectionalLight {
        //     //color: Qt.rgba(0, 1, 0, 1)  // Slightly cool fill light
        //     brightness: 0.2
        //     eulerRotation: Qt.vector3d(0, 90, 0)
        //     castsShadow: true
        // }

    }

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


    // Draw batch of lines (with same color and width)
    // This is recommended for drawing a big number of lines,
    // it is planned to allow color and width per line even in
    // batches
    MultiLine3D {
        visible: false
        coords:  view.generateRandomLineBatch(1000,
                                              Qt.vector3d(0,0,0),
                                              Qt.vector3d(100,100,100),
                                              2)
        color: "blue"
        width: 3
        Node{
            x: 50; y: 50; z: 100.1
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "MultiLine3D"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Draw inidividual lines using a 3D repeater
    // This is only recommended when drawing a view lines
    // e.g. for annotations
    Node {
        visible: false
        Repeater3D {
            model: 10
            delegate: Line3D {
                coords: view.generateRandomLineData(Qt.vector3d(-110,0,0),
                                                    Qt.vector3d(100,100,100), 100)
                color: Qt.rgba(Math.random(), Math.random(), Math.random(), 1.0)
                width: 2
            }
        }
        Node{
            x: -60; y: 50; z: 100.1
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "Repeater3D(Line3D)"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    BoxLine3D {
        visible: false
        positions: [
            Qt.vector3d(0, 5, 130),
            Qt.vector3d(25, 5, 150),
            Qt.vector3d(50, 5, 170),
            Qt.vector3d(75, 5, 200),
            Qt.vector3d(90, 5, 250),
            Qt.vector3d(100, 5, 300)
        ]
        width: 10
        color: "green"
        Node{
            x: 50; y: 25; z: 200
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "BoxLine3D"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Box3D  {
        visible: false
        x: -200; y: 0; z: 50
        width: 100
        Node{
            x: 0; y: 10; z: 50.1
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "Box3D"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    VoxelMap {
        id: _voxelMap
        castsShadows: true
        x: 100; y: 0; z: 100
        // instancing: InstanceList {
        //     instances: [
        //         InstanceListEntry {
        //             position: Qt.vector3d(-300, 0, 100)
        //             scale: Qt.vector3d(1, 1, 1)
        //         },
        //         InstanceListEntry {
        //             position: Qt.vector3d(-320, 0, 200)
        //             scale: Qt.vector3d(0.9, 0.9, 0.9)
        //         },
        //         InstanceListEntry {
        //             position: Qt.vector3d(-400, 0, 150)
        //             scale: Qt.vector3d(1.1, 1.1, 1.1)
        //         }
        //     ]
        // }
        width: 30; height: 30; depth: 30
        voxelSize: 5.0
        defaultColor: "transparent"
        Component.onCompleted: {
            // To set one voxel
            //_voxelMap.set(0,0,0, "black");

            // The tree's top
            _voxelMap.fillSphere(10, 15, 10, 8, [
                                         { color: "#2D5A27", weight: 0.3 },  // Darker forest green (inner/lower foliage)
                                         { color: "#3A7729", weight: 0.3 },  // Medium forest green
                                         { color: "#4C9A2A", weight: 0.15 },  // Bright green
                                         { color: "red", weight: 0.05 },  // Bright green
                                         { color: "#68B030", weight: 0.15 }, // Light lime green (sun-exposed leaves)
                                         { color: "#89C34A", weight: 0.05 }  // Very light green (highlights)
                                 ], 0.3);

            // The tree's trunk
            _voxelMap.fillCylinder(10, 0, 10, 2, 10, [
                { color: "#5C4033", weight: 0.4 },  // Dark brown
                { color: "#8B4513", weight: 0.4 },  // Saddle brown
                { color: "#A0522D", weight: 0.2 }   // Sienna
            ], 0.0);
        }
    }

    Node {
        id: _physicsRoot

        Node {
            id: _floor
            StaticRigidBody {
                eulerRotation: Qt.vector3d(-90, 0, 0)
                collisionShapes: PlaneShape {}
                Model {
                    source: "#Rectangle"
                    scale: Qt.vector3d(2000, 2000, 1)
                    materials: PrincipledMaterial { baseColor: "white" }
                    castsShadows: false
                    receivesShadows: true
                }
            }
            Model {
                visible: true
                y: 0.5
                scale: Qt.vector3d(2000, 2000, 2000)
                eulerRotation: Qt.vector3d(-90, 0, 0)
                geometry: GridGeometry {
                    //horizontalLines: 100
                    //verticalLines: 100
                    horizontalStep: 50/2000
                    verticalStep: 50/2000
                }
                materials: [ DefaultMaterial { diffuseColor: "grey" } ]
            }
        }

        // Repeater3D{
        //     model: 2
        //     Box3DBody {
        //         color: "orange"
        //         x: 150;  y: 50; z: 50
        //         width: 20
        //         scaledFace: Box3DGeometry.BottomFace
        //         faceScale: Qt.vector2d(.5, .5)
        //     }
        // }
        // Node{
        //     x: 150; y: 10; z: 100.1
        //     Label {
        //         color: "black"
        //         background: Rectangle {opacity: .75}
        //         text: "Box3DBody"
        //         anchors.horizontalCenter: parent.horizontalCenter
        //         anchors.verticalCenter: parent.verticalCenter
        //     }
        // }

    }

    Model {
        x: -300; y:50; z: 200
        source: "#Cube"
        materials: PrincipledMaterial {
            baseColor: "yellow"
        }
        castsShadows: true
    }

    PhysicsWorld{
        scene: _physicsRoot
        running: true
        gravity: Qt.vector3d(0, -9.81, 0)
    }

    WasdController {
        controlledObject: camera
        forwardSpeed: .5
        backSpeed: .5

    }
}
