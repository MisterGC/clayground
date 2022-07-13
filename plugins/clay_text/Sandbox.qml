// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Text

Rectangle
{
    id: theRect
    color: "#896b6b"

    StackView {
        id: stack
        anchors.fill: parent
        initialItem: csvComp
    }

    Component { id: regExComp
        Item {
            id: highlightedText
            anchors.fill: parent
            Column {
                spacing: 10
                anchors {
                    left: parent.left; leftMargin: parent.width * .01
                    top: parent.top; topMargin: parent.height * .01
                }
                Text {
                    color: "white"
                    textFormat: Text.MarkdownText
                    text: "## Highlighted Text"
                }
                Row {
                    TextField {
                        id: regExInput;
                        width: regExTextInput.width
                        placeholderText: "<Enter a Regular Expression>"
                        color: "white"; font.pixelSize: 15; focus:true
                        Component.onCompleted: forceActiveFocus()
                    }
                }
                HighlightedText {
                    id: regExTextInput
                    width: highlightedText.width * .95
                    searchRegEx: regExInput.text
                    text:
`
    property alias yWuMin: _world.worldYMin
    property alias yWuMax: _world.worldYMax

    // MAP LOADING
    // Path to SVG which contains the initial world content
    property string map: ""
    // Base z-coord that is used when loading entities from the map
    property alias baseZCoord: mapLoader.baseZCoord
    property alias lastZCoord: mapLoader.lastZCoord
    // true -> entities get loaded without block UI
    property alias loadMapAsync: mapLoader.loadEntitiesAsync

    Component.onCompleted: {_moveToRoomOnDemand(); childrenChanged.connect(_moveToRoomOnDemand); _loadActive.restart();}
    Timer {id: _loadActive; interval: 1; onTriggered: mapLoader.active = true;}
    Connections{target: room; function onChildrenChanged(){_updateRoomContent();}}
`
                }
            }
        }
    }

    Component { id: jsonataComp
        Item {
            anchors.fill: parent
            Column {
                anchors {
                    left: parent.left; leftMargin: parent.width * .01
                    top: parent.top; topMargin: parent.height * .01
                }
                Text {
                    color: "white"
                    textFormat: Text.MarkdownText
                    text:
`
## JSONata
### Input: \` ${JSON.stringify(jsonataTransform.inputObject)} \`
### Query: \` ${jsonataTransform.jsonataString} \`
### Output: \` ${jsonataTransform.jsonOutput} \`
`
                }
                JsonataTransform {
                    id: jsonataTransform

                    // Enter the input object:
                    inputObject: {"example": [{"value": 4}, {"value": 7}, {"value": 13}]}

                    // Enter the JSONata query:
                    jsonataString: "$min(example.value)"
                }
            }
        }
    }

    Component { id: csvComp
        Item {
            anchors.fill: parent
            Column {
                anchors {
                    left: parent.left; leftMargin: parent.width * .01
                    top: parent.top; topMargin: parent.height * .01
                }
                Text {
                    color: "white"
                    textFormat: Text.MarkdownText
                    text: "## CSV\n\n ### Input: "
                }
                Text{
                    text: "```\n" + csvModel.source
                    textFormat: Text.MarkdownText
                    color: "white"
                }
                Text{text: "### Output (as table): "; color: "white"; textFormat: Text.MarkdownText}
                Item {height: 10; width: 10}
                TableView {
                    id: tableView
                    width: theRect.width * .8
                    height: theRect.height * .8
                    columnSpacing: 1
                    rowSpacing: 1
                    clip: true
                    model: csvModel.tableModel

                    delegate: Rectangle {
                        implicitWidth: 100
                        implicitHeight: 50
                        border.width: 1
                        Text {
                            text: display
                            anchors.centerIn: parent
                        }
                    }
                }
            }

            CsvModel {
                id: csvModel

                // Either enter a string containing the
                // CSV data directly or provide a path to a file
                source: "Col1, Col2, Col3 \n" +
                        "1.0,  2.0,  3.0  \n" +
                        "2.0,  3.0,  4.0  \n"
                //source: "/home/someuser/data/test.csv"
                sourceDelimiter: ","

                destination: "out.csv"
                destinationDelimiter: ";"

                // Step 1: Filter columns
                colFilter: (colName) => {
                               return (["Col1","Col2","Col3"].indexOf(colName) >= 0);}

                // Step 2: Filter rows
                rowFilter: (vals) => {return vals[colNames.indexOf("Col1")] === "1.0";}

                // Step 3: Transform rows
                rowTransform: (vals) => {return vals.map(v => v.replace(".", ","));}

                Component.onCompleted: {
                    load();
                    save();
                }
            }
        }
    }
}
