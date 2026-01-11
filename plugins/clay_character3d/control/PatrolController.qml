// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import ".."

/*!
    \qmltype PatrolController
    \inqmlmodule Clayground.Character3D
    \brief AI controller for character patrol behavior.

    PatrolController makes a character wander randomly within a defined
    area. It picks random destinations, turns toward them, walks there,
    pauses briefly, then picks a new destination.

    Example usage:
    \qml
    import Clayground.Character3D

    Character {
        id: npc
    }

    PatrolController {
        character: npc
        minX: -50
        maxX: 50
        minZ: -50
        maxZ: 50
        minIdleTime: 2000
        maxIdleTime: 5000
    }
    \endqml

    \sa Character, CharacterController
*/
Item {
    id: root

    /*!
        \qmlproperty QtObject PatrolController::character
        \brief The character to control (required).
    */
    required property QtObject character

    /*!
        \qmlproperty real PatrolController::minX
        \brief Minimum X coordinate of patrol area.
    */
    property real minX: -40

    /*!
        \qmlproperty real PatrolController::maxX
        \brief Maximum X coordinate of patrol area.
    */
    property real maxX: 40

    /*!
        \qmlproperty real PatrolController::minZ
        \brief Minimum Z coordinate of patrol area.
    */
    property real minZ: -40

    /*!
        \qmlproperty real PatrolController::maxZ
        \brief Maximum Z coordinate of patrol area.
    */
    property real maxZ: 40

    /*!
        \qmlproperty real PatrolController::turnSpeed
        \brief Turn speed in degrees per update.
    */
    property real turnSpeed: 3.0

    /*!
        \qmlproperty real PatrolController::arrivalThreshold
        \brief Distance at which character is considered to have arrived.
    */
    property real arrivalThreshold: 2.0

    /*!
        \qmlproperty int PatrolController::minIdleTime
        \brief Minimum idle pause duration in milliseconds.
    */
    property int minIdleTime: 1000

    /*!
        \qmlproperty int PatrolController::maxIdleTime
        \brief Maximum idle pause duration in milliseconds.
    */
    property int maxIdleTime: 3000

    /*!
        \qmlproperty bool PatrolController::enabled
        \brief Whether the controller is active.
    */
    property bool enabled: true

    /*!
        \qmlproperty int PatrolController::updateInterval
        \brief Update frequency in milliseconds.
    */
    property int updateInterval: 50

    /*!
        \qmlproperty real PatrolController::destX
        \brief Current destination X coordinate.
    */
    property real destX: 0

    /*!
        \qmlproperty real PatrolController::destZ
        \brief Current destination Z coordinate.
    */
    property real destZ: 0

    /*!
        \qmlproperty bool PatrolController::isIdle
        \brief True when character is pausing between destinations.
    */
    property bool isIdle: true

    Component.onCompleted: {
        pickNewDestination()
        idleTimer.interval = randomInt(minIdleTime, maxIdleTime)
        idleTimer.start()
    }

    function randomInt(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min
    }

    function pickNewDestination() {
        destX = minX + Math.random() * (maxX - minX)
        destZ = minZ + Math.random() * (maxZ - minZ)
    }

    function distanceToDestination() {
        const dx = destX - character.position.x
        const dz = destZ - character.position.z
        return Math.sqrt(dx * dx + dz * dz)
    }

    function angleToDestination() {
        const dx = destX - character.position.x
        const dz = destZ - character.position.z
        // atan2 gives angle from +X axis, we need angle from -Z axis (forward)
        // Forward is -Z, so we compute angle accordingly
        return Math.atan2(dx, dz) * 180 / Math.PI
    }

    function normalizeAngle(angle) {
        while (angle > 180) angle -= 360
        while (angle < -180) angle += 360
        return angle
    }

    Timer {
        id: idleTimer
        running: false
        repeat: false
        onTriggered: {
            root.isIdle = false
        }
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.enabled
        repeat: true

        onTriggered: {
            if (!root.character || root.isIdle) {
                if (root.character) {
                    root.character.activity = Character.Idle
                }
                return
            }

            const dist = root.distanceToDestination()

            // Check if arrived
            if (dist < root.arrivalThreshold) {
                root.isIdle = true
                root.character.activity = Character.Idle
                root.pickNewDestination()
                idleTimer.interval = root.randomInt(root.minIdleTime, root.maxIdleTime)
                idleTimer.start()
                return
            }

            // Turn toward destination
            const targetAngle = root.angleToDestination()
            const currentAngle = root.character.eulerRotation.y
            let angleDiff = root.normalizeAngle(targetAngle - currentAngle)

            // Apply turn
            if (Math.abs(angleDiff) > 2) {
                const turnAmount = Math.sign(angleDiff) * Math.min(Math.abs(angleDiff), root.turnSpeed)
                root.character.eulerRotation.y += turnAmount
            }

            // Move forward if roughly facing destination
            if (Math.abs(angleDiff) < 45) {
                const yawRad = root.character.eulerRotation.y * Math.PI / 180
                const fwdX = Math.sin(yawRad)
                const fwdZ = Math.cos(yawRad)

                const frameTime = root.updateInterval / 1000.0
                const speedPerFrame = root.character.currentSpeed * frameTime

                root.character.position.x += fwdX * speedPerFrame
                root.character.position.z += fwdZ * speedPerFrame

                root.character.activity = Character.Walking
            } else {
                // Still turning, stay idle or walk slowly
                root.character.activity = Character.Idle
            }
        }
    }
}
