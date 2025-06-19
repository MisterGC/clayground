import QtQuick
import QtQuick3D

ProceduralAnim {
    id: _walkCycle

    // // Forward offset should be proportional to leg length for natural stride
    property real footForwardOffset: 0.4 * entity.legHeight
    // // Hand swing should be proportional to arm length
    property real handForwardOffset: 0.3 * entity.armHeight
    property real footMaxRotation: 45
    property real handMaxRotation: 30

    // =========================
    // Derived position/rotations
    // =========================

    readonly property vector3d _footEulerForward: Qt.vector3d(-footMaxRotation, 0, 0)
    readonly property vector3d _footEulerBackward: Qt.vector3d(footMaxRotation, 0, 0)

    readonly property vector3d _handEulerForward: Qt.vector3d(-handMaxRotation, 0, 0)
    readonly property vector3d _handEulerBackward: Qt.vector3d(handMaxRotation, 0, 0)

    function _calculatePosition(bodyPart, yOffset, zOffset, isHand) {
        const basePos = bodyPart.basePos;
        // Use different scaling for hands vs feet
        const offset = isHand ? handForwardOffset : footForwardOffset;
        const verticalOffset = yOffset * (offset * 0.2);
        return Qt.vector3d(basePos.x, basePos.y + verticalOffset, basePos.z + zOffset);
    }

    // Access body parts through arm/leg hierarchy
    readonly property Foot rightFoot: entity.rightLeg.foot
    readonly property Foot leftFoot: entity.leftLeg.foot
    readonly property Hand rightHand: entity.rightArm.hand
    readonly property Hand leftHand: entity.leftArm.hand

    readonly property vector3d _rightFootPosForward: _calculatePosition(rightFoot, 1, footForwardOffset, false)
    readonly property vector3d _rightFootPosBackward: _calculatePosition(rightFoot, -1, -footForwardOffset, false)

    readonly property vector3d _leftFootPosForward: _calculatePosition(leftFoot, -1, footForwardOffset, false)
    readonly property vector3d _leftFootPosBackward: _calculatePosition(leftFoot, 1, -footForwardOffset, false)

    readonly property vector3d _rightHandPosForward: _calculatePosition(rightHand, 1, handForwardOffset, true)
    readonly property vector3d _leftHandPosForward: _calculatePosition(leftHand, 1, handForwardOffset, true)

    readonly property vector3d _rightHandPosBackward: _calculatePosition(rightHand, -1, -handForwardOffset, true)
    readonly property vector3d _leftHandPosBackward: _calculatePosition(leftHand, -1, -handForwardOffset, true)

    // Step 1: Right Foot Forward, Left Foot Backward
    ParallelAnimation {
        PosAndEulerAnim{
            target: _walkCycle.rightFoot

            duration: _walkCycle.duration
            fromPos: _walkCycle._rightFootPosBackward
            toPos: _walkCycle._rightFootPosForward
            fromEuler: _walkCycle._footEulerBackward
            toEuler: _walkCycle._footEulerForward
        }
        PosAndEulerAnim{
            target: _walkCycle.leftFoot

            duration: _walkCycle.duration
            fromPos: _walkCycle._leftFootPosForward
            toPos: _walkCycle._leftFootPosBackward
            fromEuler: _walkCycle._footEulerForward
            toEuler: _walkCycle._footEulerBackward
        }
        PosAndEulerAnim{
            target: _walkCycle.leftHand

            duration: _walkCycle.duration
            fromPos: _walkCycle._leftHandPosBackward
            toPos: _walkCycle._leftHandPosForward
            fromEuler: _walkCycle._handEulerBackward
            toEuler: _walkCycle._handEulerForward
        }
        PosAndEulerAnim{
            target: _walkCycle.rightHand

            duration: _walkCycle.duration
            fromPos: _walkCycle._rightHandPosForward
            toPos: _walkCycle._rightHandPosBackward
            fromEuler: _walkCycle._handEulerForward
            toEuler: _walkCycle._handEulerBackward
        }
    }

    // Step 2: Right Foot Backward, Left Foot Forward
    ParallelAnimation {
        PosAndEulerAnim{
            target: _walkCycle.rightFoot

            duration: _walkCycle.duration
            fromPos: _walkCycle._rightFootPosForward
            toPos: _walkCycle._rightFootPosBackward
            fromEuler: _walkCycle._footEulerForward
            toEuler: _walkCycle._footEulerBackward
        }
        PosAndEulerAnim{
            target: _walkCycle.leftFoot

            duration: _walkCycle.duration
            fromPos: _walkCycle._leftFootPosBackward
            toPos: _walkCycle._leftFootPosForward
            fromEuler: _walkCycle._footEulerBackward
            toEuler: _walkCycle._footEulerForward
        }
        PosAndEulerAnim{
            target: _walkCycle.leftHand

            duration: _walkCycle.duration
            fromPos: _walkCycle._leftHandPosForward
            toPos: _walkCycle._leftHandPosBackward
            fromEuler: _walkCycle._handEulerForward
            toEuler: _walkCycle._handEulerBackward
        }
        PosAndEulerAnim{
            target: _walkCycle.rightHand

            duration: _walkCycle.duration
            fromPos: _walkCycle._rightHandPosBackward
            toPos: _walkCycle._rightHandPosForward
            fromEuler: _walkCycle._handEulerBackward
            toEuler: _walkCycle._handEulerForward
        }
    }
}
