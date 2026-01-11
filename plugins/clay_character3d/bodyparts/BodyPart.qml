import QtQuick
import Clayground.Canvas3D

/*!
    \qmltype BodyPart
    \inqmlmodule Clayground.Character3D
    \inherits Box3D
    \brief Base component for character body parts.

    BodyPart provides the foundation for all character body part components,
    extending Box3D with default styling and positioning properties.

    It sets sensible defaults for character rendering: edges are shown with
    moderate thickness, shadows are cast, and parts are pickable for interaction.

    Example usage:
    \qml
    import Clayground.Character3D

    BodyPart {
        width: 1.0
        height: 2.0
        depth: 0.5
        color: "#4169e1"
        basePos: Qt.vector3d(0, 1, 0)
    }
    \endqml

    \sa BodyPartsGroup, Box3D
*/
Box3D {
    /*!
        \qmlproperty vector3d BodyPart::basePos
        \brief The base position of the body part.

        Used as the reference position for animations. The actual position
        property is bound to this value, allowing animations to modify
        position while preserving the original base position.
    */
    property vector3d basePos: Qt.vector3d(0,0,0)

    /*!
        \qmlproperty vector3d BodyPart::baseEuler
        \brief The base rotation of the body part in Euler angles.

        Used as the reference rotation for animations. The actual eulerRotation
        property is bound to this value, allowing animations to modify
        rotation while preserving the original base orientation.
    */
    property vector3d baseEuler: Qt.vector3d(0,0,0)

    position: basePos
    eulerRotation: baseEuler
    showEdges: true
    edgeThickness: 7
    edgeColorFactor: 0.4
    castsShadows: true
    pickable: true
}