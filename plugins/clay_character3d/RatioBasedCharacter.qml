// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype RatioBasedCharacter
    \inqmlmodule Clayground.Character3D
    \inherits Character
    \brief Character with dimension ratios for style customization.

    RatioBasedCharacter extends Character by calculating dimensions from ratio
    properties. This provides fine control over proportions like head-to-body
    ratios for creating different character styles (comic, realistic, etc.).

    Example usage:
    \qml
    import Clayground.Character3D

    RatioBasedCharacter {
        name: "toon"
        headsTall: 4.7           // Cartoon proportions
        headWidthToHeight: 0.9
        shoulderWidthToHeadWidth: 1.8
    }
    \endqml

    \qmlproperty real RatioBasedCharacter::headsTall
    \brief How many head heights fit in the body. Lower = more cartoon-like.

    \qmlproperty real RatioBasedCharacter::headWidthToHeight
    \brief Head width as ratio of head height.

    \qmlproperty real RatioBasedCharacter::headDepthToHeadWidth
    \brief Head depth as ratio of head width.

    \qmlproperty real RatioBasedCharacter::neckHeightToHeadHeight
    \brief Neck height as ratio of head height.

    \qmlproperty real RatioBasedCharacter::shoulderWidthToHeadWidth
    \brief Shoulder width as ratio of head width.

    \qmlproperty real RatioBasedCharacter::torsoHeightToHeadHeight
    \brief Torso height as ratio of head height.

    \qmlproperty real RatioBasedCharacter::shoulderWidthToTorsoDepth
    \brief Torso depth as ratio of shoulder width.

    \qmlproperty real RatioBasedCharacter::armHeightToTorsoHeight
    \brief Arm length as ratio of torso height.

    \qmlproperty real RatioBasedCharacter::armHeightToHandLength
    \brief Arm length divided by hand length.

    \qmlproperty real RatioBasedCharacter::footLengthToBodyHeight
    \brief Foot length as ratio of body height.
*/
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
    property real armHeightToTorsoHeight: 1.0
    property real armHeightToHandLength: 3
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
    armHeight: torsoHeight * armHeightToTorsoHeight
    handLength: armHeight / armHeightToHandLength
    legHeight: height - torsoHeight - neckHeight
    footLength: height * footLengthToBodyHeight
}