// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Layouts
import Clayground.Common

Rectangle {
    id: root
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Text {
            text: "Clayground Platform Info"
            font.family: root.monoFont
            font.pixelSize: 24
            font.bold: true
            color: root.accentColor
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: root.accentColor
            opacity: 0.5
        }

        GridLayout {
            columns: 2
            columnSpacing: 20
            rowSpacing: 10

            Text {
                text: "runsInSandbox:"
                font.family: root.monoFont
                font.pixelSize: 16
                color: root.dimTextColor
            }
            Text {
                text: Clayground.runsInSandbox ? "true" : "false"
                font.family: root.monoFont
                font.pixelSize: 16
                font.bold: true
                color: Clayground.runsInSandbox ? "#4ade80" : root.textColor
            }

            Text {
                text: "isWasm:"
                font.family: root.monoFont
                font.pixelSize: 16
                color: root.dimTextColor
            }
            Text {
                text: Clayground.isWasm ? "true" : "false"
                font.family: root.monoFont
                font.pixelSize: 16
                font.bold: true
                color: Clayground.isWasm ? "#4ade80" : root.textColor
            }

            Text {
                text: "browser:"
                font.family: root.monoFont
                font.pixelSize: 16
                color: root.dimTextColor
            }
            Text {
                text: Clayground.browser
                font.family: root.monoFont
                font.pixelSize: 16
                font.bold: true
                color: {
                    switch(Clayground.browser) {
                        case "chrome": return "#4285f4"
                        case "firefox": return "#ff7139"
                        case "safari": return "#006cff"
                        case "edge": return "#0078d7"
                        case "none": return root.dimTextColor
                        default: return root.textColor
                    }
                }
            }

            Text {
                text: "Qt.platform.os:"
                font.family: root.monoFont
                font.pixelSize: 16
                color: root.dimTextColor
            }
            Text {
                text: Qt.platform.os
                font.family: root.monoFont
                font.pixelSize: 16
                font.bold: true
                color: root.textColor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: root.surfaceColor
        }

        Text {
            text: "Capabilities"
            font.family: root.monoFont
            font.pixelSize: 18
            font.bold: true
            color: root.accentColor
        }

        GridLayout {
            columns: 3
            columnSpacing: 15
            rowSpacing: 8

            // Header
            Text { text: "Feature"; font.family: root.monoFont; font.pixelSize: 14; font.bold: true; color: root.dimTextColor }
            Text { text: "Status"; font.family: root.monoFont; font.pixelSize: 14; font.bold: true; color: root.dimTextColor }
            Text { text: "Hint"; font.family: root.monoFont; font.pixelSize: 14; font.bold: true; color: root.dimTextColor }

            // Clipboard
            Text { text: "clipboard"; font.family: root.monoFont; font.pixelSize: 14; color: root.textColor }
            Text {
                text: Clayground.capabilities.clipboard.status
                font.family: root.monoFont; font.pixelSize: 14; font.bold: true
                color: statusColor(Clayground.capabilities.clipboard.status)
            }
            Text {
                text: Clayground.capabilities.clipboard.hint || "-"
                font.family: root.monoFont; font.pixelSize: 12; color: root.dimTextColor
                Layout.preferredWidth: 200; wrapMode: Text.Wrap
            }

            // Sound
            Text { text: "sound"; font.family: root.monoFont; font.pixelSize: 14; color: root.textColor }
            Text {
                text: Clayground.capabilities.sound.status
                font.family: root.monoFont; font.pixelSize: 14; font.bold: true
                color: statusColor(Clayground.capabilities.sound.status)
            }
            Text {
                text: Clayground.capabilities.sound.hint || "-"
                font.family: root.monoFont; font.pixelSize: 12; color: root.dimTextColor
                Layout.preferredWidth: 200; wrapMode: Text.Wrap
            }

            // GPU
            Text { text: "gpu"; font.family: root.monoFont; font.pixelSize: 14; color: root.textColor }
            Text {
                text: Clayground.capabilities.gpu.status
                font.family: root.monoFont; font.pixelSize: 14; font.bold: true
                color: statusColor(Clayground.capabilities.gpu.status)
            }
            Text {
                text: Clayground.capabilities.gpu.hint || "-"
                font.family: root.monoFont; font.pixelSize: 12; color: root.dimTextColor
                Layout.preferredWidth: 200; wrapMode: Text.Wrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: root.surfaceColor
        }

        Text {
            Layout.fillWidth: true
            text: "This demo tests the Clayground singleton's platform and capability detection."
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.dimTextColor
            wrapMode: Text.Wrap
        }

        Item { Layout.fillHeight: true }
    }

    function statusColor(status) {
        switch(status) {
            case "full": return "#4ade80"        // green
            case "restricted": return "#f59e0b"  // amber
            case "unavailable": return "#ef4444" // red
            case "unknown": return "#8b5cf6"     // purple
            default: return root.dimTextColor
        }
    }
}
