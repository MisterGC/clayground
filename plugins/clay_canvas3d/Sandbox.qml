// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick.Controls
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Storage

Item {
    anchors.fill: parent


    KeyValueStore {
        id: _kvStore
        name: "Clayground.Canvas3D.Store"
    }

    View3D {
        id: view
        anchors.fill: parent

        Component.onCompleted: {
            if (_kvStore.has("camPos"))
                camera.position = JSON.parse(_kvStore.get("camPos"));
            if (_kvStore.has("camEuler"))
                camera.eulerRotation = JSON.parse(_kvStore.get("camEuler"));
        }


        Component.onDestruction: {
            _kvStore.set("camPos", JSON.stringify(camera.position));
            _kvStore.set("camEuler", JSON.stringify(camera.eulerRotation));
        }

        // Add focus to receive key events
        focus: true

        // Add property to track current control mode
        property bool controllingPacman: false

        // Add properties to track movement
        property vector3d pacmanDirection: Qt.vector3d(0, 0, 0)
        property real pacmanSpeed: 2  // Units per frame, adjust as needed

        // Add timer for continuous movement
        Timer {
            id: pacmanMoveTimer
            interval: 16  // Approximately 60 FPS
            running: view.controllingPacman
            repeat: true
            onTriggered: {
                if (view.controllingPacman) {
                    _pacman.x += view.pacmanDirection.x * view.pacmanSpeed
                    _pacman.z += view.pacmanDirection.z * view.pacmanSpeed
                }
            }
        }

        // Add key handling
        Keys.onPressed: function(event) {

            // Toggle control mode with 'T' key
            if (event.key === Qt.Key_T) {
                controllingPacman = !controllingPacman;
                forceActiveFocus();
                event.accepted = true;
                return;
            }

            // Only handle movement keys when controlling Pacman
            if (controllingPacman) {
                switch(event.key) {
                case Qt.Key_W:
                    pacmanDirection = Qt.vector3d(0, 0, -1)
                    _pacman.eulerRotation.y = 90  // Rotate to face -Z direction
                    event.accepted = true
                    break
                case Qt.Key_S:
                    pacmanDirection = Qt.vector3d(0, 0, 1)
                    _pacman.eulerRotation.y = 270   // Rotate to face +Z direction
                    event.accepted = true
                    break
                case Qt.Key_A:
                    pacmanDirection = Qt.vector3d(-1, 0, 0)
                    _pacman.eulerRotation.y = 180  // Rotate to face -X direction
                    event.accepted = true
                    break
                case Qt.Key_D:
                    pacmanDirection = Qt.vector3d(1, 0, 0)
                    _pacman.eulerRotation.y = 0    // Rotate to face +X direction
                    event.accepted = true
                    break
                default:
                    event.accepted = false
                }
            }
        }

        environment: SceneEnvironment {
            clearColor: "black"
            backgroundMode: SceneEnvironment.Color
        }

        DebugSettings{
            wireframeEnabled: true
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(-40, 120, 300)
            eulerRotation: Qt.vector3d(-15, 0, 0)
            //lookAtNode: _daNode
        }

        Node {
            id: _lighting

            // Main directional light (sun)
            DirectionalLight {
                id: mainLight
                color: Qt.rgba(1, 0.98, 0.95, 1)
                brightness: 0.5  // Reduced from 0.7 for less harsh shadows
                eulerRotation: Qt.vector3d(-30, -45, 0)  // Changed angle to better illuminate all faces
                castsShadow: true
                shadowFactor: 25  // Reduced from 50 for softer shadows
                shadowMapQuality: Light.ShadowMapQualityHigh
                shadowMapFar: 2000
                shadowBias: 5
                ambientColor: Qt.rgba(0.6, 0.6, 0.6, 1)  // Increased ambient light for better fill
            }

            // Add a second directional light from another angle
            DirectionalLight {
                color: Qt.rgba(0.9, 0.9, 1.0, 1)  // Slightly blue-tinted light
                brightness: 0.3
                eulerRotation: Qt.vector3d(-20, 135, 0)  // Coming from opposite direction
                castsShadow: false  // No shadows from fill light
            }

            // Add ambient point light for general illumination
            PointLight {
                position: Qt.vector3d(0, 10000, 0)  // Position above the scene
                brightness: 0.15                    // Increased from 0.1
                quadraticFade: 0.0001             // Very gradual falloff
                castsShadow: false                // No shadows from ambient light
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
                running: true
                NumberAnimation {
                    target: _voxelMapInst
                    property: "spacing"
                    to: 2
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
                                           }}
                                   ]);
            }
        }

        StaticVoxelMap {
            id: _voxelMap
            castsShadows: true
            //x: 100; y: 0; z: 100
            showEdges: true; edgeColorFactor: 0.5;
            edgeThickness: 0.5
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
                                  // Base layer (largest)
                                  {
                                      box: {
                                          pos: Qt.vector3d(0, 0, 0),
                                          width: 40, height: 4, depth: 40,
                                          colors: [ { color: "#FF8C00", weight: 1 } ]  // Dark orange
                                      }
                                  },
                                  // Second layer
                                  {
                                      box: {
                                          pos: Qt.vector3d(5, 4, 5),
                                          width: 30, height: 4, depth: 30,
                                          colors: [ { color: "#FFA500", weight: 1 } ]  // Orange
                                      }
                                  },
                                  // Third layer
                                  {
                                      box: {
                                          pos: Qt.vector3d(10, 8, 10),
                                          width: 20, height: 4, depth: 20,
                                          colors: [ { color: "#FFB52E", weight: 1 } ]  // Light orange
                                      }
                                  },
                                  // Top layer (smallest)
                                  {
                                      box: {
                                          pos: Qt.vector3d(15, 12, 15),
                                          width: 10, height: 4, depth: 10,
                                          colors: [ { color: "#FFD700", weight: 1 } ]  // Gold
                                      }
                                  }
                              ]);
            }
        }


        DynamicVoxelMap {
            x: 200; y: 180; z: 200
            id: _rubikCube
            width: 3; height: 3; depth: 3
            voxelSize: 15.0; spacing: 0.0
            showEdges: true; edgeThickness: 1;
            edgeColorFactor: 0.5

            Component.onCompleted: _rubikCube.fill([{
                                                        box: {
                                                            pos: Qt.vector3d(0, 0, 0),
                                                            width: 3 , height: 3, depth: 3,
                                                            colors: [
                                                                { color: "white",  weight: 1/6 },
                                                                { color: "yellow", weight: 1/6 },
                                                                { color: "blue",   weight: 1/6 },
                                                                { color: "green",  weight: 1/6 },
                                                                { color: "red",    weight: 1/6 },
                                                                { color: "orange", weight: 1/6 }
                                                            ]
                                                        }
                                                    }]);
        }

        Node{

            id: _daNode
            x: 200; y: 100; z: 200
            NumberAnimation {
                target: _daNode
                property: "eulerRotation.y"
                loops: Animation.Infinite
                running: false
                from: 0
                to: 360
                duration: 10000
            }

            DynamicVoxelMap {
                id: _pacman
                width: 15; height: 15; depth: 15
                voxelSize: 4.0; spacing: 0.0
                showEdges: true; edgeThickness: 1;
                edgeColorFactor: 0.5

                // Add properties to control animation speed
                property real mouthFrequency: 2.0  // Opens mouth 2 times per second
                property real animationPhase: 1

                Timer {
                    interval: 50  // Keep 50ms interval for smooth animation
                    running: true
                    repeat: true
                    onTriggered: {
                        // Adjust phase increment based on desired frequency
                        // frequency = 1/period
                        // phaseIncrement = (2π * interval/1000 * frequency)
                        _pacman.animationPhase = (_pacman.animationPhase +
                                                  (2 * Math.PI * 0.05 * _pacman.mouthFrequency)) % (2 * Math.PI)
                        _pacman.updatePacman()
                    }
                }

                function updatePacman() {
                    // Clear previous frame
                    fill([{
                              box: {
                                  pos: Qt.vector3d(0, 0, 0),
                                  width: width, height: height, depth: depth,
                                  colors: [{ color: "transparent", weight: 1.0 }]
                              }
                          }]);

                    let parts = [];

                    // Calculate center position relative to dimensions
                    let centerX = width / 2;
                    let centerY = height / 2;
                    let centerZ = depth / 2;

                    // Calculate radius relative to the smallest dimension
                    let radius = Math.min(width, height, depth) / 2;

                    // Main body
                    parts.push({
                                   sphere: {
                                       pos: Qt.vector3d(centerX, centerY, centerZ),
                                       radius: radius,
                                       colors: [{ color: "#FFFF00", weight: 1.0 }]
                                   }
                               });

                    // Mouth (using box subtraction)
                    let mouthSize = Math.abs(Math.sin(animationPhase)) * (radius * 0.4) + (radius * 0.1);
                    parts.push({
                                   box: {
                                       pos: Qt.vector3d(centerX + radius * 0.3, centerY - mouthSize/2, 0),
                                       width: width, // Make it wide enough to cut through
                                       height: mouthSize,
                                       depth: depth,
                                       colors: [{ color: "transparent", weight: 1.0 }]
                                   }
                               });

                    // Calculate eye size relative to radius
                    let eyeSize = Math.max(radius * 0.1,2);

                    // Left eye
                    parts.push({
                                   box: {
                                       pos: Qt.vector3d(centerX + radius * 0.5, centerY + radius * 0.5, centerZ + radius * 0.4),
                                       width: eyeSize,
                                       height: eyeSize,
                                       depth: eyeSize,
                                       colors: [{ color: "#000000", weight: 1.0 }]
                                   }
                               });

                    // Right eye
                    parts.push({
                                   box: {
                                       pos: Qt.vector3d(centerX + radius * 0.5, centerY + radius * 0.5, centerZ - radius * 0.4),
                                       width: eyeSize,
                                       height: eyeSize,
                                       depth: eyeSize,
                                       colors: [{ color: "#000000", weight: 1.0 }]
                                   }
                               });

                    fill(parts);
                }

                Component.onCompleted: updatePacman()
            }
        }

        // Update the label
        Node {
            x: 200; y: 40; z: 200
            Label {
                color: "black"
                background: Rectangle {opacity: .75}
                text: "Animated Pac-Man"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
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
                        materials: PrincipledMaterial { baseColor: "black" }
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
            enabled: !view.controllingPacman // Disable when controlling Pacman
        }

        /*AxisHelper{
            enableAxisLines: true
            enableXZGrid: true

        }*/

        // Add status text to show current control mode
        Text {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.pointSize: 12
            text: "Currently controlling: " + (view.controllingPacman ? "Pacman" : "Camera") + " (Press 'T' to toggle)"
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
