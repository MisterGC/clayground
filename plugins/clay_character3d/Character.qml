// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick
import Clayground.Canvas3D
import Clayground.Storage

pragma ComponentBehavior: Bound

BodyPartsGroup {
    id: _character

    // TODO: Describe what this nodes positions means

    property string name: "unknown"

    // Configure animations (e.g. to adapt based on movement
    // speed)
    //property alias walkCycleDuration: _walkAnim.duration
    //property alias idleCycleDuration: _idleAnim.duration

    // TODO: Adapt on demand
    width: Math.max(shoulderWidth, waistWidth, hipWidth)
    height: 10.667 // Default total height (will be recalculated if parts change)
    depth: 10

    Box3D {
        visible: false
        height: _character.height
        width: _character.width
        depth: _character.depth
        color: "orange"
        opacity: 0.3
    }

    // Absolute dimensions - these can be set directly
    // or calculated by a specialized component like RatioBasedCharacter

    // Head
    property real neckHeight: 0.333 // Default based on headHeight, neckHeightToHeadHeight 0.25

    // Head height ~1.333 Default based on bodyHeight ≈10, headsTall ≈7.5
    // Head width 1.0, based on headHeight, headWidthToHeadHeight 0.75
    // Head depth 1.20, based on headWidth, headDepthToHeadWidth 1.0 (approx)
    readonly property real headHeight: upperHeadHeight + lowerHeadHeight


    // Torso
    property real shoulderWidth: 2.50 // Default based on headWidth, shoulderWidthToHeadWidth ≈2.5
    property real waistWidth: 2.00 // Default based on shoulderWidth, waistWidthToShoulderWidth ≈0.8
    property real hipWidth: 2.25 // Default based on shoulderWidth, hipWidthToShoulderWidth ≈0.9

    // Legacy properties for default calculations only
    // These are used internally for backward compatibility but should not be set directly
    property real handLength: 1.137 // Used for default hand dimensions
    property real footLength: 1.60 // Used for default foot dimensions

    // Actions/Activities
    enum Activity {
        Walking,
        Idle
    }
    property int activity: Character.Activity.Idle
    property alias faceActivity: _head.activity
    //property alias thoughts: _head.thoughts

    // Colors for each body part
    property alias headSkinColor: _head.skinColor
    property alias headHairColor: _head.hairColor
    property alias torsoColor: _torso.color
    property alias handColor: _rightArm.handColor
    // property alias footColor: _rightLeg.footColor
    
    // Dimension aliases for full control
    // Note: torsoWidth is an alias to shoulderWidth for consistency
    property alias torsoWidth: _character.shoulderWidth
    property alias torsoHeight: _torso.height
    property alias torsoDepth: _torso.depth
    
    // Head dimension aliases
    property alias upperHeadWidth: _head.upperHeadWidth
    property alias upperHeadHeight: _head.upperHeadHeight
    property alias upperHeadDepth: _head.upperHeadDepth
    property alias lowerHeadWidth: _head.lowerHeadWidth
    property alias lowerHeadHeight: _head.lowerHeadHeight
    property alias lowerHeadDepth: _head.lowerHeadDepth
    property alias chinPointiness: _head.chinPointiness

    // Arms (symmetric - right arm drives both)
    property alias armWidth: _rightArm.width
    property alias armHeight: _rightArm.height
    property alias armDepth: _rightArm.depth
    
    // Hands (symmetric - accessed through arm)
    property alias handWidth: _rightArm.handWidth
    property alias handHeight: _rightArm.handHeight
    property alias handDepth: _rightArm.handDepth
    
    // Legs (symmetric)
    property alias legWidth: _rightLeg.width
    property alias legHeight: _rightLeg.height
    property alias legDepth: _rightLeg.depth
    
    // Feet (symmetric - accessed through leg)
    property alias footWidth: _rightLeg.footWidth
    property alias footHeight: _rightLeg.footHeight
    property alias footDepth: _rightLeg.footDepth

    // Body Parts (e.g. for animating them)
    // and their base (relative) positions
    readonly property Arm leftArm: _leftArm
    readonly property Arm rightArm: _rightArm
    readonly property Leg leftLeg: _leftLeg
    readonly property Leg rightLeg: _rightLeg
    readonly property Head head: _head

    BodyPart {
        id: _torso

        width: _character.shoulderWidth
        height: 3.667 // Default torso height
        depth: 1.25 // Default torso depth
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(_character.hipWidth/_character.shoulderWidth, 1)
        basePos: Qt.vector3d(0, 5.333, 0) // Default leg height

        Head {
            id: _head
            basePos:  Qt.vector3d(0, (_torso.height + _character.neckHeight), 0)
        }

        // Arms (containing hands)
        Arm {
            id: _rightArm
            basePos: Qt.vector3d(_character.shoulderWidth * 0.5, 0, 0)
        }

        Arm {
            id: _leftArm
            basePos: Qt.vector3d(-_character.shoulderWidth * 0.5, 0, 0)

            // Mirror right arm dimensions
            width: _rightArm.width
            height: _rightArm.height
            depth: _rightArm.depth

            // Mirror hand dimensions and color
            handWidth: _rightArm.handWidth
            handHeight: _rightArm.handHeight
            handDepth: _rightArm.handDepth
            handColor: _rightArm.handColor
        }

        // // Legs (containing feet)
        Leg {
            id: _rightLeg
            basePos: Qt.vector3d(_character.hipWidth * 0.4, -_torso.height, 0)
        }
        Leg {
            id: _leftLeg
            basePos: Qt.vector3d(-_character.hipWidth * 0.4, -_torso.height, 0)
            // Mirror right leg dimensions
            width: _rightLeg.width
            height: _rightLeg.height
            depth: _rightLeg.depth
            // Mirror foot dimensions and color
            footWidth: _rightLeg.footWidth
            footHeight: _rightLeg.footHeight
            footDepth: _rightLeg.footDepth
            footColor: _rightLeg.footColor
        }
    }

    WalkAnim {
        id: _walkAnim
        entity: _character
        duration: 1000
        footForwardOffset: 0.4 * _rightLeg.height
        footMaxRotation: 45
        handMaxRotation: 30
        running: _character.activity == Character.Activity.Walking
        loops: Animation.Infinite
    }

    IdleAnim {
        id: _idleAnim
        entity: _character
        duration: 1000
        running: _character.activity == Character.Activity.Idle
        loops: 1
    }

    KeyValueStore {
        id: _keyValueStore
        name: "CharacterConfigStore"
    }

    // Save the current character configuration to the key-value store
    // function saveConfig() {
    //     // Generate a key based on character name to allow multiple character configs
    //     const configKey = "character_config_" + name;

    //     // Collect all character properties
    //     let config = {
    //         // Head properties
    //         upperHeadHeight: upperHeadHeight,
    //         upperHeadWidth: upperHeadWidth,
    //         upperHeadDepth: upperHeadDepth,
    //         lowerHeadHeight: lowerHeadHeight,
    //         lowerHeadWidth: lowerHeadWidth,
    //         lowerHeadDepth: lowerHeadDepth,
    //         chinPointiness: chinPointiness,
    //         neckHeight: neckHeight,
    //         headSkinColor: headSkinColor,
    //         headHairColor: headHairColor,

    //         // Torso properties
    //         shoulderWidth: shoulderWidth,
    //         waistWidth: waistWidth,
    //         hipWidth: hipWidth,
    //         torsoHeight: torsoHeight,
    //         torsoDepth: torsoDepth,
    //         torsoColor: torsoColor,

    //         // Limb properties (keep legacy for compatibility)
    //         handLength: handLength,
    //         footLength: footLength,
    //         handColor: handColor,
    //         footColor: footColor,
            
    //         // New dimension properties
    //         armWidth: armWidth,
    //         armHeight: armHeight,
    //         armDepth: armDepth,
    //         handWidth: handWidth,
    //         handHeight: handHeight,
    //         handDepth: handDepth,
    //         legWidth: legWidth,
    //         legHeight: legHeight,
    //         legDepth: legDepth,
    //         footWidth: footWidth,
    //         footHeight: footHeight,
    //         footDepth: footDepth
    //     };

    //     // Convert to JSON string and save to store
    //     const configJson = JSON.stringify(config);
    //     _keyValueStore.set(configKey, configJson);

    //     console.log("Character configuration saved for: " + name);
    //     return true;
    // }

    // // Load and apply a saved configuration from the key-value store
    // function loadConfig() {
    //     // Generate the key based on character name
    //     const configKey = "character_config_" + name;

    //     // Check if configuration exists
    //     if (_keyValueStore.has(configKey)) {
    //         try {
    //             // Get the saved JSON string
    //             const configJson = _keyValueStore.get(configKey);
    //             const config = JSON.parse(configJson);

    //             // Apply all properties to the character
    //             for (let prop in config) {
    //                 if (_character.hasOwnProperty(prop)) {
    //                     _character[prop] = config[prop];
    //                 }
    //             }

    //             console.log("Character configuration loaded for: " + name);
    //             return true;
    //         } catch (e) {
    //             console.error("Error loading character configuration: " + e);
    //             return false;
    //         }
    //     } else {
    //         console.log("No saved configuration found for character: " + name);
    //         return false;
    //     }
    // }
}
