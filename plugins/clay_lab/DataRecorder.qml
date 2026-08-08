// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Text
import "record.js" as Record

/*!
    \qmltype DataRecorder
    \inqmlmodule Clayground.Lab
    \brief Records a run as a citable run record (or as plain CSV).

    Recording starts and stops with \l recording. On stop the run is written
    to \l destination as a \e{run record}: a self-describing text file holding
    the lab id, scenario, seed, every parameter value, the per-probe series
    with their summaries, and the command that regenerates it. That file is
    what a paper cites - see \c{plugins/clay_lab/record.js} for the format and
    why it is shaped that way.

    Records belong in \c{labs/<lab>/records/} and are committed: they are small
    diffable text, and a record with no wall-clock field in it means two runs
    of the same seed produce the same bytes, so "does the paper still hold?" is
    a \c diff.

    A \c{.csv} destination still writes the flat table it always did - the
    spreadsheet escape hatch - but a CSV cannot be cited, because it carries no
    provenance.

    Example usage:
    \qml
    import Clayground.Lab

    DataRecorder {
        id: rec
        lab: "sensor-fusion-101"
        destination: "labs/sensor-fusion-101/records/open-sky-42.labrec"
        command: "labs/sensor-fusion-101/records/make.sh open-sky"
    }
    // rec.recording = true ... rec.recording = false -> the record is written
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
        \brief Output path. A \c{.csv} suffix selects the flat CSV table;
        anything else (by convention \c{.labrec}) writes a run record.

        Relative paths resolve against the process working directory, so a lab
        gives an explicit one - a bare default once littered the repo root.
    */
    property string destination: "lab_recording.labrec"

    /*!
        \qmlproperty string DataRecorder::format
        \brief \c "auto" (from the suffix), \c "record" or \c "csv".
    */
    property string format: "auto"

    /*!
        \qmlproperty string DataRecorder::lab
        \brief Lab id written into the record; defaults to the destination's
        parent-of-\c records directory when it can be read off the path.
    */
    property string lab: ""

    /*!
        \qmlproperty string DataRecorder::recordId
        \brief Id a paper cites this record by; defaults to the file's base name.

        Deliberately an INPUT rather than something generated: a record carries
        no wall clock, so its id has to come from outside if it is to name a
        particular run.
    */
    property string recordId: ""

    /*!
        \qmlproperty string DataRecorder::command
        \brief The command that regenerates this record, written into it.

        Empty is allowed and produces a record nobody can reproduce, which the
        recorder warns about rather than hiding.
    */
    property string command: ""

    /*!
        \qmlproperty int DataRecorder::steps
        \brief Fixed steps the run advanced, for the record's provenance
        (0 = unknown, e.g. a live dojo recording).
    */
    property int steps: 0

    /*!
        \qmlproperty real DataRecorder::stepSize
        \brief Sim seconds per step, for the record's provenance.

        0 falls back to \c SimClock.fixedStep. A driver that steps the clock
        itself (the headless record runs do) has to say so here, because a
        clock advanced from outside does not know how big the steps were.
    */
    property real stepSize: 0

    /*!
        \qmlproperty int DataRecorder::maxBytes
        \brief Size above which the sample table is thinned instead of written
        in full (the record stays committable; summaries stay over all samples).
    */
    property int maxBytes: 200 * 1024

    /*!
        \qmlproperty bool DataRecorder::recording
        \brief Toggle to start/stop; stopping writes the file.
    */
    property bool recording: false

    /*!
        \qmlproperty int DataRecorder::rows
        \readonly
        \brief Sample ticks recorded in the current/last run.
    */
    property int rows: 0

    /*!
        \qmlproperty string DataRecorder::lastFile
        \readonly
        \brief Path of the most recently written file ("" if none).
    */
    property string lastFile: ""

    /*!
        \qmlproperty string DataRecorder::error
        \readonly
        \brief Why the last write failed ("" if it did not).
    */
    property string error: ""

    /*!
        \qmlsignal DataRecorder::written(string path, int rows)
        \brief Emitted after a successful write.
    */
    signal written(string path, int rows)

    /*!
        \qmlmethod var DataRecorder::record()
        \brief The record object for what has been captured so far, without
        writing it - the shape \c{record.js} serializes.
    */
    function record() {
        return Record.build({
            id: _rec._id(),
            lab: _rec._labId(),
            scenario: Lab.scenario,
            seed: Lab.clock ? Lab.clock.seed : 0,
            steps: _rec.steps,
            stepSize: _rec.stepSize > 0 ? _rec.stepSize
                                        : (Lab.clock ? Lab.clock.fixedStep : 0),
            sampleInterval: Lab.clock ? Lab.clock.sampleInterval : 0,
            command: _rec.command,
            params: _rec._paramList(),
            probes: _rec._probeList(),
            rows: _rec._rows
        })
    }

    property var _names: []
    property var _rows: []
    property bool _csv: false
    property CsvWriter _writer: CsvWriter {}
    property TextWriter _text: TextWriter {}

    function _isCsv() {
        if (format === "csv") return true
        if (format === "record") return false
        return destination.toLowerCase().endsWith(".csv")
    }

    // "labs/sensor-fusion-101/records/open-sky-42.labrec" -> "sensor-fusion-101".
    // A guess, and only a fallback: a lab that cares sets `lab` explicitly.
    function _labId() {
        if (lab !== "") return lab
        const parts = destination.split("/")
        for (let i = parts.length - 1; i > 0; --i)
            if (parts[i] === "records") return parts[i - 1]
        return ""
    }

    function _id() {
        if (recordId !== "") return recordId
        const base = destination.split("/").pop()
        const dot = base.lastIndexOf(".")
        return dot > 0 ? base.substring(0, dot) : base
    }

    function _paramList() {
        const out = []
        for (const n of Lab.paramNames) {
            const p = Lab.parameter(n)
            if (p) out.push({ name: n, value: p.value, unit: p.unit })
        }
        return out
    }

    function _probeList() {
        const out = []
        for (const n of _names) {
            const p = Lab.probe(n)
            out.push({ name: n, unit: p ? p.unit : "" })
        }
        return out
    }

    function _write() {
        error = ""
        if (_csv) { _writer.finish(); lastFile = destination; written(destination, rows); return }
        if (command === "")
            console.warn("DataRecorder: no command set - " + destination
                         + " will not say how to regenerate it")
        const text = Record.serialize(record(), { maxBytes: maxBytes })
        if (!_text.write(destination, text)) {
            error = _text.error
            console.warn("DataRecorder: " + error)
            return
        }
        lastFile = destination
        written(destination, rows)
    }

    onRecordingChanged: {
        if (recording) {
            _names = probes.length ? probes.slice() : Lab.probeNames.slice()
            rows = 0
            _rows = []
            _csv = _isCsv()
            if (_csv) {
                _writer.destination = destination
                _writer.begin(["t"].concat(_names))
            }
        } else {
            _write()
        }
    }

    property Connections _conn: Connections {
        target: Lab
        enabled: _rec.recording
        function onSampled(t) {
            // A probe only keeps FINITE samples, so "did this probe sample at
            // this tick?" is "is its newest sample this tick?". Reading
            // probe.value instead would repeat the last reading through a
            // dropout and invent measurements nobody made - which is exactly
            // what the sensor labs are about.
            const row = [t]
            const csvRow = _rec._csv ? [t.toFixed(4)] : null
            for (const n of _rec._names) {
                const pr = Lab.probe(n)
                const s = pr ? pr.samples : null
                const fresh = s && s.length > 0 && s[s.length - 1].t === t
                const v = fresh ? s[s.length - 1].v : NaN
                row.push(v)
                if (csvRow) csvRow.push(fresh ? String(v) : "")
            }
            if (csvRow) _rec._writer.appendRow(csvRow)
            else _rec._rows.push(row)
            _rec.rows++
        }
    }
}
