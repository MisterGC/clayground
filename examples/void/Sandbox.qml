
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
        position: Qt.vector3d(0, 20, 0)
        eulerRotation: Qt.vector3d(-90, 0, 0)
    }

    DirectionalLight {
        eulerRotation: Qt.vector3d(-30, 0, 0)
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
        const rndCol = Qt.rgba(Math.random(), .7 + Math.random()*.2, Math.random(), 1);
        return {
            vertices: vertices,
            color: rndCol,
            width: 8
        };
    }

    Repeater3D {
        model: 1000
        delegate: Model {
            id: lineModel
            property var lineData: generateRandomLineData(Qt.vector3d(-100,-100,-100), Qt.vector3d(100,100,100), 10)

            geometry: Line3dGeometry {
                id: lineGeometry
                vertices: lineData.vertices
                color: lineData.color
                width: lineData.width
            }

            materials: [
                DefaultMaterial {
                    lighting: DefaultMaterial.NoLighting
                    cullMode: DefaultMaterial.NoCulling
                    diffuseColor: lineGeometry.color
                }
            ]
        }
    }

    function generateGrass(volume) {
        let grassElements = [];
        let minLength = 0.1 * volume.height;
        let maxLength = volume.height;

        let length = minLength + Math.random() * (maxLength - minLength);
        let angle = Math.random() * 2 * Math.PI; // Random angle for direction in the x-z plane
        let anchorPoint = Qt.vector3d(

            volume.x + Math.random() * volume.width,
            volume.y,
            volume.z + Math.random() * volume.depth
        );
        let endPoint = Qt.vector3d(
            anchorPoint.x + length * Math.cos(angle),
            anchorPoint.y + length, // Grass grows upwards
            anchorPoint.z + length * Math.sin(angle)
        );

        // Green color variations
        let greenShade = 0.5 + Math.random() * 0.5; // Values between 0.5 and 1
        let color = Qt.rgba(0, greenShade, 0, 1);

        return{
            vertices: [anchorPoint,endPoint],
            color: color,
            width: .5
        };
    }

    Repeater3D {
        model: 1000

        delegate:
            BoxLine3d {
            id: myLine
            property var lineData: generateRandomLineData(Qt.vector3d(0,0,0),
                                                          Qt.vector3d(100,100,100),
                                                          5)
            //property var lineData: generateGrass({ x: 0, y: 0, z: 0, width: 10, depth: 10, height: 1 })
            positions: lineData.vertices
            color: lineData.color
            width: 2

        }
    }

    WasdController {
        controlledObject: camera
        forwardSpeed: .5
        backSpeed: .5

    }
}
