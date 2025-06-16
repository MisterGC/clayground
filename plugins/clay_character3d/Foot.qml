import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _foot
    // Character this foot belongs to
    required property var character
    // if true it's the left foot, the right foot otherwise
    property bool left: true
    color: character.feetColor
    width: character.footLength * 0.5;
    depth: character.footLength
    height: depth * 0.3
    scaledFace: Box3DGeometry.FrontFace
    faceScale: Qt.vector2d(1.3, 1.0)

    basePos:  Qt.vector3d((_foot.left ? 1 : -1) * 0.5 * (character.hipWidth - _foot.width),
                          -(character.legLength),
                          character.footLength * .4)
}