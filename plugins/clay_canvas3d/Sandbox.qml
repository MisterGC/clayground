// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Storage

Item {
    id: root
    anchors.fill: parent

    // Store camera position between sessions
    KeyValueStore {
        id: kvStore
        name: "Clayground.Canvas3D.Sandbox"
    }

    // Main layout with sidebar and content
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Left sidebar menu
        Rectangle {
            Layout.preferredWidth: 250
            Layout.fillHeight: true
            color: "#2c3e50"

            Column {
                width: parent.width
                padding: 10
                spacing: 5

                // Title
                Text {
                    text: "Canvas3D Demos"
                    font.pixelSize: 20
                    font.bold: true
                    color: "white"
                    padding: 10
                }

                // Menu items
                Repeater {
                    model: [
                        { name: "Box3D Examples", component: "Box3DDemo.qml" },
                        { name: "Line Examples", component: "LineDemo.qml" },
                        { name: "Voxel Examples", component: "VoxelDemo.qml" }
                    ]

                    Rectangle {
                        width: parent.width - 20
                        height: 40
                        color: demoLoader.currentDemo === modelData.component ? "#3498db" : 
                               menuItemArea.containsMouse ? "#34495e" : "transparent"
                        radius: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: modelData.name
                            color: "white"
                        }

                        MouseArea {
                            id: menuItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                demoLoader.currentDemo = modelData.component
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width - 20
                    height: 1
                    color: "#34495e"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 20
                }

                // Info section
                Text {
                    text: "Controls"
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                    padding: 10
                    topPadding: 20
                }

                Text {
                    text: "• Left click + drag: Rotate camera\n" +
                          "• Right click + drag: Pan camera\n" + 
                          "• Scroll: Zoom in/out\n" +
                          "• F: Focus on origin"
                    color: "#ecf0f1"
                    font.pixelSize: 12
                    leftPadding: 10
                    width: parent.width - 20
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Main content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a1a"

            Loader {
                id: demoLoader
                anchors.fill: parent
                property string currentDemo: "Box3DDemo.qml"
                source: currentDemo

                // Pass common properties to loaded demos
                property var cameraStore: kvStore
            }
        }
    }
}