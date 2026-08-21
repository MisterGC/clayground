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
    property alias handWidth: _hand.palmWidth

    /*!
        \qmlproperty real Arm::handHeight
        \brief Height of the hand.
    */
    property alias handHeight: _hand.palmHeight

    /*!
        \qmlproperty real Arm::handDepth
        \brief Depth of the hand.
    */
    property alias handDepth: _hand.palmDepth

    /*!
        \qmlproperty color Arm::handColor
        \brief Color of the hand (skin color).
    */
    property alias handColor: _hand.color

    /*!
        \qmlproperty bool Arm::articulated
        \brief Whether the hand has fingers.

        Off by default: a \l DetailedHand is ten more boxes per hand, and a
        character seen from across a room does not need them.

        Switching it on keeps the plain hand box and demotes it to the palm the
        fingers grow off. That is a real change of size: on its own the box is
        a whole hand and reshapes itself for every \l handPose, and a palm is
        less than half of one. The two are built to match in outline, so the
        swap is meant to go unnoticed - but the box is not the same box.

        \sa DetailedHand, handPose, Hand
    */
    property bool articulated: false

    /*!
        \qmlproperty string Arm::handPose
        \brief What the hand is doing: "relax", "open", "point", "thumbsUp"
               or "fist".

        Read at both levels of detail. An \l articulated hand folds real
        fingers for it; a plain one reshapes its single box to the same pose's
        outline, so a wave and a raised fist are still different things on a
        character too far away to have fingers.
    */
    property string handPose: "relax"

    /*!
        \qmlproperty bool Arm::mirrored
        \brief Set on a left arm, so an articulated hand puts its thumb on
               the correct side.
    */
    property bool mirrored: false

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

    /*!
        \qmlproperty vector3d Arm::indexTip
        \readonly
        \brief Where the hand ends, in \l hand's own frame - the point to aim
               along, and the point to measure a gesture against.

        On an \l articulated arm this is the tip of the extended index finger,
        and only meaningful while the index is straight. On a plain one it is
        the far face of the hand box, so a caller measuring reach does not have
        to know which kind of hand it has.
    */
    readonly property vector3d indexTip: _fingers.item
                                       ? _fingers.item.indexTip
                                       : Qt.vector3d(0, -_hand.height, 0)

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

                // A palm is a SLAB, not a brick. These three were 0.8/0.2/0.6
                // of the arm, which comes out 1.2 : 1.6 : 1 - very nearly a
                // cube, where a real palm is about 3 : 3.3 : 1. Close up that
                // is what made an articulated hand read as a block with
                // pimples on it: the palm was so much bigger than the fingers
                // that nothing else on the hand registered. It is also wider
                // than the wrist it hangs off, which is why width goes above
                // one - a palm narrower than its own forearm is the other half
                // of the same mistake.
                Hand {
                    id: _hand
                    basePos: Qt.vector3d(0, -height, 0)
                    palmWidth: _arm.width * 1.05
                    palmHeight: _arm.height * 0.19
                    palmDepth: _arm.depth * 0.34

                    // An empty pose means "you are a palm, do not reshape".
                    // The single box shapes itself to stand in for fingers it
                    // does not have; with real fingers on top of it the same
                    // shaping would be counted twice, and a fist would come
                    // out as a swollen palm inside a folded hand.
                    pose: _arm.articulated ? "" : _arm.handPose
                }

                // The fingers, when they are wanted. They hang off the same
                // wrist joint as the hand box and use it as their palm.
                // Loaded on demand: a character that never shapes a hand does
                // not pay ten boxes per arm for the option.
                Loader3D {
                    id: _fingers
                    active: _arm.articulated
                    sourceComponent: Component {
                        DetailedHand {
                            pose: _arm.handPose
                            mirrored: _arm.mirrored
                            palmWidth: _hand.width
                            palmHeight: _hand.height
                            palmDepth: _hand.depth
                            tone: _hand.color
                        }
                    }
                }
            }
        }
    }
}
