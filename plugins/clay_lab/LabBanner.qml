// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype LabBanner
    \inqmlmodule Clayground.Lab
    \brief The centred status pill: something is wrong, or something just happened.

    Top centre, above everything, and normally invisible. Two labs had one -
    electronics for a short circuit, street-network for gridlock - and both had
    independently worked out the same three rules, which is why it is here:

    \list
    \li the fill carries the severity (\l alarm red versus the gold of a
        warning) and the ink comes from the fill via \c inkOn(), never pinned;
    \li a real fault \l blink{blinks}, a note does not - a banner that always
        pulses stops meaning anything;
    \li the width is capped against the panels beside it and the text elides,
        because a German banner runs about a quarter longer than the English
        one and a banner that slides under the palette is worse than no banner.
    \endlist

    \qml
    LabBanner {
        active: sim.shorted || sim.overloaded
        alarm: sim.shorted
        blink: sim.shorted
        guard: palette
        text: LabLang.t(sim.shorted ? "banner.short" : "banner.heavy")
    }
    \endqml

    \sa HintBar, Narrator
*/
Rectangle {
    id: root

    /*!
        \qmlproperty string LabBanner::text
        \brief The message (already translated).
    */
    property string text: ""

    /*!
        \qmlproperty bool LabBanner::active
        \brief Show it.
    */
    property bool active: false

    /*!
        \qmlproperty bool LabBanner::alarm
        \brief Fault colouring rather than a warning's gold.
    */
    property bool alarm: false

    /*!
        \qmlproperty bool LabBanner::blink
        \brief Pulse - reserve it for a live fault.
    */
    property bool blink: false

    /*!
        \qmlproperty color LabBanner::fill
        \brief Override the severity colour outright.
    */
    property color fill: alarm ? LabTheme.alarm : LabTheme.highlight

    /*!
        \qmlproperty Item LabBanner::guard
        \brief A panel on either side the banner may not grow into.

        Usually the lab's palette or parameter panel. The cap is symmetric,
        because the banner is centred.
    */
    property Item guard: null

    /*!
        \qmlproperty real LabBanner::maxWidth
        \brief Hard cap, whatever the guard allows.
    */
    property real maxWidth: LabTheme.px(360)

    /*!
        \qmlproperty real LabBanner::topMargin
        \brief Distance from the top edge.
    */
    property real topMargin: LabTheme.spaceXxl

    visible: active && text !== ""
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    y: topMargin
    width: {
        let w = Math.min(maxWidth, _label.implicitWidth + 2 * LabTheme.spaceXxl)
        if (guard && parent)
            w = Math.min(w, Math.max(LabTheme.px(80),
                                     parent.width - 2 * (guard.width + LabTheme.px(40))))
        return w
    }
    height: LabTheme.px(34)
    radius: LabTheme.radius
    color: fill

    Text {
        id: _label
        anchors.centerIn: parent
        width: parent.width - 2 * LabTheme.spaceXl
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        text: root.text
        // the fill changes with the severity, so the ink follows the fill
        color: LabTheme.inkOn(root.color)
        font.pixelSize: LabTheme.fontLabel
        font.bold: true
        font.family: LabTheme.monoFont
    }

    SequentialAnimation on opacity {
        running: root.blink && root.visible
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 0.55; duration: 300 }
        NumberAnimation { to: 1.0; duration: 300 }
    }
}
