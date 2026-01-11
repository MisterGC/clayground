// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ParametricCharacter
    \inqmlmodule Clayground.Character3D
    \inherits Character
    \brief Character with high-level parameters for easy customization.

    ParametricCharacter extends Character with intuitive parameters like bodyHeight,
    realism, maturity, femininity, and mass that automatically calculate all body
    part dimensions. This makes it easy to create diverse characters without
    manually setting individual dimensions.

    Example usage:
    \qml
    import Clayground.Character3D

    ParametricCharacter {
        name: "hero"
        bodyHeight: 10.0
        realism: 0.3       // More cartoon-like
        maturity: 0.7      // Adult
        femininity: 0.3    // More masculine
        mass: 0.5          // Average build
        muscle: 0.7        // Athletic
        skin: "#d38d5f"
        topClothing: "#4169e1"
    }
    \endqml
*/
import QtQuick

pragma ComponentBehavior: Bound

Character {
    id: _parametric

    // ============================================================================
    // HIGH-LEVEL BODY PARAMETERS
    // ============================================================================

    /*!
        \qmlproperty real ParametricCharacter::bodyHeight
        \brief Total character height in world units.
    */
    property real bodyHeight: 10.0

    /*!
        \qmlproperty real ParametricCharacter::realism
        \brief Style from cartoon (0) to realistic (1).

        Affects head-to-body ratio and feature sizes.
    */
    property real realism: 0.0

    /*!
        \qmlproperty real ParametricCharacter::maturity
        \brief Age from child (0) to elderly (1).

        Affects body proportions like leg length and head size.
    */
    property real maturity: 0.5

    /*!
        \qmlproperty real ParametricCharacter::femininity
        \brief Build from masculine (0) to feminine (1).

        Affects shoulder/hip ratio and waist definition.
    */
    property real femininity: 0.5

    /*!
        \qmlproperty real ParametricCharacter::mass
        \brief Body mass from thin (0) to heavy (1).
    */
    property real mass: 0.5

    /*!
        \qmlproperty real ParametricCharacter::muscle
        \brief Muscularity from soft (0) to athletic (1).
    */
    property real muscle: 0.5

    // ============================================================================
    // HIGH-LEVEL FACE PARAMETERS
    // ============================================================================

    /*!
        \qmlproperty real ParametricCharacter::faceShape
        \brief Face shape from round (0) to long/angular (1).
    */
    property real faceShape: 0.5

    /*!
        \qmlproperty real ParametricCharacter::chinForm
        \brief Chin from round (0) to pointed (1).
    */
    property real chinForm: 0.5

    /*!
        \qmlproperty real ParametricCharacter::eyes
        \brief Eye size multiplier (0.5-1.5).
    */
    property real eyes: 1.0

    /*!
        \qmlproperty real ParametricCharacter::nose
        \brief Nose size multiplier (0.5-1.5).
    */
    property real nose: 1.0

    /*!
        \qmlproperty real ParametricCharacter::mouth
        \brief Mouth size multiplier (0.5-1.5).
    */
    property real mouth: 1.0

    /*!
        \qmlproperty real ParametricCharacter::hair
        \brief Hair volume (0 = bald, 1 = full).
    */
    property real hair: 1.0

    // ============================================================================
    // COLOR PALETTE
    // ============================================================================

    /*!
        \qmlproperty color ParametricCharacter::skin
        \brief Skin color.
    */
    property color skin: "#d38d5f"

    /*!
        \qmlproperty color ParametricCharacter::hairTone
        \brief Hair color.
    */
    property color hairTone: "#734120"

    /*!
        \qmlproperty color ParametricCharacter::eyeTone
        \brief Eye color.
    */
    property color eyeTone: "#4a3728"

    /*!
        \qmlproperty color ParametricCharacter::topClothing
        \brief Color for torso and arms.
    */
    property color topClothing: "#4169e1"

    /*!
        \qmlproperty color ParametricCharacter::bottomClothing
        \brief Color for hips and legs.
    */
    property color bottomClothing: "#708090"

    // ============================================================================
    // DERIVED CALCULATIONS
    // ============================================================================

    // Helper function: linear interpolation
    function lerp(a: real, b: real, t: real): real {
        return a + (b - a) * Math.max(0, Math.min(1, t));
    }

    // Heads tall ratio (how many head heights fit in body)
    // Cartoon: 4-6 heads, Realistic: 6-8 heads
    // Children: fewer heads tall, Adults: more heads tall
    readonly property real _headsTall: {
        const cartoonChild = 4.0;
        const cartoonAdult = 5.5;
        const realisticChild = 5.5;
        const realisticAdult = 7.5;

        const cartoonHeads = lerp(cartoonChild, cartoonAdult, maturity);
        const realisticHeads = lerp(realisticChild, realisticAdult, maturity);
        return lerp(cartoonHeads, realisticHeads, realism);
    }

    // Head dimensions derived from headsTall
    readonly property real _headSize: bodyHeight / _headsTall

    // Shoulder to hip ratio
    // Masculine: broader shoulders, Feminine: broader hips
    readonly property real _shoulderHipRatio: lerp(0.85, 1.35, 1.0 - femininity)

    // Waist definition (narrower = more defined)
    // Affected by femininity (more = narrower), mass (more = wider), muscle (more = narrower/V-shape)
    readonly property real _waistRatio: {
        const base = lerp(0.7, 0.95, femininity * 0.5 + (1.0 - muscle) * 0.5);
        return lerp(base, 1.0, mass * 0.5);
    }

    // Overall body width multiplier
    readonly property real _widthMultiplier: lerp(0.7, 1.3, mass * 0.6 + muscle * 0.4)

    // Limb proportions affected by maturity
    // Children have shorter legs relative to torso
    readonly property real _legToBodyRatio: lerp(0.42, 0.48, maturity)
    readonly property real _armToTorsoRatio: lerp(0.9, 1.1, maturity)

    // Neck length affected by maturity and mass
    readonly property real _neckRatio: lerp(0.15, 0.25, maturity) * lerp(1.0, 0.7, mass)

    // Feature sizes affected by realism (cartoon = bigger features)
    readonly property real _eyeSizeMultiplier: eyes * lerp(1.3, 0.9, realism)
    readonly property real _noseSizeMultiplier: nose * lerp(0.8, 1.1, realism)

    // ============================================================================
    // APPLY DERIVED VALUES TO CHARACTER
    // ============================================================================

    // Head dimensions
    upperHeadWidth: _headSize * 0.9 * lerp(1.0, 0.85, faceShape)
    upperHeadHeight: _headSize * 0.6
    upperHeadDepth: _headSize * 0.9
    lowerHeadWidth: _headSize * 0.85 * lerp(1.0, 0.9, faceShape)
    lowerHeadHeight: _headSize * 0.4 * lerp(0.8, 1.2, faceShape)
    lowerHeadDepth: _headSize * 0.85
    neckHeight: _headSize * _neckRatio
    chinPointiness: lerp(0.6, 1.0, chinForm)

    // Face features
    eyeSize: _eyeSizeMultiplier
    noseSize: _noseSizeMultiplier
    mouthSize: mouth
    hairVolume: hair

    // Torso dimensions
    shoulderWidth: _headSize * 1.8 * _shoulderHipRatio * _widthMultiplier * lerp(1.0, 1.15, muscle)
    torsoHeight: _headSize * 2.0 * lerp(0.9, 1.1, maturity)
    torsoDepth: _headSize * 0.7 * _widthMultiplier
    waistWidth: shoulderWidth * _waistRatio

    // Hip dimensions
    hipWidth: _headSize * 1.6 * (1.0 / _shoulderHipRatio) * _widthMultiplier
    hipHeight: _headSize * 0.6
    hipDepth: torsoDepth

    // Arm dimensions
    armWidth: _headSize * 0.35 * _widthMultiplier * lerp(0.85, 1.15, muscle)
    armHeight: torsoHeight * _armToTorsoRatio
    armDepth: armWidth * 1.1

    // Leg dimensions
    legWidth: _headSize * 0.45 * _widthMultiplier * lerp(0.9, 1.1, muscle)
    legHeight: bodyHeight * _legToBodyRatio
    legDepth: legWidth * 1.2

    // Movement properties are now derived from leg animation geometry
    // walkSpeed and strideLength are calculated in WalkAnim based on leg swing angles

    // Colors
    skinColor: skin
    hairColor: hairTone
    eyeColor: eyeTone
    torsoColor: topClothing
    armColor: topClothing
    hipColor: bottomClothing
    legColor: bottomClothing
    handColor: skin
    footColor: skin  // Changed from bottomClothing to make feet visible for debugging
}
