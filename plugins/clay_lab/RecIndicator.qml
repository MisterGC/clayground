// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype RecIndicator
    \inqmlmodule Clayground.Lab
    \brief The recording dot: this run is being written to a file.

    \c Shift+R starts a \l DataRecorder and nothing on screen said so, which is
    how a lab ends up with a CSV nobody knew was growing. A dot, the word, and
    the row count - the row count because it is the one number that proves
    samples really are arriving.

    Invisible unless the recorder is running.

    \qml
    RecIndicator {
        recorder: recorder
        anchors.left: parent.left; anchors.bottom: plot.top
        anchors.margins: LabTheme.spaceXl
    }
    \endqml

    \sa DataRecorder, LabKeys
*/
Row {
    id: root

    /*!
        \qmlproperty var RecIndicator::recorder
        \brief The DataRecorder to watch.
    */
    property var recorder: null

    /*!
        \qmlproperty bool RecIndicator::showRows
        \brief Append the row count.
    */
    property bool showRows: true

    /*!
        \qmlproperty color RecIndicator::tone
        \brief Dot and text colour.
    */
    property color tone: LabTheme.alarm

    visible: recorder !== null && recorder !== undefined && recorder.recording
    spacing: LabTheme.spaceM

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: LabTheme.px(9); height: width
        radius: width / 2
        color: root.tone
        SequentialAnimation on opacity {
            running: root.visible
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 0.3; duration: 520 }
            NumberAnimation { to: 1.0; duration: 520 }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: LabLang.t("rec.label")
              + (root.showRows && root.recorder ? " (" + root.recorder.rows + ")" : "")
        color: root.tone
        font.pixelSize: LabTheme.fontBody; font.bold: true
        font.family: LabTheme.monoFont
    }
}
