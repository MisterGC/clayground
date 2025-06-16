import QtQuick
import Clayground.Canvas3D
import QtQuick3D.Helpers

/** 
 * Allows grouping of body parts and providing the same
 * interface as as body part (e.g. dimensions)
**/
BodyPart
{
    // No visible geo and material
    // as this is only for grouping
    geometry: ProceduralMesh{}
    materials: []
}