// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick

Item {
    id: root
    
    // Required: The character to control
    required property QtObject character
    
    // Movement configuration
    property real turnSpeed: 2.0        // degrees per frame per unit axis
    property real walkSpeed: 0.5        // world units per frame per unit axis
    property real inputDeadzone: 0.1    // axis deadzone
    
    // Input values (can be bound to GameController or other input sources)
    property real axisX: 0.0            // Turn left/right (-1 to 1)
    property real axisY: 0.0            // Move forward/backward (-1 to 1)
    property bool buttonA: false        // Reserved for future use
    property bool buttonB: false        // Reserved for future use
    
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
                
                // Scale by input and speed
                const deltaX = fwdX * root.processedAxisY * root.walkSpeed;
                const deltaZ = fwdZ * root.processedAxisY * root.walkSpeed;
                
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
    
    // Helper function to bind to a GameController
    function bindToGameController(controller) {
        root.axisX = Qt.binding(function() { return controller.axisX; });
        root.axisY = Qt.binding(function() { return controller.axisY; });
        root.buttonA = Qt.binding(function() { return controller.buttonAPressed; });
        root.buttonB = Qt.binding(function() { return controller.buttonBPressed; });
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