// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Text

/*!
    \qmltype DataRecorder
    \inqmlmodule Clayground.Lab
    \brief Records probe samples to a CSV file while recording is on.

    One row per sample tick (column t plus one column per probe). The
    file is written when recording stops. Backbone of the sweep runner's
    measurement output.

    Example usage:
    \qml
    import Clayground.Lab

    DataRecorder { id: rec; destination: "run.csv"; probes: ["kineticEnergy"] }
    // rec.recording = true ... rec.recording = false -> run.csv
    \endqml

    \sa Probe, Lab
*/
QtObject {
    id: _rec

    /*!
        \qmlproperty var DataRecorder::probes
        \brief Probe names to record (empty = all registered probes).
    */
    property var probes: []

    /*!
        \qmlproperty string DataRecorder::destination
        \brief CSV output path.
    */
    property string destination: "lab_recording.csv"

    /*!
        \qmlproperty bool DataRecorder::recording
        \brief Toggle to start/stop; stopping writes the file.
    */
    property bool recording: false

    /*!
        \qmlproperty int DataRecorder::rows
        \readonly
        \brief Rows recorded in the current/last run.
    */
    property int rows: 0

    property var _names: []
    property CsvWriter _writer: CsvWriter {}

    onRecordingChanged: {
        if (recording) {
            _names = probes.length ? probes.slice() : Lab.probeNames.slice()
            rows = 0
            _writer.destination = destination
            _writer.begin(["t"].concat(_names))
        } else {
            _writer.finish()
        }
    }

    property Connections _conn: Connections {
        target: Lab
        enabled: _rec.recording
        function onSampled(t) {
            const row = [t.toFixed(4)]
            for (const n of _rec._names) {
                const pr = Lab.probe(n)
                row.push(pr ? String(pr.value) : "")
            }
            _rec._writer.appendRow(row)
            _rec.rows++
        }
    }
}
