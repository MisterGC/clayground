// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Text

Rectangle {
    id: root
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    property int currentTab: 0

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        // Header
        Text {
            text: "Clayground.Text"
            font.family: root.monoFont
            font.pixelSize: 18
            font.bold: true
            color: root.accentColor
        }

        // Tab bar
        Row {
            spacing: 8

            Repeater {
                model: ["CSV", "RegEx Highlight", "JSONata"]

                Rectangle {
                    width: tabText.implicitWidth + 20
                    height: 30
                    radius: 4
                    color: root.currentTab === index ? root.accentColor : root.surfaceColor

                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: modelData
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.currentTab === index ? "white" : root.dimTextColor
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.currentTab = index
                    }
                }
            }
        }

        // Content area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.surfaceColor
            radius: 6

            // CSV Demo
            Item {
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentTab === 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "CSV Parsing & Transformation"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        font.bold: true
                        color: root.textColor
                    }

                    Text {
                        text: "Input:"
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.dimTextColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: csvSourceText.implicitHeight + 16
                        color: Qt.darker(root.surfaceColor, 1.3)
                        radius: 4

                        Text {
                            id: csvSourceText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: csvModel.source.trim()
                            font.family: root.monoFont
                            font.pixelSize: 11
                            color: root.textColor
                            wrapMode: Text.Wrap
                        }
                    }

                    Text {
                        text: "Output (filtered & transformed):"
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.dimTextColor
                    }

                    TableView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columnSpacing: 1
                        rowSpacing: 1
                        clip: true
                        model: csvModel.tableModel

                        delegate: Rectangle {
                            implicitWidth: 100
                            implicitHeight: 36
                            color: Qt.darker(root.surfaceColor, 1.3)
                            radius: 2

                            Text {
                                text: display
                                anchors.centerIn: parent
                                font.family: root.monoFont
                                font.pixelSize: 12
                                color: root.textColor
                            }
                        }
                    }
                }

                CsvModel {
                    id: csvModel
                    source: "Col1, Col2, Col3 \n" +
                            "1.0,  2.0,  3.0  \n" +
                            "2.0,  3.0,  4.0  \n"
                    sourceDelimiter: ","
                    destination: "out.csv"
                    destinationDelimiter: ";"
                    colFilter: (colName) => {
                        return (["Col1","Col2","Col3"].indexOf(colName) >= 0);
                    }
                    rowFilter: (vals) => { return vals[colNames.indexOf("Col1")] === "1.0"; }
                    rowTransform: (vals) => { return vals.map(v => v.replace(".", ",")); }
                    Component.onCompleted: { load(); save(); }
                }
            }

            // RegEx Highlight Demo
            Item {
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentTab === 1

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "Regular Expression Highlighting"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        font.bold: true
                        color: root.textColor
                    }

                    TextField {
                        id: regExInput
                        Layout.fillWidth: true
                        placeholderText: "Enter a Regular Expression..."
                        font.family: root.monoFont
                        font.pixelSize: 13
                        color: root.textColor
                        placeholderTextColor: root.dimTextColor
                        background: Rectangle {
                            color: Qt.darker(root.surfaceColor, 1.3)
                            radius: 4
                            border.color: regExInput.focus ? root.accentColor : "transparent"
                            border.width: 1
                        }
                    }

                    HighlightedText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        searchRegEx: regExInput.text
                        text:
`    property alias yWuMin: _world.worldYMin
    property alias yWuMax: _world.worldYMax

    // MAP LOADING
    property string map: ""
    property alias baseZCoord: mapLoader.baseZCoord
    property alias lastZCoord: mapLoader.lastZCoord
    property alias loadMapAsync: mapLoader.loadEntitiesAsync

    Component.onCompleted: {
        _moveToRoomOnDemand();
        childrenChanged.connect(_moveToRoomOnDemand);
    }`
                    }
                }
            }

            // JSONata Demo
            Item {
                anchors.fill: parent
                anchors.margins: 15
                visible: root.currentTab === 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15

                    Text {
                        text: "JSONata Transform"
                        font.family: root.monoFont
                        font.pixelSize: 14
                        font.bold: true
                        color: root.textColor
                    }

                    Text {
                        text: "Input: " + JSON.stringify(jsonataTransform.inputObject)
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.dimTextColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    Text {
                        text: "Query: " + jsonataTransform.jsonataString
                        font.family: root.monoFont
                        font.pixelSize: 12
                        color: root.accentColor
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: outputText.implicitHeight + 20
                        color: Qt.darker(root.surfaceColor, 1.3)
                        radius: 4

                        Text {
                            id: outputText
                            anchors.centerIn: parent
                            text: "Result: " + jsonataTransform.jsonOutput
                            font.family: root.monoFont
                            font.pixelSize: 16
                            font.bold: true
                            color: "#4ade80"
                        }
                    }

                    JsonataTransform {
                        id: jsonataTransform
                        inputObject: {"example": [{"value": 4}, {"value": 7}, {"value": 13}]}
                        jsonataString: "$min(example.value)"
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
