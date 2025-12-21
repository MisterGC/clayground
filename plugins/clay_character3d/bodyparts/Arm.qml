// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

BodyPartsGroup {
    id: _arm

    // Total arm dimensions
    width: 0.917  // Default: 3.667 * 0.25
    height: 3.667 // Default arm length
    depth: 1.1    // Default: 3.667 * 0.3

    // Proportion controls
    property real upperRatio: 0.5     // Upper arm proportion (0.4-0.6)
    property real lowerTaper: 0.9     // Lower arm taper (width/depth reduction)

    // Arm color (applies to upper and lower arm)
    property alias color: _upperArm.color

    // Hand dimension aliases
    property alias handWidth: _hand.width
    property alias handHeight: _hand.height
    property alias handDepth: _hand.depth

    // Hand color alias
    property alias handColor: _hand.color

    // Expose arm parts for animation (animate the joints, not the geometry)
    readonly property alias upperArm: _shoulderJoint
    readonly property alias lowerArm: _elbowJoint
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
