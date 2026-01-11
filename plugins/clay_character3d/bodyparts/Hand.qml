import QtQuick
import Clayground.Canvas3D

/*!
    \qmltype Hand
    \inqmlmodule Clayground.Character3D
    \inherits BodyPart
    \brief A hand body part with tapered shape.

    Hand is a specialized BodyPart that represents a character's hand.
    It uses face scaling to create a tapered shape that narrows toward
    the fingers.

    Hands are typically created automatically as part of an Arm, but can
    be customized through the Arm's hand properties.

    \sa Arm, BodyPart
*/
BodyPart {
    id: _hand

    // Default color that can be overridden
    color: "#d38d5f"

    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(0.7, 0.7)
}
