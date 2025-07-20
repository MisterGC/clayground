// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Canvas3D

BodyPartsGroup {
    id: _arm
    
    // Total arm dimensions
    width: 0.917  // Default: 3.667 * 0.25
    height: 3.667 // Default arm length
    depth: 1.1    // Default: 3.667 * 0.3
    
    // Position is set by parent (Character.qml)

    // Hand dimension aliases
    property alias handWidth: _hand.width
    property alias handHeight: _hand.height
    property alias handDepth: _hand.depth
    
    // Hand color alias
    property alias handColor: _hand.color
    
    // Expose arm parts for animation
    readonly property alias upperArm: _upperArm
    readonly property alias lowerArm: _lowerArm
    readonly property alias hand: _hand
    
    // Upper arm (shoulder to elbow)
    BodyPart {
        id: _upperArm
        width: _arm.width
        height: _arm.height * 0.5  // Upper arm is half of total arm length
        depth: _arm.depth
        color: "#4169e1"  // Default blue color
        
        // Lower arm (elbow to wrist)
        BodyPart {
            id: _lowerArm
            width: _arm.width * 0.9  // Slightly thinner than upper arm
            height: _arm.height * 0.5  // Lower arm is half of total arm length
            depth: _arm.depth * 0.9
            basePos: Qt.vector3d(0, -_upperArm.height, 0)
            color: "#4169e1"  // Default blue color
            
            Hand {
                id: _hand
                basePos: Qt.vector3d(0, -_lowerArm.height, 0)
                width: height * 0.3
                height: _arm.height * 0.5
                depth: height * 0.5

            }
        }
    }
}
