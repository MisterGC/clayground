// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype SelectionFrame3D
    \inqmlmodule Clayground.Lab
    \brief The shared hover/select language: a flat frame on the work surface.

    One shape, two strengths - hovering draws a thin quiet outline, selecting
    draws the full one plus a nose mark showing which way the object faces
    after a rotation. Small, and it is exactly the sort of thing that makes
    two different labs feel like one framework rather than two programs that
    happen to share a palette.

    Flat bars on the surface rather than a box around the object: the frame
    then reads at any camera angle, never hides the object it marks, and
    cannot fight the object's own silhouette.

    Put it inside the object's Node so it inherits position and rotation.

    \qml
    import Clayground.Lab

    Node {
        SelectionFrame3D {
            halfWidth: 5.2; halfDepth: 3.9
            selected: root.selected
            hovered: root.hovered
        }
    }
    \endqml

    \sa LabTheme, WorldLabel
*/
Node {
    id: root

    /*! \qmlproperty bool SelectionFrame3D::selected \brief Full frame plus nose mark. */
    property bool selected: false

    /*! \qmlproperty bool SelectionFrame3D::hovered \brief Thin, quiet outline. */
    property bool hovered: false

    /*! \qmlproperty real SelectionFrame3D::halfWidth \brief Half extent along x. */
    property real halfWidth: 5.0

    /*! \qmlproperty real SelectionFrame3D::halfDepth \brief Half extent along z. */
    property real halfDepth: 4.0

    /*! \qmlproperty color SelectionFrame3D::tone \brief Frame colour (the interactive blue). */
    property color tone: LabTheme.secondary

    /*! \qmlproperty color SelectionFrame3D::noseColor \brief Colour of the facing mark. */
    property color noseColor: LabTheme.accent

    /*! \qmlproperty bool SelectionFrame3D::showNose \brief Draw the facing mark when selected. */
    property bool showNose: true

    /*! \qmlproperty real SelectionFrame3D::height \brief Height above the surface. */
    property real height: 0.14

    /*! \qmlproperty real SelectionFrame3D::thickness \brief Bar thickness when selected. */
    property real thickness: 0.38

    visible: selected || hovered
    y: height
    opacity: selected ? 1.0 : 0.55

    readonly property real _bar: selected ? thickness : thickness * 0.58

    Repeater3D {
        model: [{ along: true, s: -1 }, { along: true, s: 1 },
                { along: false, s: -1 }, { along: false, s: 1 }]
        Model {
            required property var modelData
            source: "#Cube"
            castsShadows: false
            position: modelData.along
                ? Qt.vector3d(0, 0, modelData.s * root.halfDepth)
                : Qt.vector3d(modelData.s * root.halfWidth, 0, 0)
            scale: modelData.along
                ? Qt.vector3d((root.halfWidth * 2) / 100, 0.0014, root._bar / 100)
                : Qt.vector3d(root._bar / 100, 0.0014, (root.halfDepth * 2) / 100)
            materials: PrincipledMaterial {
                baseColor: root.tone
                lighting: PrincipledMaterial.NoLighting
            }
        }
    }

    Model {   // nose mark: which way the object faces after a rotation
        visible: root.selected && root.showNose
        source: "#Cube"
        castsShadows: false
        position: Qt.vector3d(root.halfWidth + 1.0, 0, 0)
        scale: Qt.vector3d(0.013, 0.0014, 0.013)
        eulerRotation.y: 45
        materials: PrincipledMaterial {
            baseColor: root.noseColor
            lighting: PrincipledMaterial.NoLighting
        }
    }
}
