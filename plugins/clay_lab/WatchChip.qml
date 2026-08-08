// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype WatchChip
    \inqmlmodule Clayground.Lab
    \brief Put this thing on the plot - the watch toggle, in three states.

    Belongs on a selection card, beside the per-object controls: monitoring is
    a per-object act, like selecting. Three states, and the third is the one
    labs kept getting wrong:

    \list
    \li \b watch - offered, in the interactive blue;
    \li \b watched - filled with the colour this object now wears on the plot,
        on the board and on its card, so the three agree at a glance;
    \li \b full - the monitor has no colour left (\l {WatchMonitor::maxSeries})
        and says so, rather than presenting a control that silently does
        nothing.
    \endlist

    Reads the limit off the monitor rather than taking its own copy - a lab
    that kept a second \c watchMax beside the monitor's had them disagree.

    \qml
    WatchChip { monitor: monitor; target: card.element.id }
    \endqml

    \sa WatchMonitor, WatchMark
*/
Rectangle {
    id: root

    /*! \qmlproperty var WatchChip::monitor \brief The WatchMonitor that owns the watch set. */
    property var monitor: null

    /*! \qmlproperty var WatchChip::target \brief The id to watch. */
    property var target: undefined

    /*! \qmlproperty bool WatchChip::watched \readonly \brief The target is on the plot. */
    readonly property bool watched: monitor !== null && target !== undefined
                                    && monitor.isWatched(target)

    /*! \qmlproperty bool WatchChip::full \readonly \brief No series left to give. */
    readonly property bool full: !watched && monitor !== null && monitor.isFull()

    /*!
        \qmlproperty var WatchChip::labels
        \brief Dictionary keys for the three states.

        Defaults to the kernel's \c watch.add / \c watch.on / \c watch.full;
        a lab with its own wording overrides them here.
    */
    property var labels: ({ add: "watch.add", on: "watch.on", full: "watch.full" })

    visible: monitor !== null && target !== undefined
    implicitWidth: _label.implicitWidth + 2 * LabTheme.spaceL
    implicitHeight: LabTheme.px(21)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: root.watched && root.monitor ? root.monitor.colorOf(root.target)
                                        : LabTheme.panel
    border.color: root.watched ? LabTheme.panelEdge
                : (root.full ? LabTheme.panelEdge : LabTheme.secondary)
    border.width: LabTheme.borderWidth

    Text {
        id: _label
        anchors.centerIn: parent
        text: LabLang.t(root.watched ? root.labels.on
                                     : (root.full ? root.labels.full : root.labels.add))
        // watched fills with the series colour, which is a data token and may
        // be light or dark in either theme - so the ink comes from the fill
        color: root.watched ? LabTheme.inkOn(root.color)
             : (root.full ? LabTheme.inkFaint : LabTheme.secondary)
        font.pixelSize: LabTheme.fontBody
        font.family: LabTheme.handFont
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.full
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.monitor && root.target !== undefined)
                       root.monitor.toggle(root.target)
    }
}
