// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype HintBar
    \inqmlmodule Clayground.Lab
    \brief The bottom-centre line that says what you can do right now.

    Owns the slot rules that every lab got right by hand and would eventually
    get wrong: it steps aside while a flow narrates (the Narrator owns
    bottom-centre), and it is width-capped against whatever sits left and
    right of it, because a translated hint runs about a quarter longer than
    the English it replaced and must be clipped rather than overlap a panel.

    \qml
    HintBar {
        flow: introFlow
        rightGuard: plot                       // never grow into the monitor
        text: root.eraser ? LabLang.t("hint.eraser") : LabLang.t("hint.idle")
    }
    \endqml

    \sa Narrator, LabKeys
*/
Rectangle {
    id: root

    // There is one of these per lab, so it can carry a name every lab shares -
    // which is what lets a figure ask for "the hint bar" by name rather than
    // by a pixel rectangle that the next UI scale invalidates. A lab may still
    // override it. See clayrender --crop.
    objectName: "hint"

    /*!
        \qmlproperty string HintBar::text
        \brief The line to show; empty hides the bar.
    */
    property string text: ""

    /*!
        \qmlmethod void HintBar::flash(string message)
        \brief Shows \a message for a moment, then returns to \l text.

        The refusal channel: a key that cannot act right now says what is
        missing here ("no earlier view", "nothing selected") instead of
        doing nothing - and saying it must not disturb whatever the lab's
        own hint binding currently reads, which is why this is a transient
        overlay rather than a text write.
    */
    function flash(message) {
        _flash = message
        _flashTimer.restart()
    }

    property string _flash: ""
    Timer { id: _flashTimer; interval: 1800; onTriggered: root._flash = "" }

    /*!
        \qmlproperty var HintBar::flow
        \brief Hidden while this Flow runs.
    */
    property var flow: null

    /*!
        \qmlproperty Item HintBar::rightGuard
        \brief Panel on the right the bar may not grow into (usually the monitor).
    */
    property Item rightGuard: null

    /*!
        \qmlproperty Item HintBar::leftGuard
        \brief Panel on the left the bar may not grow into.
    */
    property Item leftGuard: null

    /*!
        \qmlproperty int HintBar::margin
        \brief Gap kept to the guards.
    */
    property int margin: LabTheme.spaceL

    // The bar is centred, so its half-width is bounded by the NEARER guard:
    // capping against the text it sizes would be a binding loop, and capping
    // against the window would let a long translation slide under a panel.
    readonly property real _limit: {
        const centre = parent ? parent.width / 2 : 0
        let half = centre - margin
        if (rightGuard) half = Math.min(half, rightGuard.x - margin - centre)
        if (leftGuard)
            half = Math.min(half, centre - (leftGuard.x + leftGuard.width + margin))
        return Math.max(LabTheme.px(60), 2 * half)
    }

    anchors.bottom: parent ? parent.bottom : undefined
    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.bottomMargin: LabTheme.spaceL

    // Focus mode takes it too: a line telling you what you could click is
    // chrome about interaction, and focus mode is for when you are not
    // interacting. The alarm banner is deliberately NOT treated this way -
    // a short circuit outranks whatever you were trying to look at.
    visible: (text !== "" || _flash !== "") && !(flow && flow.running) && !LabView.focus
    width: _hint.width + LabTheme.px(30)
    height: LabTheme.px(26)
    radius: LabTheme.px(6)
    color: LabTheme.panel

    Text {
        id: _hint
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root._limit - LabTheme.px(30))
        elide: Text.ElideRight
        text: root._flash !== "" ? root._flash : root.text
        // a flash outranks the standing hint in ink too: it is an answer to
        // the key just pressed, not ambient guidance
        color: root._flash !== "" ? LabTheme.ink : LabTheme.inkSoft
        font.pixelSize: LabTheme.fontLead
        font.family: LabTheme.handFont
    }
}
