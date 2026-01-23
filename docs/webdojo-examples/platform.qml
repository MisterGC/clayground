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
            text: "URL Arguments (dojoArgs)"
            font.family: root.monoFont
            font.pixelSize: 18
            font.bold: true
            color: root.accentColor
        }

        Text {
            Layout.fillWidth: true
            text: "Try adding &playerName=YourName&level=5 to the URL hash!"
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.dimTextColor
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: argsColumn.implicitHeight + 20
            color: root.surfaceColor
            radius: 6

            ColumnLayout {
                id: argsColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Current dojoArgs:"
                    font.family: root.monoFont
                    font.pixelSize: 14
                    font.bold: true
                    color: root.dimTextColor
                }

                Text {
                    id: argsDisplay
                    Layout.fillWidth: true
                    text: formatArgs(Clayground.dojoArgs)
                    font.family: root.monoFont
                    font.pixelSize: 14
                    color: root.textColor
                    wrapMode: Text.Wrap

                    function formatArgs(args) {
                        let keys = Object.keys(args);
                        if (keys.length === 0) return "(none)";
                        return keys.map(k => k + " = \"" + args[k] + "\"").join("\n");
                    }
                }
            }
        }

        RowLayout {
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 32
                color: root.surfaceColor
                radius: 4
                border.color: keyInput.activeFocus ? root.accentColor : "transparent"
                border.width: 2

                TextInput {
                    id: keyInput
                    anchors.fill: parent
                    anchors.margins: 8
                    font.family: root.monoFont
                    font.pixelSize: 14
                    color: root.textColor
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: "key"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        color: root.dimTextColor
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 32
                color: root.surfaceColor
                radius: 4
                border.color: valueInput.activeFocus ? root.accentColor : "transparent"
                border.width: 2

                TextInput {
                    id: valueInput
                    anchors.fill: parent
                    anchors.margins: 8
                    font.family: root.monoFont
                    font.pixelSize: 14
                    color: root.textColor
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: "value"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        color: root.dimTextColor
                        visible: !parent.text && !parent.activeFocus
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 32
                color: setBtn.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: "Set"
                    font.family: root.monoFont
                    font.pixelSize: 14
                    font.bold: true
                    color: root.color
                }

                MouseArea {
                    id: setBtn
                    anchors.fill: parent
                    onClicked: {
                        if (keyInput.text) {
                            let success = Clayground.setDojoArg(keyInput.text, valueInput.text);
                            statusText.showStatus(success ? "Set '" + keyInput.text + "'" : "Failed (reserved key?)");
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                color: removeBtn.pressed ? Qt.darker("#ef4444", 1.2) : "#ef4444"
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: "Remove"
                    font.family: root.monoFont
                    font.pixelSize: 14
                    font.bold: true
                    color: root.color
                }

                MouseArea {
                    id: removeBtn
                    anchors.fill: parent
                    onClicked: {
                        if (keyInput.text) {
                            let success = Clayground.removeDojoArg(keyInput.text);
                            statusText.showStatus(success ? "Removed '" + keyInput.text + "'" : "Failed");
                        }
                    }
                }
            }
        }

        Text {
            id: statusText
            font.family: root.monoFont
            font.pixelSize: 12
            color: root.dimTextColor
            opacity: 0

            function showStatus(msg) {
                text = msg;
                opacity = 1;
                statusFade.restart();
            }

            NumberAnimation on opacity {
                id: statusFade
                running: false
                to: 0
                duration: 2000
                easing.type: Easing.InQuad
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: root.surfaceColor
        }

        Text {
            Layout.fillWidth: true
            text: "This demo tests the Clayground singleton's platform detection, capabilities, and URL argument API."
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
