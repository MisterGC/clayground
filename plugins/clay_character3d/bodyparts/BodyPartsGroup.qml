import QtQuick
import Clayground.Canvas3D
import QtQuick3D.Helpers

/*!
    \qmltype BodyPartsGroup
    \inqmlmodule Clayground.Character3D
    \inherits BodyPart
    \brief Groups multiple body parts together as an invisible container.

    BodyPartsGroup extends BodyPart but renders no geometry, serving purely
    as a grouping container. It provides the same interface as BodyPart
    (position, rotation, dimensions) while remaining invisible.

    This is useful for creating hierarchical body part structures where a
    parent group controls multiple child parts. For example, an arm group
    containing upper arm, lower arm, and hand.

    Example usage:
    \qml
    import Clayground.Character3D

    BodyPartsGroup {
        id: armGroup
        basePos: Qt.vector3d(1.5, 3, 0)

        BodyPart {
            id: upperArm
            height: 1.5
            basePos: Qt.vector3d(0, -height, 0)
        }

        BodyPart {
            id: lowerArm
            height: 1.2
            basePos: Qt.vector3d(0, -upperArm.height - height, 0)
        }
    }
    \endqml

    \sa BodyPart, Character
*/
BodyPart {
    // No visible geometry and material as this is only for grouping
    geometry: ProceduralMesh {}
    materials: []
}