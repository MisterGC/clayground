// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick
import Clayground.Canvas3D

BodyPartsGroup {
    id: _leg
    
    // Total leg dimensions
    width: 1.067  // Default: 5.333 * 0.2
    height: 5.333 // Default leg length
    depth: 1.333  // Default: 5.333 * 0.25
    
    // Position is set by parent (Character.qml)
    
    // Foot dimension aliases
    property alias footWidth: _foot.width
    property alias footHeight: _foot.height
    property alias footDepth: _foot.depth
    
    // Foot color alias
    property alias footColor: _foot.color
    
    // Expose leg parts for animation
    readonly property alias upperLeg: _upperLeg
    readonly property alias lowerLeg: _lowerLeg
    readonly property alias foot: _foot
    
    // Upper leg (hip to knee)
    BodyPartsGroup {
        id: _upperLeg
        width: _leg.width
        height: _leg.height * 0.5  // Upper leg is half of total leg length
        depth: _leg.depth
        
        // Lower leg (knee to ankle)
        BodyPartsGroup {
            id: _lowerLeg
            width: _leg.width * 0.8  // Slightly thinner than upper leg
            height: _leg.height * 0.5  // Lower leg is half of total leg length
            depth: _leg.depth * 0.8
            basePos: Qt.vector3d(0, -_upperLeg.height, 0)
            
            Foot {
                id: _foot
                // Position at ankle with forward offset for natural stance
                basePos: Qt.vector3d(0, -_lowerLeg.height, _lowerLeg.depth * 0.4)
                // Dimensions with default bindings that can be overridden
                width: depth * 0.5
                depth: _leg.height * 0.5
                height: depth * 0.3
            }
        }
    }
}
