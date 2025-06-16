// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick
import "." // Import Character from the same directory

pragma ComponentBehavior: Bound

Character {
    id: ratioBasedCharacter

    // Propertion Relations - tune for specific
    // style e.g. comic, realistic  or male vs female
    // Head
    property real headsTall: 4.7
    property real headWidthToHeight: 0.9
    property real headDepthToHeadWidth: 0.8
    property real neckHeightToHeadHeight: 0.2
    // Torso
    property real shoulderWidthToHeadWidth: 1.8
    property real torsoHeightToHeadHeight: 2.0
    property real shoulderWidthToTorsoDepth: 0.3
    // Arms and Hands
    // Shoulder to beginning of hand
    property real armLengthToTorsoHeight: 1.0
    property real armLengthToHandLength: 3
    // Legs and Feet
    property real footLengthToBodyHeight: 0.15

    // Calculated dimensions based on ratios
    headHeight: height / headsTall
    headWidth: headHeight * headWidthToHeight
    headDepth: headWidth * headDepthToHeadWidth
    neckHeight: headHeight * neckHeightToHeadHeight
    shoulderWidth: headWidth * shoulderWidthToHeadWidth
    // TODO: Use waistWidth e.g. for distinct btwn male/female
    waistWidth: shoulderWidth / 1.3
    hipWidth: shoulderWidth * 0.9
    torsoHeight: headHeight * torsoHeightToHeadHeight
    torsoDepth: shoulderWidth * shoulderWidthToTorsoDepth
    armLength: torsoHeight * armLengthToTorsoHeight
    handLength: armLength / armLengthToHandLength
    legLength: height - torsoHeight - neckHeight
    footLength: height * footLengthToBodyHeight
}