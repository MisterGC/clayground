// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Compass
    \inqmlmodule Clayground.Lab
    \brief Which way the work surface faces while you circle it.

    You stay at the bottom and the board turns, which is what actually
    happens when an orbit camera swings around a fixed scene. Orientation is
    half the value of a 3D lab: without it a learner who has orbited 180
    degrees reads "left" for "right" on every instruction.

    \qml
    Compass { yaw: rig.yaw; x: 12; y: palette.y + palette.height + 10 }
    \endqml

    \sa OrbitCamera3D
*/
Rectangle {

    // Which way the board faces is orientation, not scene. Focus mode takes it with the
    // rest of the HUD - see LabView::focus.
    visible: !LabView.focus
    id: root

    /*!
        \qmlproperty real Compass::yaw
        \brief Camera yaw in degrees (the rig's).
    */
    property real yaw: 0

    /*!
        \qmlproperty real Compass::aspect
        \brief Width/height of the surface shown.
    */
    property real aspect: 1.55

    /*!
        \qmlproperty color Compass::frontColor
        \brief Marker on the surface's front edge.
    */
    property color frontColor: LabTheme.accent

    width: LabTheme.px(68); height: width
    radius: width / 2
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    Rectangle {   // the surface, seen from above, turning with the view
        anchors.centerIn: parent
        width: Math.round(root.width * 0.58)
        height: Math.round(width / root.aspect)
        radius: LabTheme.px(3)
        color: LabTheme.paperDeep
        border.color: LabTheme.ink
        border.width: Math.max(1, LabTheme.px(1.5))
        rotation: -root.yaw

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.round(parent.width * 0.35)
            height: Math.max(1, LabTheme.px(3))
            color: root.frontColor
        }
    }

    Rectangle {   // you: fixed at the bottom, the surface turns instead
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.spaceS
        width: LabTheme.spaceL; height: width; radius: width / 2
        color: LabTheme.secondary
    }
}
