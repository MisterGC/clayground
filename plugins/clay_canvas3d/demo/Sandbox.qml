// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief 3D boxes, voxel maps and line rendering with toon shading
// @tags 3D, Canvas3D, Voxels

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D
import Clayground.Storage

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

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
            Layout.preferredWidth: 220
            Layout.fillHeight: true
            color: root.surfaceColor

            Column {
                width: parent.width
                padding: 10
                spacing: 5

                // Title
                Text {
                    text: "Clayground.Canvas3D"
                    font.family: root.monoFont
                    font.pixelSize: 16
                    font.bold: true
                    color: root.accentColor
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
                        height: 36
                        color: demoLoader.currentDemo === modelData.component ? root.accentColor :
                               menuItemArea.containsMouse ? Qt.darker(root.surfaceColor, 1.3) : "transparent"
                        radius: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: modelData.name
                            font.family: root.monoFont
                            font.pixelSize: 12
                            color: demoLoader.currentDemo === modelData.component ? "white" : root.textColor
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
                    color: Qt.darker(root.surfaceColor, 1.3)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Info section
                Text {
                    text: "Controls"
                    font.family: root.monoFont
                    font.pixelSize: 13
                    font.bold: true
                    color: root.textColor
                    padding: 10
                    topPadding: 20
                }

                Text {
                    text: "Left drag: Rotate\n" +
                          "Right drag: Pan\n" +
                          "Scroll: Zoom\n" +
                          "F: Focus on origin"
                    color: root.dimTextColor
                    font.family: root.monoFont
                    font.pixelSize: 11
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
            color: "#1a1a2e"

            Loader {
                id: demoLoader
                anchors.fill: parent
                property string currentDemo: "Box3DDemo.qml"
                // Relative path - works with URL-based loading in webdojo
                source: currentDemo

                // Pass common properties to loaded demos
                property var cameraStore: kvStore
            }
        }
    }
}