// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype SceneTitle
    \inqmlmodule Clayground.Lab
    \brief A title card over the whole picture: fades in, holds, fades out.

    What an establishing shot is captioned with - "AND gate" over the new
    board - and deliberately not a status pill: a scene change is the one
    moment the lesson may take the whole frame, so the type is large, sits
    in the middle of the picture, and a light wash under it lets it read
    over anything while the new layout stays visible behind it.

    Bind \l text to \c {CameraDirector.title}; the card appears while the
    text is non-empty and fades out when it clears, keeping the last title
    for the length of the fade so a card never blanks mid-fade.

    \qml
    SceneTitle { anchors.fill: parent; text: director.title }
    \endqml

    \sa CameraDirector, LabBanner
*/
Item {
    id: root

    /*! \qmlproperty string SceneTitle::text \brief The title; "" hides the card. */
    property string text: ""

    /*! \qmlproperty int SceneTitle::fadeMs \brief Fade in and out, in ms. */
    property int fadeMs: 380

    /*!
        \qmlproperty real SceneTitle::wash
        \brief How much the picture is calmed under the type, 0..1.
    */
    property real wash: 0.32

    /*!
        \qmlproperty real SceneTitle::at
        \brief Where the title sits, as a fraction of the height from the top.

        The lower third by default - television's place for a title, and
        the part of an establishing shot that is ground rather than setup,
        so the card names the scene without sitting on it.
    */
    property real at: 0.66

    // The last non-empty title, so the fade-out still shows a word.
    property string _label: ""
    onTextChanged: if (text !== "") _label = text

    visible: opacity > 0.001
    opacity: text !== "" ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: root.fadeMs; easing.type: Easing.InOutQuad } }

    Rectangle {
        anchors.fill: parent
        color: LabTheme.paper
        opacity: root.wash
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * root.at - height / 2
        spacing: LabTheme.px(10)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root._label
            color: LabTheme.ink
            font.pixelSize: Math.round(LabTheme.fontTitle * 2.6)
            font.family: LabTheme.handFont
            font.bold: true
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: LabTheme.px(72); height: Math.max(2, LabTheme.px(3))
            radius: height / 2
            color: LabTheme.secondary
        }
    }
}
