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
            brightness: 1.0
            eulerRotation: Qt.vector3d(-45, -45, 0)
            //castsShadow: true
            //shadowFactor: 50  // Increase for softer shadows
            //shadowMapQuality: Light.ShadowMapQualityHigh
        }

        // Fill light (opposite direction to main light)
        DirectionalLight {
            color: Qt.rgba(0.7, 0.7, 0.8, 1)  // Slightly cool fill light
            brightness: 0.5
            eulerRotation: Qt.vector3d(45, 135, 0)
            castsShadow: false
        }

        //Ambient light
        PointLight {
            color: Qt.rgba(0.2, 0.2, 0.2, 1)
            brightness: 0.2
            position: Qt.vector3d(0, 1000, 0)  // Position high above the scene
        }
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
        x: -200; y: 50; z: 50
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

        Repeater3D{
            model: 2
            Box3DBody {
                color: "orange"
                x: 150;  y: 50; z: 50
                width: 20
                scaledFace: Box3DGeometry.BottomFace
                faceScale: Qt.vector2d(.5, .5)
            }
        }
        Node{
            x: 150; y: 10; z: 100.1
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "Box3DBody"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
        }

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
