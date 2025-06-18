import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _hand
    
    // Character this hand belongs to
    required property var character
    // if true it's the left hand, the right hand otherwise
    property bool left: true
    
    // Default color that can be overridden
    color: "#d38d5f"
    
    // Dimensions with default bindings that can be overridden
    width: character.handLength * 0.3
    height: character.handLength
    depth: character.handLength * 0.5
    
    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(0.7, 0.7)
}
