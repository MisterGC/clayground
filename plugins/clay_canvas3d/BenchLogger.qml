// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Canvas3D

/*!
    \qmltype BenchLogger
    \inqmlmodule Clayground.Canvas3D
    \brief Samples a View3D's renderStats at a fixed interval and writes them
    to a CSV file.

    BenchLogger is a non-visual helper for automated performance benchmarks.
    While \l running is true it takes a sample every \l intervalMs milliseconds
    from the target \l View3D and appends one CSV row per sample through a small
    C++ file writer (QML cannot write files directly).

    The fixed columns are:
    \c t_ms, \c fps, \c frame_ms, \c sync_ms, \c prepare_ms, \c render_ms,
    \c gpu_ms, \c draw_calls, \c draw_vertices. One extra column is appended for
    every key in \l extra, followed by a final \c note column.

    The file is flushed after every sample and closed when logging stops or the
    component is destroyed, so partial runs still yield valid data.

    Example usage:
    \qml
    import QtQuick
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view
        anchors.fill: parent

        BenchLogger {
            id: bench
            view3D: view
            outputPath: "/tmp/bench.csv"
            intervalMs: 250
            extra: ({ "boxes": function() { return spawner.count } })
            running: true
            onSampleTaken: console.log("sample written")
        }
    }
    \endqml

    \sa PerfHud
*/
Item {
    id: root

    /*!
        \qmlproperty var BenchLogger::view3D
        \brief The View3D whose renderStats are sampled. Required.
    */
    property var view3D: null

    /*!
        \qmlproperty string BenchLogger::outputPath
        \brief Destination CSV file path (plain path or file:// URL).
    */
    property string outputPath: ""

    /*!
        \qmlproperty int BenchLogger::intervalMs
        \brief Sampling interval in milliseconds.
    */
    property int intervalMs: 250

    /*!
        \qmlproperty bool BenchLogger::running
        \brief Set true to open the file and start sampling, false to flush,
        close and stop.
    */
    property bool running: false

    /*!
        \qmlproperty var BenchLogger::extra
        \brief Map of extra column name to value or zero-argument function. Each
        entry adds one CSV column; functions are evaluated per sample. The key
        set is captured when logging starts.
    */
    property var extra: ({})

    /*!
        \qmlsignal BenchLogger::sampleTaken()
        \brief Emitted after a sample row has been written.
    */
    signal sampleTaken()

    // Live render statistics of the target view.
    readonly property var stats: view3D ? view3D.renderStats : null

    /*!
        \qmlmethod void BenchLogger::annotate(string key, var value)
        \brief Adds a one-shot \c key=value note to the next sample's note
        column. Multiple notes before a sample are joined with ';'.
    */
    function annotate(key, value) {
        _pendingNote.push(key + "=" + value)
    }

    // --- internals ---------------------------------------------------------

    property var _extraKeys: []
    property var _pendingNote: []
    property double _startMs: 0

    BenchCsvWriter { id: writer }

    function _csvField(v) {
        var s = String(v)
        if (s.indexOf(",") !== -1 || s.indexOf("\"") !== -1 || s.indexOf("\n") !== -1)
            return "\"" + s.replace(/"/g, "\"\"") + "\""
        return s
    }

    function _num(v, digits) {
        return (v === undefined || v === null || isNaN(v)) ? "" : Number(v).toFixed(digits)
    }

    function _start() {
        if (!outputPath) {
            console.warn("BenchLogger: outputPath is empty, not starting")
            return
        }
        if (stats)
            stats.extendedDataCollectionEnabled = true
        _extraKeys = Object.keys(extra)
        if (!writer.open(outputPath)) {
            console.warn("BenchLogger: could not open " + outputPath)
            return
        }
        var header = ["t_ms", "fps", "frame_ms", "sync_ms", "prepare_ms",
                      "render_ms", "gpu_ms", "draw_calls", "draw_vertices"]
        for (var i = 0; i < _extraKeys.length; ++i)
            header.push(_extraKeys[i])
        header.push("note")
        writer.writeLine(header.join(","))
        writer.flush()
        _pendingNote = []
        _startMs = Date.now()
        timer.start()
    }

    function _stop() {
        timer.stop()
        writer.flush()
        writer.close()
    }

    function _sample() {
        if (!writer.isOpen())
            return
        var s = stats
        var t = Math.round(Date.now() - _startMs)
        var row = [
            t,
            s ? s.fps : "",
            _num(s ? s.frameTime : NaN, 3),
            _num(s ? s.syncTime : NaN, 3),
            _num(s ? s.renderPrepareTime : NaN, 3),
            _num(s ? s.renderTime : NaN, 3),
            _num(s ? s.lastCompletedGpuTime : NaN, 3),
            s ? s.drawCallCount : "",
            s ? s.drawVertexCount : ""
        ]
        for (var i = 0; i < _extraKeys.length; ++i) {
            var key = _extraKeys[i]
            var val = extra[key]
            if (typeof val === "function")
                val = val()
            row.push(_csvField(val))
        }
        var note = _pendingNote.join(";")
        _pendingNote = []
        row.push(_csvField(note))
        writer.writeLine(row.join(","))
        writer.flush()
        sampleTaken()
    }

    onRunningChanged: running ? _start() : _stop()

    Component.onDestruction: {
        if (writer.isOpen()) {
            writer.flush()
            writer.close()
        }
    }

    Timer {
        id: timer
        interval: root.intervalMs
        repeat: true
        onTriggered: root._sample()
    }
}
