// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import ".."

/*!
    \qmltype CharacterController
    \inqmlmodule Clayground.Character3D
    \brief Player input controller for Character movement.

    CharacterController translates input axis values into character movement
    and rotation. Bind axisX and axisY to a GameController or other input
    source to control a character.

    The controller automatically sets the character's activity state based
    on movement (Idle, Walking, Running).

    Example usage:
    \qml
    import Clayground.Character3D
    import Clayground.GameController

    Character {
        id: hero
    }

    GameController {
        id: gamepad
    }

    CharacterController {
        character: hero
        axisX: gamepad.axisLeftX
        axisY: gamepad.axisLeftY
        sprinting: gamepad.buttonL1
    }
    \endqml

    \sa Character, PatrolController
*/
Item {
    id: root

    /*!
        \qmlproperty QtObject CharacterController::character
        \brief The character to control (required).
    */
    required property QtObject character

    /*!
        \qmlproperty real CharacterController::turnSpeed
        \brief Turn speed in degrees per frame per unit axis input.
    */
    property real turnSpeed: 2.0

    /*!
        \qmlproperty real CharacterController::inputDeadzone
        \brief Axis values below this threshold are treated as zero.
    */
    property real inputDeadzone: 0.1

    /*!
        \qmlproperty real CharacterController::axisX
        \brief Horizontal input axis for turning (-1 to 1, required).
    */
    required property real axisX

    /*!
        \qmlproperty real CharacterController::axisY
        \brief Vertical input axis for forward/backward (-1 to 1, required).
    */
    required property real axisY

    /*!
        \qmlproperty bool CharacterController::sprinting
        \brief When true, character runs instead of walks.
    */
    property bool sprinting: false

    /*!
        \qmlproperty bool CharacterController::enabled
        \brief Whether the controller is active.
    */
    property bool enabled: true

    /*!
        \qmlproperty int CharacterController::updateInterval
        \brief Update frequency in milliseconds.
    */
    property int updateInterval: 50

    /*!
        \qmlproperty real CharacterController::processedAxisX
        \readonly
        \brief Horizontal axis value after deadzone is applied.
    */
    readonly property real processedAxisX: Math.abs(axisX) > inputDeadzone ? axisX : 0

    /*!
        \qmlproperty real CharacterController::processedAxisY
        \readonly
        \brief Vertical axis value after deadzone is applied.
    */
    readonly property real processedAxisY: Math.abs(axisY) > inputDeadzone ? axisY : 0

    /*!
        \qmlproperty bool CharacterController::isMoving
        \readonly
        \brief True when forward/backward input is active.
    */
    readonly property bool isMoving: processedAxisY !== 0

    /*!
        \qmlproperty bool CharacterController::isTurning
        \readonly
        \brief True when turn input is active.
    */
    readonly property bool isTurning: processedAxisX !== 0

    /*!
        \qmlsignal CharacterController::moved(real deltaX, real deltaZ)
        \brief Emitted when the character moves.
    */
    signal moved(real deltaX, real deltaZ)

    /*!
        \qmlsignal CharacterController::turned(real deltaYaw)
        \brief Emitted when the character turns.
    */
    signal turned(real deltaYaw)

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.enabled
        repeat: true

        onTriggered: {
            if (!root.character) return;

            // Handle rotation
            if (root.processedAxisX) {
                const deltaYaw = -root.processedAxisX * root.turnSpeed;
                root.character.eulerRotation.y += deltaYaw;
                root.turned(deltaYaw);
            }

            // Handle movement
            if (root.processedAxisY) {
                // Compute yaw in radians
                const yawRad = root.character.eulerRotation.y * Math.PI / 180;

                // Forward vector: yaw=0 means looking along -Z
                const fwdX = Math.sin(yawRad);
                const fwdZ = Math.cos(yawRad);

                // Use currentSpeed which is derived from animation (walk or run)
                const frameTime = root.updateInterval / 1000.0;  // Convert ms to seconds
                const speedPerFrame = root.character.currentSpeed * frameTime;

                // Scale by input and speed
                const deltaX = fwdX * root.processedAxisY * speedPerFrame;
                const deltaZ = fwdZ * root.processedAxisY * speedPerFrame;

                // Update position
                root.character.position.x += deltaX;
                root.character.position.z += deltaZ;

                root.moved(deltaX, deltaZ);
            }

            // Update character activity state based on movement and sprint
            // Only override movement-based activities, preserve special activities like Using/Fighting
            if (root.processedAxisY) {
                root.character.activity = root.sprinting ? Character.Running : Character.Walking;
            } else if (root.character.activity === Character.Walking ||
                       root.character.activity === Character.Running) {
                root.character.activity = Character.Idle;
            }
            // Note: Using and Fighting activities are preserved until explicitly changed
        }
    }

    // Helper function to apply custom movement (for AI, scripted sequences, etc.)
    function applyMovement(forwardAmount, turnAmount) {
        root.axisY = forwardAmount;
        root.axisX = turnAmount;
    }

    // Stop all movement
    function stop() {
        root.axisX = 0;
        root.axisY = 0;
    }
}
