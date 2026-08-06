// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype LabHelp
    \inqmlmodule Clayground.Lab
    \brief The key map, on screen, generated from a LabKeys.

    Toggled by \c ? (LabKeys owns the key). Because it reads
    \l {LabKeys::entries}{entries}, a lab that declares a key has documented
    it - the list can never drift from what the lab actually does.

    \qml
    LabHelp { keymap: keymap; anchors.centerIn: parent }
    \endqml

    \sa LabKeys
*/
LabPanel {
    id: root

    /*! \qmlproperty var LabHelp::keymap \brief The LabKeys to describe. */
    property var keymap: null

    title: LabLang.t("keys.title")
    tag: "?"
    visible: keymap !== null && keymap.helpVisible
    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Repeater {
        model: root.keymap ? root.keymap.entries : []
        Row {
            spacing: LabTheme.spaceL
            Rectangle {
                width: LabTheme.px(62); height: LabTheme.px(19)
                radius: LabTheme.px(4)
                color: LabTheme.paperDeep
                border.color: LabTheme.panelEdge; border.width: 1
                Text {
                    anchors.centerIn: parent
                    width: parent.width - LabTheme.spaceM
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.key
                    color: LabTheme.ink
                    font.pixelSize: LabTheme.fontSmall; font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: LabTheme.px(190)
                elide: Text.ElideRight
                text: LabLang.t(modelData.label)
                color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontLabel
                font.family: LabTheme.handFont
            }
        }
    }
}
