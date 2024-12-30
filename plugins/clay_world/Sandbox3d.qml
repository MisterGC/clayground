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
        position: Qt.vector3d(0, 170, 300)
        eulerRotation: Qt.vector3d(-40, 0, 0)
    }

    DirectionalLight { }
    PointLight {z: 500}


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

    WasdController {
        controlledObject: camera
        forwardSpeed: .5
        backSpeed: .5

    }
}
