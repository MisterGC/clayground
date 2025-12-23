// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

pragma ComponentBehavior: Bound

Character {
    id: _parametric

    // ============================================================================
    // HIGH-LEVEL BODY PARAMETERS
    // ============================================================================

    // Overall scale in world units
    property real bodyHeight: 10.0

    // Style: cartoon vs realistic (affects head-to-body ratio, feature sizes)
    property real realism: 0.0        // 0.0 = cartoon, 1.0 = realistic

    // Age: affects proportions (head size, limb length, torso)
    property real maturity: 0.5       // 0.0 = child, 0.5 = young adult, 1.0 = elderly

    // Build: shoulder/hip ratio, waist definition
    property real femininity: 0.5     // 0.0 = masculine, 0.5 = neutral, 1.0 = feminine

    // Body mass: affects width/thickness of all parts
    property real mass: 0.5           // 0.0 = thin, 0.5 = average, 1.0 = heavy

    // Muscularity: V-shape, shoulder breadth, limb definition
    property real muscle: 0.5         // 0.0 = soft, 0.5 = average, 1.0 = athletic

    // ============================================================================
    // HIGH-LEVEL FACE PARAMETERS
    // ============================================================================

    // Face shape
    property real faceShape: 0.5      // 0.0 = round, 1.0 = long/angular
    property real chinForm: 0.5       // 0.0 = round, 1.0 = pointed

    // Feature sizes (multipliers)
    property real eyes: 1.0           // 0.5 = small, 1.5 = large
    property real nose: 1.0           // 0.5 = small, 1.5 = prominent
    property real mouth: 1.0          // 0.5 = small, 1.5 = wide
    property real hair: 1.0           // 0.0 = bald, 1.0 = full

    // ============================================================================
    // COLOR PALETTE
    // ============================================================================

    property color skin: "#d38d5f"
    property color hairTone: "#734120"
    property color eyeTone: "#4a3728"
    property color topClothing: "#4169e1"
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
