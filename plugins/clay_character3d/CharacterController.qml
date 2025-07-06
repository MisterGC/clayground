// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick

Item {
    id: root

    // Required: The character to control
    required property QtObject character

    // Movement configuration
    property real turnSpeed: 2.0        // degrees per frame per unit axis

    // Input values (can be bound to GameController or other input sources)
    property real inputDeadzone: 0.1    // axis deadzone
    required property real axisX        // Turn left/right (-1 to 1)
    required property real axisY        // Move forward/backward (-1 to 1)

    // Enable/disable controller
    property bool enabled: true

    // Update rate
    property int updateInterval: 50     // milliseconds

    // Processed input values (applying deadzone)
    readonly property real processedAxisX: Math.abs(axisX) > inputDeadzone ? axisX : 0
    readonly property real processedAxisY: Math.abs(axisY) > inputDeadzone ? axisY : 0

    // Movement state
    readonly property bool isMoving: processedAxisY !== 0
    readonly property bool isTurning: processedAxisX !== 0

    // Signals for external actions
    signal moved(real deltaX, real deltaZ)
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

                // Convert character's walk speed from units/second to units/frame
                const frameTime = root.updateInterval / 1000.0;  // Convert ms to seconds
                const speedPerFrame = root.character.walkSpeed * frameTime;

                // Scale by input and speed
                const deltaX = fwdX * root.processedAxisY * speedPerFrame;
                const deltaZ = fwdZ * root.processedAxisY * speedPerFrame;

                // Update position
                root.character.position.x += deltaX;
                root.character.position.z += deltaZ;

                root.moved(deltaX, deltaZ);
            }

            // Update character activity state
            if (root.processedAxisY) {
                root.character.activity = Character.Walking;
            } else {
                root.character.activity = Character.Idle;
            }
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
