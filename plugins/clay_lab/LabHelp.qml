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
            spacing: 10
            Rectangle {
                width: 62; height: 19; radius: 4
                color: LabTheme.paperDeep
                border.color: LabTheme.panelEdge; border.width: 1
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: modelData.key
                    color: LabTheme.ink; font.pixelSize: 11; font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 190
                elide: Text.ElideRight
                text: LabLang.t(modelData.label)
                color: LabTheme.inkSoft; font.pixelSize: 13
                font.family: LabTheme.handFont
            }
        }
    }
}
