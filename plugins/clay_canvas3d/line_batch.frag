// LineBatch3D fragment shader.
// Shapes each segment into a round- or square-capped ribbon and applies the
// per-line style looked up from the style-table texture (styleTable). Legacy
// styles (dash/gap/cap/opacity only) take a verbatim hard-edged path; styles
// that use any of the extended keys (dot/chevron pattern, flow, glow, pulse)
// take the resolution-independent SDF path below.
//   styleTable is styleCount columns wide and 3 rows tall (see
//   LineStyleTextureData::kTableRows). Row 0: dash, gap, capRound, opacity.
//   Row 1: patternId (glyph enum | screen-units bit 8), param0 (triangle
//   base-width fraction, 0 = full width), param1 (reserved), flow.
//   Row 2: glow, pulse, headLength, headWidth (heads are handled in the
//   vertex/fragment arrow path).

VARYING vec4 vColor;
VARYING vec2 vUV;   // x = along-axis coordinate, y = across coordinate
VARYING vec2 vCap;  // x = segment length, y = half width
VARYING vec2 vDash; // x = path distance at segment start, y = world segment length
VARYING float vStyleId;   // constant per segment (same for all 4 quad vertices)
VARYING float vCapFlags;  // constant per segment: bit0 = start cap, bit1 = end cap
VARYING float vScreenScale; // screen pixels per world unit for this segment
VARYING vec2 vHead; // x = arrowhead length (segment-space), y = head half width

// The colour write has to be compiled out of the depth pre-pass.
//
// While a batch casts shadows, its material is OpaquePrePass (see
// LineBatch3D.qml), which is what keeps this snippet running in the layer's
// depth pre-pass so the pre-pass depth is carved by the discards below rather
// than being the raw quad. But that pass has no colour attachment: for an
// Unshaded custom material Qt declares no fragOutput there, and an
// unconditional FRAGCOLOR write fails to compile ("'fragOutput' : undeclared
// identifier") - which silently drops the whole batch. The discards are what
// that pass needs; the colour is not. Every write below is therefore guarded.
// Value test, as always: Qt emits QSSG_ENABLE_DEPTH_PASS as 0 or 1 in every
// variant, so defined() would gate nothing.

const int PATTERN_DASH = 0;
const int PATTERN_DOT = 1;
const int PATTERN_CHEVRON = 2;
const int PATTERN_TRIANGLE = 3;
const int SCREEN_UNITS_BIT = 8;

// Coverage from a signed distance (dist < 0 is inside). aa <= 0 gives a hard
// edge (reproduces the legacy discard); aa > 0 gives a soft falloff of that
// width centred on the boundary (the glow look).
float coverage(float dist, float aa)
{
    if (aa <= 0.0)
        return dist <= 0.0 ? 1.0 : 0.0;
    return clamp(0.5 - dist / aa, 0.0, 1.0);
}

