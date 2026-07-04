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
        bodyHeight: 10.0
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

    // Proportion Relations - tune for specific
    // style e.g. comic, realistic or male vs female

    /*!
        \qmlproperty real RatioBasedCharacter::bodyHeight
        \brief Total character height in world units.

        All other dimensions are derived from this value via the ratio
        properties.
    */
    property real bodyHeight: 10.0

    /*!
        \qmlproperty real RatioBasedCharacter::headsTall
        \brief How many head heights fit in the body.

        Lower values create more cartoon-like proportions.
    */
    property real headsTall: 4.7

    /*!
        \qmlproperty real RatioBasedCharacter::headWidthToHeight
        \brief Head width as ratio of head height.
    */
    property real headWidthToHeight: 0.9

    /*!
        \qmlproperty real RatioBasedCharacter::headDepthToHeadWidth
        \brief Head depth as ratio of head width.
    */
    property real headDepthToHeadWidth: 0.8

    /*!
        \qmlproperty real RatioBasedCharacter::neckHeightToHeadHeight
        \brief Neck height as ratio of head height.
    */
    property real neckHeightToHeadHeight: 0.2

    /*!
        \qmlproperty real RatioBasedCharacter::shoulderWidthToHeadWidth
        \brief Shoulder width as ratio of head width.
    */
    property real shoulderWidthToHeadWidth: 1.8

    /*!
        \qmlproperty real RatioBasedCharacter::torsoHeightToHeadHeight
        \brief Torso height as ratio of head height.
    */
    property real torsoHeightToHeadHeight: 2.0

    /*!
        \qmlproperty real RatioBasedCharacter::shoulderWidthToTorsoDepth
        \brief Torso depth as ratio of shoulder width.
    */
    property real shoulderWidthToTorsoDepth: 0.3

    /*!
        \qmlproperty real RatioBasedCharacter::armHeightToTorsoHeight
        \brief Arm length as ratio of torso height.
    */
    property real armHeightToTorsoHeight: 1.0

    /*!
        \qmlproperty real RatioBasedCharacter::armHeightToHandLength
        \brief Arm length divided by hand length.
    */
    property real armHeightToHandLength: 3

    /*!
        \qmlproperty real RatioBasedCharacter::footLengthToBodyHeight
        \brief Foot length as ratio of body height.
    */
    property real footLengthToBodyHeight: 0.15

    // Intermediate values derived from the ratios
    readonly property real _headHeight: bodyHeight / headsTall
    readonly property real _headWidth: _headHeight * headWidthToHeight
    readonly property real _headDepth: _headWidth * headDepthToHeadWidth

    // Calculated dimensions based on ratios
    upperHeadHeight: _headHeight * 0.6
    lowerHeadHeight: _headHeight * 0.4
    upperHeadWidth: _headWidth
    lowerHeadWidth: _headWidth * 0.9
    upperHeadDepth: _headDepth
    lowerHeadDepth: _headDepth * 0.9
    neckHeight: _headHeight * neckHeightToHeadHeight
    shoulderWidth: _headWidth * shoulderWidthToHeadWidth
    // TODO: Use waistWidth e.g. for distinct btwn male/female
    waistWidth: shoulderWidth / 1.3
    hipWidth: shoulderWidth * 0.9
    hipHeight: _headHeight * 0.5
    torsoHeight: _headHeight * torsoHeightToHeadHeight
    torsoDepth: shoulderWidth * shoulderWidthToTorsoDepth
    armHeight: torsoHeight * armHeightToTorsoHeight
    handHeight: armHeight / armHeightToHandLength
    legHeight: Math.max(0.1, bodyHeight - _headHeight - neckHeight
                             - torsoHeight - hipHeight - footHeight)
    footDepth: bodyHeight * footLengthToBodyHeight
}