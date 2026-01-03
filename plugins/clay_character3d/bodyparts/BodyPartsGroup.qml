import QtQuick
import Clayground.Canvas3D
import QtQuick3D.Helpers

/*!
    \qmltype BodyPartsGroup
    \inqmlmodule Clayground.Character3D
    \brief Groups multiple body parts together with shared interface.

    BodyPartsGroup allows grouping of body parts while providing the same
    interface as a body part (e.g. dimensions). Used internally by Character
    to organize body part hierarchies.
*/
BodyPart
{
    // No visible geo and material
    // as this is only for grouping
    geometry: ProceduralMesh{}
    materials: []
}