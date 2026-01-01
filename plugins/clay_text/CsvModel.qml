// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype CsvModel
    \inqmlmodule Clayground.Text
    \brief High-level component combining CSV reading/writing with a TableModel.

    CsvModel provides a convenient way to load CSV data into a Qt TableModel
    for display in views, and to save modified data back to CSV format.
    It supports filtering columns and rows, as well as transforming row data.

    Example usage:
    \qml
    import Clayground.Text

    CsvModel {
        id: gameData
        source: "enemies.csv"
        colFilter: (name) => ["id", "type", "health"].includes(name)
        rowFilter: (vals) => parseInt(vals[2]) > 50

        Component.onCompleted: load()
    }
    \endqml

    \qmlproperty string CsvModel::source
    \brief CSV file path or data to read.

    \qmlproperty string CsvModel::sourceDelimiter
    \brief Delimiter character for reading CSV (default: ",").

    \qmlproperty var CsvModel::colFilter
    \brief Function to filter columns: (colName) => bool.

    Return true to include the column, false to exclude it.

    \qmlproperty var CsvModel::rowFilter
    \brief Function to filter rows: (rowVals) => bool.

    Return true to include the row, false to exclude it.

    \qmlproperty var CsvModel::rowTransform
    \brief Function to transform row data: (rowVals) => array.

    Modify and return the row values array.

    \qmlproperty string CsvModel::destination
    \brief File path for saving CSV data.

    \qmlproperty string CsvModel::destinationDelimiter
    \brief Delimiter character for writing CSV (default: ",").

    \qmlproperty TableModel CsvModel::tableModel
    \brief The generated TableModel containing loaded data.

    Use this property to bind to TableView or other model-based views.

    \qmlproperty var CsvModel::colNames
    \readonly
    \brief Array of column names from the CSV header.
*/

import QtQuick
import Qt.labs.qmlmodels
import Clayground.Text

Item
{
    id: _csvModel

    property alias source: _reader.source
    property alias sourceDelimiter: _reader.delimiter

    property alias colFilter: _reader.colFilter
    property alias rowFilter: _reader.rowFilter
    property alias rowTransform: _reader.rowTransform

    property alias destination: _writer.destination
    property alias destinationDelimiter: _writer.delimiter

    property TableModel tableModel: null
    readonly property var colNames: []

    /*!
        \qmlmethod void CsvModel::load()
        \brief Loads CSV data from the source into the tableModel.

        Parses the CSV file, applies column and row filters, and populates
        the tableModel with the resulting data.
    */
    function load() {_reader.load();}

    /*!
        \qmlmethod void CsvModel::save()
        \brief Saves the current tableModel data to the destination file.

        Writes all rows from the tableModel to a CSV file at the
        destination path using the destinationDelimiter.
    */
    function save() {_writer.save();}

    CsvReader {
        id: _reader

        property var colFilter: (colName) => {return true;}
        property var rowFilter: (rowVals) => {return true;}
        property var rowTransform: (rowVals) => {return rowVals;}

        onColumnNames: (names) =>
                       {
                           let cols = "";
                           for (let name of names) {
                               colNames.push(name)
                               if (!colFilter(name)) continue;
                               cols += "TableModelColumn{display: \"" + name + "\"}\n";
                           }

                           // Need to be instantiated from text representation
                           // as otherwise dynamic number of columns is not
                           // allowed/supported (Qt 6.3.0)
                           const comp =
                           `
                           import QtQuick
                           import Qt.labs.qmlmodels

                           TableModel
                           {
                           ${cols}
                           }
                           `

                           tableModel = Qt.createQmlObject(comp ,
                                                           tableView,
                                                           "DynamicTableModel");
                       }
        onRow: (vals) =>
               {
                   if (!rowFilter(vals)) return;
                   let obj = {};
                   vals = rowTransform(vals);
                   for (let i = 0; i<vals.length; ++i) {
                       obj[colNames[i]] = vals[i];
                   }
                   tableModel.appendRow(obj)
               }
    }

    CsvWriter {
        id: _writer

        function save() {
            const model = _csvModel.tableModel;
            let cols = [];
            let i=0;

            for (i = 0; i<model.columnCount; ++i)
                cols.push(model.columns[i].display);

            begin(cols);

            for (i = 0; i<model.rowCount; ++i){
                const obj = model.rows[i];
                let row = [];
                for (const p of cols) row.push(obj[p]);
                appendRow(row);
            }

            finish();
        }
    }
}