void MAIN()
{
    float segLen = vCap.x;
    float halfW = vCap.y;
    float u = vUV.x;
    float v = vUV.y;
    float uc = clamp(u, 0.0, segLen);

    // Look up this line's style (column selected by styleId, three rows tall).
    float col = (vStyleId + 0.5) / max(styleCount, 1.0);
    vec4 row0 = texture(styleTable, vec2(col, 0.5 / 3.0));
    vec4 row1 = texture(styleTable, vec2(col, 1.5 / 3.0));
    vec4 row2 = texture(styleTable, vec2(col, 2.5 / 3.0));

    float dashLen = row0.r;
    float gapLen = row0.g;
    bool roundCap = row0.b >= 0.5;
    float opacity = row0.a;

    int patternId = int(row1.r + 0.5);
    int glyph = patternId & 7;
    bool screenUnits = (patternId & SCREEN_UNITS_BIT) != 0;
    float param0 = row1.g; // triangle base-width fraction (0 = full ribbon width)
    float flowSpeed = row1.a;
    float glow = row2.r;
    float pulse = row2.g;
    float headWid = row2.a;

    // Per-end cap flags: an end is rounded only when it is flagged AND the style
    // is round-capped. Interior (non-flagged) ends are flush butt edges.
    int capFlagsI = int(vCapFlags + 0.5);
    bool startRound = roundCap && ((capFlagsI & 1) != 0);
    bool endRound = roundCap && ((capFlagsI & 2) != 0);
    bool headActive = (headWid > 0.0) && (capFlagsI == 3);

    bool extended = (glyph != PATTERN_DASH) || (flowSpeed != 0.0)
                    || (glow > 0.0) || (pulse > 0.0) || (headWid > 0.0);

    if (!extended) {
        // --- Legacy path: identical to the pre-v2 shader (hard edges). ---
        if (abs(v) > halfW)
            discard;

        if (u < 0.0) {
            if (!startRound || length(vec2(u, v)) > halfW)
                discard;
        } else if (u > segLen) {
            if (!endRound || length(vec2(u - segLen, v)) > halfW)
                discard;
        }

        float period = dashLen + gapLen;
        if (period > 0.0) {
            float alongN = segLen > 1e-6 ? uc / segLen : 0.0;
            float worldDist = vDash.x + alongN * vDash.y;
            float phase = mod(worldDist, period);
            if (phase > dashLen)
                discard;
        }

#if !QSSG_ENABLE_DEPTH_PASS
        FRAGCOLOR = vec4(vColor.rgb, vColor.a * opacity);
#endif
        return;
    }

    // --- Extended path: SDF coverage, optional soft edges. ---
    float aa = glow > 0.0 ? glow * halfW : 0.0;
    float across = abs(v);

    if (headActive) {
        // Classic triangular arrowhead. A shaft rectangle (half width halfW)
        // meets a wider triangle head (base 2*headHalfW, tip exactly at
        // u == segLen) at a clean shoulder. Both parts carry ~1px edge
        // anti-aliasing that is independent of glow; glow only widens the soft
        // edge on top. vHead is (head length, head half width) in segment space.
        float headLen = vHead.x;
        float headHalfW = vHead.y;
        float headBaseU = segLen - headLen;
        // The shaft overlaps the head up to uMid - the point where the triangle
        // has narrowed to exactly the shaft width - so the shoulder has no seam
        // and the shaft can never poke out past the triangle sides.
        float uMid = segLen - headLen * (halfW / max(headHalfW, 1e-6));

        // ~1px AA expressed in segment-space units (world mode converts through
        // the screen scale), widened to the glow falloff when glow is set.
        float pxToSeg = (widthMode < 0.5) ? 1.0 : 1.0 / max(vScreenScale, 1e-6);
        float aaHead = max(1.3 * pxToSeg, aa);

        // Shaft: rounded/butt-capped rectangle from the start to the crossover.
        float shaftStart;
        if (u < 0.0)
            shaftStart = startRound ? (length(vec2(u, v)) - halfW) : (-u);
        else
            shaftStart = -1e6;
        float shaftDist = max(max(across - halfW, u - uMid), shaftStart);
        float shaftCov = uMid > 0.0 ? coverage(shaftDist, aaHead) : 0.0;

        // Head triangle as an intersection of half-planes: the outward diagonal
        // edge, the flat base (shoulder) and the tip end plane.
        float Le = sqrt(headLen * headLen + headHalfW * headHalfW);
        float invLe = 1.0 / max(Le, 1e-6);
        float dEdge = ((u - headBaseU) * headHalfW
                       + (across - headHalfW) * headLen) * invLe;
        float headDist = max(max(dEdge, headBaseU - u), u - segLen);
        float headCov = coverage(headDist, aaHead);

        float cov = max(shaftCov, headCov);
        // Pulse composes on the head exactly like on the body.
        float pulseMulH = 1.0;
        if (pulse > 0.0) {
            float oscH = 0.5 + 0.5 * sin(flowTime * 3.0);
            pulseMulH = mix(1.0, oscH, pulse);
        }
        float alphaHead = vColor.a * opacity * pulseMulH * cov;
        if (alphaHead < 0.003)
            discard;
#if !QSSG_ENABLE_DEPTH_PASS
        FRAGCOLOR = vec4(vColor.rgb, alphaHead);
#endif
        return;
    }

    // Ribbon + cap coverage (mirrors the legacy discards when aa == 0).
    float bodyCov;
    float patCov = 1.0;
    if (u < 0.0) {
        bodyCov = startRound ? coverage(length(vec2(u, v)) - halfW, aa) : 0.0;
    } else if (u > segLen) {
        bodyCov = endRound ? coverage(length(vec2(u - segLen, v)) - halfW, aa) : 0.0;
    } else {
        bodyCov = coverage(across - halfW, aa);
    }
    if (bodyCov <= 0.0)
        discard;

    // Continuous world distance along the polyline, marched by flow over time.
    float alongN = segLen > 1e-6 ? uc / segLen : 0.0;
    float baseDist = vDash.x + alongN * vDash.y - flowTime * flowSpeed;

    // Move distance and the across coordinate into a common "pattern space" so
    // dots/chevrons keep their proportions. World-units patterns work in world
    // space; screen-units patterns work in screen pixels (zoom-stable).
    float sc = max(vScreenScale, 1e-6);
    float patternDist;
    float vPat;
    float halfWPat;
    if (screenUnits) {
        float k = (widthMode < 0.5) ? 1.0 : sc; // segment space -> screen
        patternDist = baseDist * sc;
        vPat = v * k;
        halfWPat = halfW * k;
    } else {
        float k = (widthMode < 0.5) ? (1.0 / sc) : 1.0; // segment space -> world
        patternDist = baseDist;
        vPat = v * k;
        halfWPat = halfW * k;
    }
    float aaPat = glow > 0.0 ? glow * halfWPat : 0.0;

    float period = dashLen + gapLen;
    if (glyph == PATTERN_DOT) {
        if (period > 0.0) {
            // Round dot (radius = half line width) centred in each period.
            float centerAlong = (floor(patternDist / period) + 0.5) * period;
            float d = length(vec2(patternDist - centerAlong, vPat)) - halfWPat;
            patCov = coverage(d, aaPat);
        }
    } else if (glyph == PATTERN_CHEVRON) {
        if (period > 0.0) {
            // ">" glyph per period, tip toward the path end (start -> end).
            // ALL along-axis geometry derives from the style's dash slot (the
            // glyph length, pattern units); the ribbon width enters only as a
            // normalized across ratio. Width is screen-anchored in Pixel mode,
            // so width-derived along geometry would wrap the period zoomed out,
            // distort mid-zoom, and thin to invisibility zoomed in.
            float local = patternDist - floor(patternDist / period) * period;
            float glyphLen = clamp(dashLen, 1e-3, period * 0.7);
            float across01 = clamp(abs(vPat) / max(halfWPat, 1e-6), 0.0, 1.0);
            float tip = period - 0.5 * glyphLen;
            float lead = tip - across01 * 0.62 * glyphLen;  // arm sweep
            float th = 0.19 * glyphLen;                     // stroke half-thickness
            patCov = coverage(abs(local - lead) - th, aaPat);
        }
    } else if (glyph == PATTERN_TRIANGLE) {
        if (period > 0.0) {
            // Filled isoceles triangle per period, tip toward the path end, base
            // across the ribbon (same direction convention as the chevron). As
            // with the chevron, ALL along-axis geometry derives from the dash
            // slot (pattern units); the ribbon width enters only through the
            // across coordinate, so the glyph stays zoom-stable. param0 is the
            // base-width fraction of the ribbon width (0 -> full width).
            float centerAlong = (floor(patternDist / period) + 0.5) * period;
            float la = patternDist - centerAlong;   // along axis, tip at +halfLen
            float glyphLen = clamp(dashLen, 1e-3, period * 0.7);
            float halfLen = 0.5 * glyphLen;
            float baseFrac = param0 > 0.0 ? param0 : 1.0;
            float baseHalf = baseFrac * halfWPat;    // base half-width (pattern units)
            float ax = abs(vPat);
            // Solid fill from an intersection of half-planes (like the terminal
            // arrowhead): the two slanted edges (base corners -> tip), the base
            // plane and the tip plane.
            float Le = sqrt(glyphLen * glyphLen + baseHalf * baseHalf);
            float invLe = 1.0 / max(Le, 1e-6);
            float dEdge = ((la + halfLen) * baseHalf + (ax - baseHalf) * glyphLen) * invLe;
            float dTri = max(max(dEdge, -halfLen - la), la - halfLen);
            // Always-on ~1px edge AA (pattern units) so the filled edges stay
            // crisp even without glow; widened to the glow falloff when set.
            float pxToPat = screenUnits ? 1.0 : (1.0 / sc);
            float aaTri = max(1.2 * pxToPat, aaPat);
            patCov = coverage(dTri, aaTri);
        }
    } else { // PATTERN_DASH (also the flowing-dash case)
        if (period > 0.0) {
            float local = patternDist - floor(patternDist / period) * period;
            // Soft only when glow is on; otherwise a hard dash cut.
            patCov = coverage(local - dashLen, aaPat);
        }
    }

    // Pulse: opacity oscillation driven by the same flow clock.
    float pulseMul = 1.0;
    if (pulse > 0.0) {
        float osc = 0.5 + 0.5 * sin(flowTime * 3.0);
        pulseMul = mix(1.0, osc, pulse);
    }

    float alpha = vColor.a * opacity * pulseMul * bodyCov * patCov;
    if (alpha < 0.003)
        discard;
#if !QSSG_ENABLE_DEPTH_PASS
    FRAGCOLOR = vec4(vColor.rgb, alpha);
#endif
}
