import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _foot
    // Character this foot belongs to
    required property var character
    // if true it's the left foot, the right foot otherwise
    property bool left: true
    // Default color that can be overridden
    color: "#d38d5f"
    
    // Dimensions with default bindings that can be overridden
    width: character.footLength * 0.5
    depth: character.footLength
    height: depth * 0.3
    
    scaledFace: Box3DGeometry.FrontFace
    faceScale: Qt.vector2d(1.3, 1.0)
}