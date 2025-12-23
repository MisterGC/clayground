import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _hand
    
    // Default color that can be overridden
    color: "#d38d5f"
    
    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(0.7, 0.7)
}
