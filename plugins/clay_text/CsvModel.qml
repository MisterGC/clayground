// (c) Clayground Contributors - MIT License, see "LICENSE" file

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

    function load() {_reader.load();}
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
