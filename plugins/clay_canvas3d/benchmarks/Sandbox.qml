// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Baseline performance benchmarks for the Canvas3D 3D primitives
// @tags 3D, Canvas3D, Benchmark, Performance
// @category Plugin Benchmarks
//
// Sidebar loader over the benchmark pages. Each page auto-runs its stepped
// scenario, logs a CSV into benchmarks/results/ via BenchLogger, and prints
// "BENCH DONE <name>" to the console when finished. Selecting a page (re)starts
// it. Pages can also be run standalone: claydojo --sbx <page>.qml

import QtQuick
import QtQuick.Layouts

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

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: root.surfaceColor

            Column {
                width: parent.width
                padding: 10
                spacing: 5

                Text {
                    text: "Canvas3D Benchmarks"
                    font.family: root.monoFont
                    font.pixelSize: 15
                    font.bold: true
                    color: root.accentColor
                    padding: 10
                }

                Repeater {
                    model: [
                        { name: "Lines - Static", component: "BenchLinesStatic.qml" },
                        { name: "Lines - Dynamic", component: "BenchLinesDynamic.qml" },
                        { name: "Lines - Batch Overdraw", component: "BenchLinesBatch.qml" },
                        { name: "Connectors - Moving", component: "BenchConnectors.qml" },
                        { name: "Instances - Orbiting", component: "BenchInstances.qml" },
                        { name: "Voxel - Edit Storm", component: "BenchVoxelEdit.qml" },
                        { name: "Voxel - Churn", component: "BenchVoxelChurn.qml" },
                        { name: "Areas - Poly vs Strips", component: "BenchAreas.qml" }
                    ]

                    Rectangle {
                        width: parent.width - 20
                        height: 36
                        color: benchLoader.current === modelData.component ? root.accentColor :
                               itemArea.containsMouse ? Qt.darker(root.surfaceColor, 1.3) : "transparent"
                        radius: 4

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: modelData.name
                            font.family: root.monoFont
                            font.pixelSize: 12
                            color: benchLoader.current === modelData.component ? "white" : root.textColor
                        }

                        MouseArea {
                            id: itemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                // Force a reload even if re-selecting the same page.
                                benchLoader.current = ""
                                benchLoader.current = modelData.component
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width - 20
                    height: 1
                    color: Qt.darker(root.surfaceColor, 1.3)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Each page auto-runs a stepped\nscenario and writes a CSV into\nbenchmarks/results/. Watch the\nconsole for 'BENCH DONE'."
                    color: root.dimTextColor
                    font.family: root.monoFont
                    font.pixelSize: 11
                    leftPadding: 10
                    topPadding: 12
                    width: parent.width - 20
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a1a2e"

            Loader {
                id: benchLoader
                anchors.fill: parent
                property string current: "BenchLinesStatic.qml"
                source: current
            }
        }
    }
}
