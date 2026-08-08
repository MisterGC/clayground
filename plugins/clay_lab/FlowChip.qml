// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype FlowChip
    \inqmlmodule Clayground.Lab
    \brief The offer to be taught: starts a Flow, and says that it exists.

    A lab's guided flow used to be reachable only by pressing \c T, which
    appeared in no hint and no panel - the best thing the lab had to offer was
    the one thing a learner could not find. This is that offer, on screen,
    from the first frame.

    Shows the flow's title while it is idle and disappears while it runs (the
    Narrator has the floor then).

    \qml
    FlowChip { flow: introFlow }
    \endqml

    \sa Flow, Narrator, LabKeys
*/
Rectangle {
    id: root

    /*! \qmlproperty var FlowChip::flow \brief The Flow to offer. */
    property var flow: null

    /*! \qmlproperty string FlowChip::label \brief Text; defaults to the flow's title. */
    property string label: flow && flow.title !== "" ? flow.title
                                                     : LabLang.t("flow.start")

    visible: flow !== null && !flow.running
    implicitWidth: _row.width + LabTheme.px(20)
    implicitHeight: LabTheme.px(32)
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: _hover.hovered ? LabTheme.highlight : LabTheme.paper
    border.color: LabTheme.highlight
    border.width: LabTheme.borderWidth

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: LabTheme.px(7)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "▶"
            color: LabTheme.accent
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.parent
                            ? root.parent.width - LabTheme.px(70) : LabTheme.px(200))
            elide: Text.ElideRight
            text: root.label
            // the chip fills with gold on hover, so the ink follows the fill
            color: LabTheme.inkOn(root.color)
            font.pixelSize: LabTheme.fontLabel
            font.family: LabTheme.handFont
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "(T)"
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    HoverHandler { id: _hover }
    TapHandler { onTapped: if (root.flow) root.flow.start() }
}
