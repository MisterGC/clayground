import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// Import the Character component if it's in the same directory or adjust path
import "."

PerspectiveCamera {
    id: rootCamera

    // Expose the character as a property
    property Character character: null

    // Properties for controlling the camera orbit
    property real orbitYawOffset: 180 // Relative to character rotation (degrees)
    property real orbitPitch: 20     // Vertical angle (degrees)
    property real orbitDistance: 40  // Distance from character

    // Define limits for orbit parameters
    property real minOrbitDistance: 5.0
    property real maxOrbitDistance: 100.0
    property real minOrbitPitch: -85.0 // Limit looking straight down
    property real maxOrbitPitch: 85.0  // Limit looking straight up

    // Default clip planes
    property real clipNear: 1
    property real clipFar: 5000 // Set a reasonable far clip plane

    // Internal helper function to calculate position based on orbit parameters
    function updatePosition() {
        if (!character) return Qt.vector3d(0, 0, 0); // Default position if no character

        // Clamp orbit parameters within defined limits
        var clampedPitch = Math.max(minOrbitPitch, Math.min(maxOrbitPitch, orbitPitch));
        var clampedDistance = Math.max(minOrbitDistance, Math.min(maxOrbitDistance, orbitDistance));

        // Normalize yaw offset (optional, keeps it tidy)
        var normalizedYawOffset = orbitYawOffset % 360;
        if (normalizedYawOffset < 0) normalizedYawOffset += 360;

        // Character's current yaw in degrees
        const charYaw = character.eulerRotation.y;

        // Total horizontal angle = facing direction + camera's offset
        const totalYawDeg = charYaw + normalizedYawOffset;
        const yawRad  = totalYawDeg * Math.PI / 180;
        const pitchRad = clampedPitch * Math.PI / 180;

        // Calculate camera offset in spherical coordinates
        const x = clampedDistance * Math.sin(yawRad) * Math.cos(pitchRad);
        const y = clampedDistance * Math.sin(pitchRad);
        const z = clampedDistance * Math.cos(yawRad) * Math.cos(pitchRad);

        // Calculate the target lookAt point (character's head position in world coordinates)
        // Note: Assuming character.head exists and has a 'position' property relative to the character's origin.
        // If head position is already world, just use character.head.position.
        // If character.position is the base and head.position is relative, add them.
        // We need to ensure head is accessible. Let's assume head is an Item3D child.
        // We might need a more robust way to get the head's world position later.
        const headLocalPos = character.head ? character.head.position : Qt.vector3d(0, character.height * 0.8, 0); // Default if head not ready
        // Use direct addition of character position and head local position
        // to ensure dependency on character.position is explicit for the binding.
        const headWorldPos = character.position.plus(headLocalPos);


        // The camera's position is the target lookAt point plus the calculated offset
        return headWorldPos.plus(Qt.vector3d(x, y, z));
    }

    // Bind the camera's position to the result of the update function
    // This ensures it recalculates whenever character position/rotation or orbit parameters change.
    position: updatePosition()

    // Make the camera look at the character's head
    // Using lookAtNode is simpler if the head node is directly accessible and stable.
    // If calculating world position is needed, use lookAtPoint.
    lookAtNode: character ? character.head : null // Look at the character's head node if available

    // Alternative: Look at calculated point (use if lookAtNode causes issues or head isn't a direct node)
    // lookAtPoint: character ? character.mapPositionToScene(character.head ? character.head.position : Qt.vector3d(0,character.height*0.8,0)) : Qt.vector3d(0,0,-1)

}