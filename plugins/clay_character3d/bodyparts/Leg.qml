// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype Leg
    \inqmlmodule Clayground.Character3D
    \inherits BodyPartsGroup
    \brief A complete leg with upper leg, lower leg, and foot.

    Leg is a hierarchical body part group containing an upper leg, lower leg,
    and foot connected by animatable joints (hip, knee, ankle).

    The leg uses a joint-based hierarchy for natural animation:
    - Hip joint controls the entire leg
    - Knee joint controls lower leg and foot
    - Ankle joint controls foot rotation

    Example usage:
    \qml
    import Clayground.Character3D

    Leg {
        width: 1.2
        height: 5.5
        upperRatio: 0.5
        color: "#708090"
        footColor: "#8b4513"
    }
    \endqml

    \sa Arm, Foot, Character
*/
BodyPartsGroup {
    id: _leg

    /*!
        \qmlproperty real Leg::width
        \brief Width of the leg segments.
    */

    /*!
        \qmlproperty real Leg::height
        \brief Total leg length from hip to ankle.
    */

    /*!
        \qmlproperty real Leg::depth
        \brief Depth of the leg segments.
    */

    // Total leg dimensions
    width: 1.067  // Default: 5.333 * 0.2
    height: 5.333 // Default leg length
    depth: 1.333  // Default: 5.333 * 0.25

    /*!
        \qmlproperty real Leg::upperRatio
        \brief Proportion of total leg length for upper leg (0.4-0.6).

        A value of 0.5 means upper and lower leg are equal length.
    */
    property real upperRatio: 0.5

    /*!
        \qmlproperty real Leg::lowerTaper
        \brief Taper factor for lower leg width/depth (0-1).

        Controls how much the calf narrows compared to the thigh.
    */
    property real lowerTaper: 0.8

    /*!
        \qmlproperty color Leg::color
        \brief Color of the leg (upper and lower segments).
    */
    property alias color: _upperLeg.color

    /*!
        \qmlproperty real Leg::footWidth
        \brief Width of the foot.
    */
    property alias footWidth: _foot.width

    /*!
        \qmlproperty real Leg::footHeight
        \brief Height of the foot.
    */
    property alias footHeight: _foot.height

    /*!
        \qmlproperty real Leg::footDepth
        \brief Depth of the foot.
    */
    property alias footDepth: _foot.depth

    /*!
        \qmlproperty color Leg::footColor
        \brief Color of the foot (shoe color).
    */
    property alias footColor: _foot.color

    /*!
        \qmlproperty Node Leg::upperLeg
        \brief Reference to the hip joint for animation.
    */
    readonly property alias upperLeg: _hipJoint

    /*!
        \qmlproperty Node Leg::lowerLeg
        \brief Reference to the knee joint for animation.
    */
    readonly property alias lowerLeg: _kneeJoint

    /*!
        \qmlproperty Node Leg::foot
        \brief Reference to the ankle joint for animation.
    */
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
