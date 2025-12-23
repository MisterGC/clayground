import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _foot
    // Character this foot belongs to
    // Default color that can be overridden
    color: "#d38d5f"
    
    scaledFace: Box3DGeometry.FrontFace
    faceScale: Qt.vector2d(1.3, 1.0)
}
