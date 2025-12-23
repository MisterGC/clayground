// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

BodyPartsGroup {
    id: _leg

    // Total leg dimensions
    width: 1.067  // Default: 5.333 * 0.2
    height: 5.333 // Default leg length
    depth: 1.333  // Default: 5.333 * 0.25

    // Proportion controls
    property real upperRatio: 0.5     // Upper leg proportion (0.4-0.6)
    property real lowerTaper: 0.8     // Lower leg taper (width/depth reduction)

    // Leg color (applies to upper and lower leg)
    property alias color: _upperLeg.color

    // Foot dimension aliases
    property alias footWidth: _foot.width
    property alias footHeight: _foot.height
    property alias footDepth: _foot.depth

    // Foot color alias
    property alias footColor: _foot.color

    // Expose leg parts for animation (animate the joints, not the geometry)
    readonly property alias upperLeg: _hipJoint
    readonly property alias lowerLeg: _kneeJoint
    readonly property alias foot: _ankleJoint

    // Hip joint - rotation point for upper leg
    Node {
        id: _hipJoint
        // At Leg origin (Y=0) = hip joint position

        // Upper leg geometry (hip to knee)
        BodyPart {
            id: _upperLeg
            width: _leg.width
            height: _leg.height * _leg.upperRatio
            depth: _leg.depth
            color: "#708090"
            basePos: Qt.vector3d(0, -height, 0)  // Extends downward from hip
        }

        // Knee joint - rotation point for lower leg
        Node {
            id: _kneeJoint
            position: Qt.vector3d(0, -_upperLeg.height, 0)  // At bottom of upper leg

            // Lower leg geometry (knee to ankle)
            BodyPart {
                id: _lowerLeg
                width: _leg.width * _leg.lowerTaper
                height: _leg.height * (1.0 - _leg.upperRatio)
                depth: _leg.depth * _leg.lowerTaper
                basePos: Qt.vector3d(0, -height, 0)  // Extends downward from knee
                color: _upperLeg.color
            }

            // Ankle joint - rotation point for foot
            Node {
                id: _ankleJoint
                position: Qt.vector3d(0, -_lowerLeg.height, 0)  // At bottom of lower leg

                Foot {
                    id: _foot
                    basePos: Qt.vector3d(0, -height, _leg.depth * 0.4)
                    width: depth * 0.5
                    depth: _leg.height * (1.0 - _leg.upperRatio) * 0.6
                    height: depth * 0.3
                }
            }
        }
    }
}
