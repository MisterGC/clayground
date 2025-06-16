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
    property alias walkCycleDuration: _walkAnim.duration
    property alias idleCycleDuration: _idleAnim.duration

    // TODO: Adapt on demand
    width: Math.max(shoulderWidth, waistWidth, hipWidth)
    height: lowerHeadHeight + upperHeadHeight + neckHeight + torsoHeight + legLength
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

    // Upper Head Properties
    property real upperHeadWidth: 1.00
    property real upperHeadHeight: 0.8
    property real upperHeadDepth: 1.20

    // Lower Head Properties
    property real lowerHeadWidth: 1.00
    property real lowerHeadHeight: 0.5
    property real lowerHeadDepth: 1.20
    property real chinPointiness: 1.0

    // Torso
    property real shoulderWidth: 2.50 // Default based on headWidth, shoulderWidthToHeadWidth ≈2.5
    property real waistWidth: 2.00 // Default based on shoulderWidth, waistWidthToShoulderWidth ≈0.8
    property real hipWidth: 2.25 // Default based on shoulderWidth, hipWidthToShoulderWidth ≈0.9
    property real torsoHeight: 3.667 // Default based on headHeight, torsoHeightToHeadHeight 2.75
    property real torsoDepth: 1.25 // Default based on shoulderWidth, shoulderWidthToTorsoDepth 0.5

    // Arms and Hands
    property real armLength: 3.667 // Default based on torsoHeight, armLengthToTorsoHeight 1.0
    property real handLength: 1.137 // Default based on armLength, handLengthToArmLength ≈0.31

    // Legs and Feet
    property real legLength: 5.333 // Default based on headHeight, legLengthToHeadHeight 4.0
    property real footLength: 1.60 // Default based on bodyHeight ≈10.67, footLengthToBodyHeight 0.15

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
    property color handsColor: "#d38d5f"
    property color feetColor: "#d38d5f"

    // Body Parts (e.g. for animating them)
    // and their base (relative) positions
    readonly property Hand leftHand: _leftHand
    readonly property Hand rightHand: _rightHand
    readonly property Foot leftFoot: _leftFoot
    readonly property Foot rightFoot: _rightFoot
    readonly property Head head: _head

    BodyPart {
        id: _torso

        width: _character.shoulderWidth; depth: _character.torsoDepth; height: _character.torsoHeight
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(_character.hipWidth/_character.shoulderWidth, 1)
        basePos: Qt.vector3d(0, _character.legLength, 0)

        Head {
            id: _head
            basePos:  Qt.vector3d(0, (_character.torsoHeight + _character.neckHeight), 0)
            lowerHeadWidth: _character.lowerHeadWidth
            lowerHeadHeight: _character.lowerHeadHeight
            lowerHeadDepth: _character.lowerHeadDepth
            upperHeadWidth: _character.upperHeadWidth
            upperHeadHeight: _character.upperHeadHeight
            upperHeadDepth: _character.upperHeadDepth
            chinPointiness: _character.chinPointiness
        }

        // Hands
        Hand {id: _rightHand; character: _character; left: false}
        Hand {id: _leftHand; character: _character; left: true}

        // Feet
        Foot {id: _rightFoot;  character: _character;  left: false}
        Foot {id: _leftFoot; character: _character; left: true }
    }

    WalkAnim {
        id: _walkAnim
        entity: _character
        duration: 1000
        footForwardOffset: 0.4 * _character.legLength
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
    function saveConfig() {
        // Generate a key based on character name to allow multiple character configs
        const configKey = "character_config_" + name;

        // Collect all character properties
        let config = {
            // Head properties
            upperHeadHeight: upperHeadHeight,
            upperHeadWidth: upperHeadWidth,
            upperHeadDepth: upperHeadDepth,
            lowerHeadHeight: lowerHeadHeight,
            lowerHeadWidth: lowerHeadWidth,
            lowerHeadDepth: lowerHeadDepth,
            chinPointiness: chinPointiness,
            neckHeight: neckHeight,
            headSkinColor: headSkinColor,
            headHairColor: headHairColor,

            // Torso properties
            shoulderWidth: shoulderWidth,
            waistWidth: waistWidth,
            hipWidth: hipWidth,
            torsoHeight: torsoHeight,
            torsoDepth: torsoDepth,
            torsoColor: torsoColor,

            // Limb properties
            armLength: armLength,
            handLength: handLength,
            legLength: legLength,
            footLength: footLength,
            handsColor: handsColor,
            feetColor: feetColor
        };

        // Convert to JSON string and save to store
        const configJson = JSON.stringify(config);
        _keyValueStore.set(configKey, configJson);

        console.log("Character configuration saved for: " + name);
        return true;
    }

    // Load and apply a saved configuration from the key-value store
    function loadConfig() {
        // Generate the key based on character name
        const configKey = "character_config_" + name;

        // Check if configuration exists
        if (_keyValueStore.has(configKey)) {
            try {
                // Get the saved JSON string
                const configJson = _keyValueStore.get(configKey);
                const config = JSON.parse(configJson);

                // Apply all properties to the character
                for (let prop in config) {
                    if (_character.hasOwnProperty(prop)) {
                        _character[prop] = config[prop];
                    }
                }

                console.log("Character configuration loaded for: " + name);
                return true;
            } catch (e) {
                console.error("Error loading character configuration: " + e);
                return false;
            }
        } else {
            console.log("No saved configuration found for character: " + name);
            return false;
        }
    }
}
