// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import ".."

Item {
    id: root

    // Required: The character to control
    required property QtObject character

    // Patrol area bounds (world coordinates)
    property real minX: -40
    property real maxX: 40
    property real minZ: -40
    property real maxZ: 40

    // Movement configuration
    property real turnSpeed: 3.0
    property real arrivalThreshold: 2.0  // Distance to consider "arrived"

    // Idle pause between destinations
    property int minIdleTime: 1000  // ms
    property int maxIdleTime: 3000  // ms

    // Enable/disable controller
    property bool enabled: true

    // Update rate
    property int updateInterval: 50  // milliseconds

    // Current destination
    property real destX: 0
    property real destZ: 0

    // State
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
