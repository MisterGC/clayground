import QtQuick
import Clayground.Canvas3D

/*!
    \qmltype Foot
    \inqmlmodule Clayground.Character3D
    \inherits BodyPart
    \brief A foot body part with extended toe shape.

    Foot is a specialized BodyPart that represents a character's foot.
    It uses face scaling to create an extended front (toe area) that
    gives the foot a natural shoe-like shape.

    Feet are typically created automatically as part of a Leg, but can
    be customized through the Leg's foot properties.

    \sa Leg, BodyPart
*/
BodyPart {
    id: _foot

    // Default color that can be overridden
    color: "#d38d5f"

    scaledFace: Box3DGeometry.FrontFace
    faceScale: Qt.vector2d(1.3, 1.0)
}
