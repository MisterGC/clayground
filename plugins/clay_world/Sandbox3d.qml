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

Item {
    anchors.fill: parent



View3D {
    id: view
    anchors.fill: parent


    environment: SceneEnvironment {
        clearColor: "black"
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
        x: -200; y: 0; z: 50
        width: 100
        pickable: true
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

    Box3D  {
        id: _positionMarker
        x: -200; y: 0; z: 50
        width: 10
        color: "lightblue"
        castsShadows: true
        receivesShadows: false
    }

    DynamicVoxelMap {
        id: _voxelMapInst
        castsShadows: true
        x: -200; y: 0; z: 300
        width: 30; height: 30; depth: 30
        voxelSize: 2.0; spacing: 0.0

        SequentialAnimation{
            loops: Animation.Infinite
            running: false
            NumberAnimation {
                target: _voxelMapInst
                property: "spacing"
                to: 5
                duration: 3000
            }
            NumberAnimation {
                target: _voxelMapInst
                property: "spacing"
                to: 0
                duration: 3000
            }
        }

        Component.onCompleted: {

            _voxelMapInst.fill([
                               // Tree crown
                               { sphere: {
                                       pos: Qt.vector3d(10, 15, 10),
                                       radius: 8,
                                       colors: [
                                           { color: "#2D5A27", weight: 0.3 },
                                           { color: "#3A7729", weight: 0.3 },
                                           { color: "#4C9A2A", weight: 0.15 },
                                           { color: "red", weight: 0.05 },
                                           { color: "#68B030", weight: 0.15 },
                                           { color: "#89C34A", weight: 0.05 }
                                       ],
                                       noise: 0.3
                                   }},
                               // Tree trunk
                               { cylinder: {
                                       pos: Qt.vector3d(10, 0, 10),
                                       radius: 2,
                                       height: 10,
                                       colors: [
                                           { color: "#5C4033", weight: 0.4 },
                                           { color: "#8B4513", weight: 0.4 },
                                           { color: "#A0522D", weight: 0.2 }
                                       ]
                                   }},
                                   { box: {
                                       pos: Qt.vector3d(15, 15, 15),
                                       width: 30,
                                       height: 30,
                                       depth: 30,
                                       colors: [ { color: "red", weight: 1 } ]
                                   }}
                           ]);
        }
    }

    StaticVoxelMap {
        id: _voxelMap
        castsShadows: true
        //x: 100; y: 0; z: 100
        instancing: InstanceList {
            instances: [
                InstanceListEntry {
                    position: Qt.vector3d(-300, 0, 100)
                    scale: Qt.vector3d(1, 1, 1)
                },
                InstanceListEntry {
                    position: Qt.vector3d(-320, 0, 200)
                    scale: Qt.vector3d(0.9, 0.9, 0.9)
                },
                InstanceListEntry {
                    position: Qt.vector3d(-400, 0, 150)
                    scale: Qt.vector3d(1.1, 1.1, 1.1)
                }
            ]
        }
        width: 30; height: 30; depth: 30
        voxelSize: 5.0; spacing: 0.0
        Component.onCompleted: {

            _voxelMap.fill([
                               // Tree crown
                               { sphere: {
                                       pos: Qt.vector3d(10, 15, 10),
                                       radius: 8,
                                       colors: [
                                           { color: "#2D5A27", weight: 0.3 },
                                           { color: "#3A7729", weight: 0.3 },
                                           { color: "#4C9A2A", weight: 0.15 },
                                           { color: "red", weight: 0.05 },
                                           { color: "#68B030", weight: 0.15 },
                                           { color: "#89C34A", weight: 0.05 }
                                       ],
                                       noise: 0.3
                                   }},
                               // Tree trunk
                               { cylinder: {
                                       pos: Qt.vector3d(10, 0, 10),
                                       radius: 2,
                                       height: 10,
                                       colors: [
                                           { color: "#5C4033", weight: 0.4 },
                                           { color: "#8B4513", weight: 0.4 },
                                           { color: "#A0522D", weight: 0.2 }
                                       ]
                                   }}
                           ]);

        }
    }

    Node{
        x: -400; y: 10; z: 200
        Label {
            color: "black"
            background: Rectangle {opacity: .75}
            text: "VoxelMap with Instancing"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    DynamicVoxelMap {
        id: _roomMap
        castsShadows: true
        x: 50; y: 0; z: 300
        width: 40; height: 20; depth: 40
        voxelSize: 5.0; spacing: 0.0
        Component.onCompleted: {
            _roomMap.fill([
                {
                    "box": {
                        pos: Qt.vector3d(20, 10, 20),
                        width: 40, height: 20, depth: 40,
                        colors: [ { color: "blue", weight: 1 } ]
                    }//,
                    // "box": {
                    //     pos: Qt.vector3d(0, 1, 0),
                    //     width: 20, height: 100, depth: 40,
                    //     colors: [ { color: "transparent", weight: 1 } ]
                    // }
                }
            ]);
        }
    }

    // Optional label for the room
    Node {
        x: -300; y: 30; z: 0
        Label {
            color: "black"
            background: Rectangle {opacity: .75}
            text: "Voxel Room"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
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
                    pickable: true
                    source: "#Rectangle"
                    scale: Qt.vector3d(2000, 2000, 1)
                    materials: PrincipledMaterial { baseColor: "white" }
                    castsShadows: false
                    receivesShadows: true
                }
            }
            Model {
                visible: false
                y: 0.5
                scale: Qt.vector3d(2000, 2000, 2000)
                eulerRotation: Qt.vector3d(-90, 0, 0)
                geometry: GridGeometry {
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


    MouseArea {
        anchors.fill: view
        //! [mouse area]

        onClicked: (mouse) => {
            // Get screen coordinates of the click
            pickPosition.text = "(" + mouse.x + ", " + mouse.y + ")"
            //! [pick result]
            var result = view.pick(mouse.x, mouse.y);
            //! [pick result]
            //! [pick specifics]
            if (result.objectHit) {
                var pickedObject = result.objectHit;
                // Get picked model name
                pickName.text = pickedObject.objectName;
                // Get other pick specifics
                uvPosition.text = "("
                        + result.uvPosition.x.toFixed(2) + ", "
                        + result.uvPosition.y.toFixed(2) + ")";
                distance.text = result.distance.toFixed(2);
                scenePosition.text = "("
                        + result.scenePosition.x.toFixed(2) + ", "
                        + result.scenePosition.y.toFixed(2) + ", "
                        + result.scenePosition.z.toFixed(2) + ")";
                _positionMarker.position = result.scenePosition;
                localPosition.text = "("
                        + result.position.x.toFixed(2) + ", "
                        + result.position.y.toFixed(2) + ", "
                        + result.position.z.toFixed(2) + ")";
                worldNormal.text = "("
                        + result.sceneNormal.x.toFixed(2) + ", "
                        + result.sceneNormal.y.toFixed(2) + ", "
                        + result.sceneNormal.z.toFixed(2) + ")";
                localNormal.text = "("
                        + result.normal.x.toFixed(2) + ", "
                        + result.normal.y.toFixed(2) + ", "
                        + result.normal.z.toFixed(2) + ")";
                //! [pick specifics]
            } else {
                pickName.text = "None";
                uvPosition.text = "";
                distance.text = "";
                scenePosition.text = "";
                localPosition.text = "";
                worldNormal.text = "";
                localNormal.text = "";
            }
        }
    }
}
Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        spacing: 10
        Column {
            Label {
                color: "white"
                font.pointSize: 14
                text: "Last Pick:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "Screen Position:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "UV Position:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "Distance:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "World Position:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "Local Position:"
            }

            Label {
                color: "white"
                font.pointSize: 14
                text: "World Normal:"
            }
            Label {
                color: "white"
                font.pointSize: 14
                text: "Local Normal:"
            }
        }
        Column {
            Label {
                id: pickName
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: pickPosition
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: uvPosition
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: distance
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: scenePosition
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: localPosition
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: worldNormal
                color: "white"
                font.pointSize: 14
            }
            Label {
                id: localNormal
                color: "white"
                font.pointSize: 14
            }

        }
    }





MouseArea {
        anchors.fill: view
        //! [mouse area]

        onClicked: (mouse) => {
            // Get screen coordinates of the click
            pickPosition.text = "(" + mouse.x + ", " + mouse.y + ")"
            //! [pick result]
            var result = view.pick(mouse.x, mouse.y);
            //! [pick result]
            //! [pick specifics]
            if (result.objectHit) {
                var pickedObject = result.objectHit;
                // Get picked model name
                pickName.text = pickedObject.objectName;
                // Get other pick specifics
                uvPosition.text = "("
                        + result.uvPosition.x.toFixed(2) + ", "
                        + result.uvPosition.y.toFixed(2) + ")";
                distance.text = result.distance.toFixed(2);
                scenePosition.text = "("
                        + result.scenePosition.x.toFixed(2) + ", "
                        + result.scenePosition.y.toFixed(2) + ", "
                        + result.scenePosition.z.toFixed(2) + ")";
                _positionMarker.position = result.scenePosition;
                localPosition.text = "("
                        + result.position.x.toFixed(2) + ", "
                        + result.position.y.toFixed(2) + ", "
                        + result.position.z.toFixed(2) + ")";
                worldNormal.text = "("
                        + result.sceneNormal.x.toFixed(2) + ", "
                        + result.sceneNormal.y.toFixed(2) + ", "
                        + result.sceneNormal.z.toFixed(2) + ")";
                localNormal.text = "("
                        + result.normal.x.toFixed(2) + ", "
                        + result.normal.y.toFixed(2) + ", "
                        + result.normal.z.toFixed(2) + ")";
                //! [pick specifics]
            } else {
                pickName.text = "None";
                uvPosition.text = "";
                distance.text = "";
                scenePosition.text = "";
                localPosition.text = "";
                worldNormal.text = "";
                localNormal.text = "";
            }
        }
    }

}
