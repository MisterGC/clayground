import QtQuick
import Clayground.Canvas3D

BodyPart {
    id: _hand
    // Character this foot belongs to
    required property var character
    // if true it's the left foot, the right foot otherwise
    property bool left: true
    color: character.handsColor
    width: _character.handLength * 0.3;
    height: _character.handLength;
    depth: _character.handLength * 0.5;
    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(0.7, 0.7)

    basePos: Qt.vector3d((_hand.left ? 1 : -1) * ((_character.shoulderWidth + width) * .5),
                          (_character.torsoHeight - _character.armLength - height),
                          0)
}