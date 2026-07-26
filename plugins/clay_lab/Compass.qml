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
    id: root

    /*! \qmlproperty real Compass::yaw \brief Camera yaw in degrees (the rig's). */
    property real yaw: 0

    /*! \qmlproperty real Compass::aspect \brief Width/height of the surface shown. */
    property real aspect: 1.55

    /*! \qmlproperty color Compass::frontColor \brief Marker on the surface's front edge. */
    property color frontColor: LabTheme.accent

    width: 68; height: 68
    radius: width / 2
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth

    Rectangle {   // the surface, seen from above, turning with the view
        anchors.centerIn: parent
        width: Math.round(root.width * 0.58)
        height: Math.round(width / root.aspect)
        radius: 3
        color: LabTheme.paperDeep
        border.color: LabTheme.ink
        border.width: 1.5
        rotation: -root.yaw

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.round(parent.width * 0.35)
            height: 3
            color: root.frontColor
        }
    }

    Rectangle {   // you: fixed at the bottom, the surface turns instead
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        width: 8; height: 8; radius: 4
        color: LabTheme.secondary
    }
}
