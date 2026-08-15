// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype WatchMark
    \inqmlmodule Clayground.Lab
    \brief The dot a watched object wears in the world, in its curve's colour.

    The other half of the watch loop: \l WatchChip puts a thing on the plot,
    this is how you find it again on the board. Colour carries information
    across surfaces - a watched part wears its curve's colour on the object
    \e and in the legend - and this is the object end of that rule.

    A QtQuick item, so it lives beside the View3D rather than in it; position
    it from a projected point, or hand it to a \l WorldLabel.

    \qml
    WatchMark {
        monitor: monitor
        target: element.id
        label: root.labelOf(element.id)
        x: screenAt.x - width / 2; y: screenAt.y
        visible: screenAt.z > 0
    }
    \endqml

    \sa WatchChip, WatchMonitor, WorldLabel
*/
Row {
    id: root

    /*!
        \qmlproperty var WatchMark::monitor
        \brief The WatchMonitor supplying the colour.
    */
    property var monitor: null

    /*!
        \qmlproperty var WatchMark::target
        \brief The watched id.
    */
    property var target: undefined

    /*!
        \qmlproperty string WatchMark::label
        \brief Text beside the dot; empty draws the dot alone.
    */
    property string label: ""

    /*!
        \qmlproperty color WatchMark::tone
        \readonly
        \brief The target's series colour.
    */
    readonly property color tone: monitor && target !== undefined
                                  ? monitor.colorOf(target) : LabTheme.inkFaint

    /*!
        \qmlproperty bool WatchMark::onlyWhenWatched
        \brief Hide unless the target is actually on the plot (the default).
    */
    property bool onlyWhenWatched: true

    visible: monitor !== null && target !== undefined
             && (!onlyWhenWatched || monitor.isWatched(target))
    spacing: LabTheme.spaceM

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: LabTheme.px(11); height: width
        radius: width / 2
        color: root.tone
        border.color: LabTheme.panel
        border.width: Math.max(1, LabTheme.px(1.5))
    }

    Rectangle {
        visible: root.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        width: _text.implicitWidth + LabTheme.spaceL
        height: _text.implicitHeight + LabTheme.spaceS
        radius: LabTheme.px(4)
        color: LabTheme.panel
        border.color: root.tone
        border.width: Math.max(1, LabTheme.px(1.5))
        opacity: 0.95
        Text {
            id: _text
            anchors.centerIn: parent
            text: root.label
            color: LabTheme.ink
            font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.family: LabTheme.monoFont
        }
    }
}
