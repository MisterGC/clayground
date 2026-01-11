// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype Arm
    \inqmlmodule Clayground.Character3D
    \inherits BodyPartsGroup
    \brief A complete arm with upper arm, lower arm, and hand.

    Arm is a hierarchical body part group containing an upper arm, lower arm,
    and hand connected by animatable joints (shoulder, elbow, wrist).

    The arm uses a joint-based hierarchy for natural animation:
    - Shoulder joint controls the entire arm
    - Elbow joint controls lower arm and hand
    - Wrist joint controls hand rotation

    Example usage:
    \qml
    import Clayground.Character3D

    Arm {
        width: 1.0
        height: 4.0
        upperRatio: 0.45
        color: "#4169e1"
        handColor: "#d38d5f"
    }
    \endqml

    \sa Leg, Hand, Character
*/
BodyPartsGroup {
    id: _arm

    /*!
        \qmlproperty real Arm::width
        \brief Width of the arm segments.
    */

    /*!
        \qmlproperty real Arm::height
        \brief Total arm length from shoulder to wrist.
    */

    /*!
        \qmlproperty real Arm::depth
        \brief Depth of the arm segments.
    */

    // Total arm dimensions
    width: 0.917  // Default: 3.667 * 0.25
    height: 3.667 // Default arm length
    depth: 1.1    // Default: 3.667 * 0.3

    /*!
        \qmlproperty real Arm::upperRatio
        \brief Proportion of total arm length for upper arm (0.4-0.6).

        A value of 0.5 means upper and lower arm are equal length.
    */
    property real upperRatio: 0.5

    /*!
        \qmlproperty real Arm::lowerTaper
        \brief Taper factor for lower arm width/depth (0-1).

        Controls how much the forearm narrows compared to the upper arm.
    */
    property real lowerTaper: 0.9

    /*!
        \qmlproperty color Arm::color
        \brief Color of the arm (upper and lower segments).
    */
    property alias color: _upperArm.color

    /*!
        \qmlproperty real Arm::handWidth
        \brief Width of the hand.
    */
    property alias handWidth: _hand.width

    /*!
        \qmlproperty real Arm::handHeight
        \brief Height of the hand.
    */
    property alias handHeight: _hand.height

    /*!
        \qmlproperty real Arm::handDepth
        \brief Depth of the hand.
    */
    property alias handDepth: _hand.depth

    /*!
        \qmlproperty color Arm::handColor
        \brief Color of the hand (skin color).
    */
    property alias handColor: _hand.color

    /*!
        \qmlproperty Node Arm::upperArm
        \brief Reference to the shoulder joint for animation.
    */
    readonly property alias upperArm: _shoulderJoint

    /*!
        \qmlproperty Node Arm::lowerArm
        \brief Reference to the elbow joint for animation.
    */
    readonly property alias lowerArm: _elbowJoint

    /*!
        \qmlproperty Node Arm::hand
        \brief Reference to the wrist joint for animation.
    */
    readonly property alias hand: _wristJoint

    // Shoulder joint - rotation point for upper arm
    Node {
        id: _shoulderJoint
        // At Arm origin (Y=0) = shoulder joint position

        // Upper arm geometry (shoulder to elbow)
        BodyPart {
            id: _upperArm
            width: _arm.width
            height: _arm.height * _arm.upperRatio
            depth: _arm.depth
            color: "#4169e1"
            basePos: Qt.vector3d(0, -height, 0)  // Extends downward from shoulder
        }

        // Elbow joint - rotation point for lower arm
        Node {
            id: _elbowJoint
            position: Qt.vector3d(0, -_upperArm.height, 0)  // At bottom of upper arm

            // Lower arm geometry (elbow to wrist)
            BodyPart {
                id: _lowerArm
                width: _arm.width * _arm.lowerTaper
                height: _arm.height * (1.0 - _arm.upperRatio)
                depth: _arm.depth * _arm.lowerTaper
                basePos: Qt.vector3d(0, -height, 0)  // Extends downward from elbow
                color: _upperArm.color
            }

            // Wrist joint - rotation point for hand
            Node {
                id: _wristJoint
                position: Qt.vector3d(0, -_lowerArm.height, 0)  // At bottom of lower arm

                Hand {
                    id: _hand
                    basePos: Qt.vector3d(0, -height, 0)
                    width: _arm.width * 0.8
                    height: _arm.height * 0.2
                    depth: _arm.depth * 0.6
                }
            }
        }
    }
}
