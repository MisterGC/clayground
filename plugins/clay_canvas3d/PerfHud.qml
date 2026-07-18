// (c) Clayground Contributors - MIT License, see "LICENSE" file
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D.Helpers

/*!
    \qmltype PerfHud
    \inqmlmodule Clayground.Canvas3D
    \brief Compact always-on-top performance overlay for a View3D.

    PerfHud is a plain QtQuick \l Item (not a 3D node) that you parent into
    your scene's 2D overlay layer. It reads live rendering metrics from the
    \c renderStats of the referenced \l View3D and shows them in a small dark
    translucent panel using the Clayground palette.

    Metrics shown: frames per second, frame time, CPU sync/prepare/render
    times, GPU time, draw calls and drawn vertices. Draw-call and vertex
    counts require extended data collection, which PerfHud enables
    automatically on the target's \c renderStats.

    Example usage:
    \qml
    import QtQuick
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        id: view
        anchors.fill: parent

        PerfHud {
            view3D: view
            extended: false
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12
        }
    }
    \endqml

    \sa BenchLogger
*/
Item {
    id: root

    /*!
        \qmlproperty var PerfHud::view3D
        \brief The View3D whose renderStats are displayed. Required.
    */
    property var view3D: null

    /*!
        \qmlproperty bool PerfHud::extended
        \brief When true, additionally shows Qt's DebugView with resource
        details next to the compact panel.
    */
    property bool extended: false

    // Convenience handle to the live render statistics object.
    readonly property var stats: view3D ? view3D.renderStats : null

    // Enable draw-call / vertex counting as soon as a target is known.
    onStatsChanged: if (stats) stats.extendedDataCollectionEnabled = true
    Component.onCompleted: if (stats) stats.extendedDataCollectionEnabled = true

    implicitWidth: panel.width
    implicitHeight: panel.height

    // Clayground palette accents.
    readonly property color clayCyan: "#00d9ff"
    readonly property color clayTeal: "#0f9d9a"
    readonly property color clayPink: "#ff3366"
    readonly property color clayGold: "#ffd93d"
    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                                       Qt.platform.os === "windows" ? "Consolas" : "monospace"

    function fmt(v, digits) {
        return (v === undefined || v === null || isNaN(v)) ? "-" : Number(v).toFixed(digits)
    }

    Rectangle {
        id: panel
        width: grid.width + 20
        height: col.height + 16
        color: Qt.rgba(0.05, 0.06, 0.10, 0.82)
        border.color: root.clayTeal
        border.width: 1
        radius: 6

        Column {
            id: col
            x: 10
            y: 8
            spacing: 4

            Text {
                text: "PERF"
                font.family: root.monoFont
                font.pixelSize: 11
                font.bold: true
                color: root.clayCyan
            }

            Grid {
                id: grid
                columns: 2
                columnSpacing: 12
                rowSpacing: 2
                verticalItemAlignment: Grid.AlignVCenter

                component Label: Text {
                    font.family: root.monoFont
                    font.pixelSize: 11
                    color: "#9fb0c0"
                }
                component Value: Text {
                    font.family: root.monoFont
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignRight
                    width: 62
                }

                Label { text: "fps" }
                Value { text: root.stats ? root.stats.fps : "-"; color: root.clayGold; font.bold: true }

                Label { text: "frame ms" }
                Value { text: root.fmt(root.stats ? root.stats.frameTime : NaN, 2); color: "#eaeaea" }

                Label { text: "sync ms" }
                Value { text: root.fmt(root.stats ? root.stats.syncTime : NaN, 2); color: "#eaeaea" }

                Label { text: "prep ms" }
                Value { text: root.fmt(root.stats ? root.stats.renderPrepareTime : NaN, 2); color: "#eaeaea" }

                Label { text: "render ms" }
                Value { text: root.fmt(root.stats ? root.stats.renderTime : NaN, 2); color: "#eaeaea" }

                Label { text: "gpu ms" }
                Value { text: root.fmt(root.stats ? root.stats.lastCompletedGpuTime : NaN, 2); color: root.clayPink; font.bold: true }

                Label { text: "draws" }
                Value { text: root.stats ? root.stats.drawCallCount : "-"; color: root.clayCyan }

                Label { text: "verts" }
                Value { text: root.stats ? root.stats.drawVertexCount : "-"; color: root.clayCyan }
            }
        }
    }

    // Qt's built-in resource inspector, only when extended details are wanted.
    DebugView {
        id: debugView
        visible: root.extended && root.view3D !== null
        source: root.view3D
        resourceDetailsVisible: true
        anchors.top: panel.top
        anchors.right: panel.left
        anchors.rightMargin: 8
    }
}
