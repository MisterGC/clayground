// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Text

Rectangle
{
    id: theRect
    color: "#896b6b"

    Column {
        anchors {
            left: parent.left; leftMargin: parent.width * .01
            top: parent.top; topMargin: parent.height * .01
        }
        Text{
            id: jsonOut;
            text: "JSONata output: " + jsonataTransform.jsonOutput
            color: "white"
        }
        Text{
            text: "CSV output: "
            color: "white"
        }
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

    JsonataTransform {
        id: jsonataTransform

        // Enter the input object:
        inputObject: {"example": [{"value": 4}, {"value": 7}, {"value": 13}]}

        // Enter the JSONata query:
        jsonataString: "$min(example.value)"
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
