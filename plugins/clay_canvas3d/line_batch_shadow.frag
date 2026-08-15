// LineBatch3D shadow-caster fragment shader.
//
// The twin material that lets a flat, world-width batch drop a shadow. The
// visible material is Unshaded: it does run in the shadow map render, but
// Qt's shader generator skips the pass's depth-output logic for unshaded
// materials, so its fragment colour would land in the map as garbage depth.
// This twin is Shaded, which makes Qt generate the proper shadow-pass
// fragment stage around it.
//
// This MAIN carves the shadow silhouette. That is only possible because the
// twin's material is depthDrawMode: Material.OpaquePrePassDepthDraw. Qt's
// shader generator treats an OpaquePrePass renderable in the ortho and
// perspective shadow passes as needing a real base colour (the mechanism that
// gives alpha-tested foliage perforated shadows), which has two consequences
// the plain path does not have:
//
//   1. The generated shadow fragment calls qt_customMain, i.e. this snippet,
//      before it writes fragOutput = vec4(qt_shadowDepth). Whatever this
//      discards is punched out of the shadow map.
//   2. rhiPrepareResourcesForShadowMap calls addOpaqueDepthPrePassBindings
//      with isCustomMaterialMeshSubset, which binds EVERY custom property
//      texture of the material - styleTable included - for the vertex AND the
//      fragment stage (RENDERER_VISIBILITY_ALL). So the style table can be
//      sampled here and in line_batch.vert, exactly like in the visible pass.
//
// So the shadow is the same shape as the line: dash gaps, dot/chevron/triangle
// glyphs, square vs round caps and arrowheads all cut it. Edges are hard here
// (no anti-aliasing, no glow falloff): a shadow map stores depth, not
// coverage, and the map's own filtering softens the result anyway.
//
// Alpha, on the other hand, does NOT cut it. Qt appends its own alpha test
// after this snippet - "if (qt_diffuseColor.a * qt_objectOpacity < 1.0)
// discard" - with qt_diffuseColor = BASE_COLOR * VAR_COLOR, and VAR_COLOR
// carries the per-line instance colour. BASE_COLOR below divides that alpha
// back out, so a semi-transparent line still casts its full silhouette instead
// of silently losing its shadow at alpha 0.99.

// Must mirror the vertex shader's set: Qt links the two VARYING blocks
// together, so the declarations have to agree.
VARYING vec4 vColor;
VARYING vec2 vUV;   // x = along-axis coordinate, y = across coordinate
VARYING vec2 vCap;  // x = segment length, y = half width
VARYING vec2 vDash; // x = path distance at segment start, y = world segment length
VARYING float vStyleId;   // constant per segment
VARYING float vCapFlags;  // constant per segment: bit0 = start cap, bit1 = end cap
VARYING float vScreenScale; // screen pixels per world unit for this segment
VARYING vec2 vHead; // x = arrowhead length (segment-space), y = head half width

const int PATTERN_DASH = 0;
const int PATTERN_DOT = 1;
const int PATTERN_CHEVRON = 2;
const int PATTERN_TRIANGLE = 3;
const int SCREEN_UNITS_BIT = 8;

void MAIN()
{
    // These must be VALUE tests: Qt emits every pass macro in every variant as
    // "#define QSSG_ENABLE_..._SHADOW_PASS 0" or "... 1", so defined() is true
    // in all of them and would gate nothing.
#if QSSG_ENABLE_ORTHO_SHADOW_PASS || QSSG_ENABLE_PERSPECTIVE_SHADOW_PASS
    float segLen = vCap.x;
    float halfW = vCap.y;
    float u = vUV.x;
    float v = vUV.y;
    float uc = clamp(u, 0.0, segLen);
    float across = abs(v);

    // Same style lookup as line_batch.frag (styleCount columns, 3 rows).
    float col = (vStyleId + 0.5) / max(styleCount, 1.0);
    vec4 row0 = texture(styleTable, vec2(col, 0.5 / 3.0));
    vec4 row1 = texture(styleTable, vec2(col, 1.5 / 3.0));
    vec4 row2 = texture(styleTable, vec2(col, 2.5 / 3.0));

    float dashLen = row0.r;
    float gapLen = row0.g;
    bool roundCap = row0.b >= 0.5;

    int patternId = int(row1.r + 0.5);
    int glyph = patternId & 7;
    bool screenUnits = (patternId & SCREEN_UNITS_BIT) != 0;
    float param0 = row1.g;   // triangle base-width fraction (0 = full width)
    float flowSpeed = row1.a;
    float headWid = row2.a;

    int capFlagsI = int(vCapFlags + 0.5);
    bool startRound = roundCap && ((capFlagsI & 1) != 0);
    bool endRound = roundCap && ((capFlagsI & 2) != 0);
    bool headActive = (headWid > 0.0) && (capFlagsI == 3);

    if (headActive) {
        // Shaft rectangle meeting a wider triangle head, the hard-edged twin of
        // the arrow path in line_batch.frag. vHead is (head length, head half
        // width) in segment space, already scaled to short segments there.
        float headLen = vHead.x;
        float headHalfW = vHead.y;
        float headBaseU = segLen - headLen;
        // The shaft runs to the point where the triangle has narrowed to the
        // shaft width, so the two parts meet without a seam or an overhang.
        float uMid = segLen - headLen * (halfW / max(headHalfW, 1e-6));

        float shaftStart;
        if (u < 0.0)
            shaftStart = startRound ? (length(vec2(u, v)) - halfW) : (-u);
        else
            shaftStart = -1e6;
        float shaftDist = max(max(across - halfW, u - uMid), shaftStart);
        bool inShaft = (uMid > 0.0) && (shaftDist <= 0.0);

        float Le = sqrt(headLen * headLen + headHalfW * headHalfW);
        float dEdge = ((u - headBaseU) * headHalfW
                       + (across - headHalfW) * headLen) / max(Le, 1e-6);
        bool inHead = max(max(dEdge, headBaseU - u), u - segLen) <= 0.0;

        if (!inShaft && !inHead)
            discard;
    } else {
        // Ribbon body with per-end caps (round only where the end is flagged
        // AND the style is round-capped; other ends are flush butt edges).
        bool inBody;
        if (u < 0.0)
            inBody = startRound && (length(vec2(u, v)) <= halfW);
        else if (u > segLen)
            inBody = endRound && (length(vec2(u - segLen, v)) <= halfW);
        else
            inBody = across <= halfW;
        if (!inBody)
            discard;

        // Continuous world distance along the polyline, marched by flow so a
        // moving pattern's shadow moves with it.
        float baseDist = vDash.x
                       + (segLen > 1e-6 ? uc / segLen : 0.0) * vDash.y
                       - flowTime * flowSpeed;

        // Pattern space, mirroring line_batch.frag. A screen-units pattern has
        // no view-independent period, so in the shadow pass it resolves against
        // the light's projection rather than the camera's - the one place where
        // the shadow's pattern can drift from the drawn one.
        float sc = max(vScreenScale, 1e-6);
        float patternDist;
        float vPat;
        float halfWPat;
        if (screenUnits) {
            float k = (widthMode < 0.5) ? 1.0 : sc;
            patternDist = baseDist * sc;
            vPat = v * k;
            halfWPat = halfW * k;
        } else {
            float k = (widthMode < 0.5) ? (1.0 / sc) : 1.0;
            patternDist = baseDist;
            vPat = v * k;
            halfWPat = halfW * k;
        }

        float period = dashLen + gapLen;
        if (period > 0.0) {
            bool keep = true;
            if (glyph == PATTERN_DOT) {
                float centerAlong = (floor(patternDist / period) + 0.5) * period;
                keep = length(vec2(patternDist - centerAlong, vPat)) <= halfWPat;
            } else if (glyph == PATTERN_CHEVRON) {
                float local = patternDist - floor(patternDist / period) * period;
                float glyphLen = clamp(dashLen, 1e-3, period * 0.7);
                float across01 = clamp(abs(vPat) / max(halfWPat, 1e-6), 0.0, 1.0);
                float tip = period - 0.5 * glyphLen;
                float lead = tip - across01 * 0.62 * glyphLen;
                keep = abs(local - lead) <= 0.19 * glyphLen;
            } else if (glyph == PATTERN_TRIANGLE) {
                float centerAlong = (floor(patternDist / period) + 0.5) * period;
                float la = patternDist - centerAlong;
                float glyphLen = clamp(dashLen, 1e-3, period * 0.7);
                float halfLen = 0.5 * glyphLen;
                float baseFrac = param0 > 0.0 ? param0 : 1.0;
                float baseHalf = baseFrac * halfWPat;
                float Le = sqrt(glyphLen * glyphLen + baseHalf * baseHalf);
                float dEdge = ((la + halfLen) * baseHalf
                               + (abs(vPat) - baseHalf) * glyphLen) / max(Le, 1e-6);
                keep = max(max(dEdge, -halfLen - la), la - halfLen) <= 0.0;
            } else { // PATTERN_DASH, also the flowing-dash case
                float local = patternDist - floor(patternDist / period) * period;
                keep = local <= dashLen;
            }
            if (!keep)
                discard;
        }
    }
#endif

    // Divide VAR_COLOR (the per-line instance colour) back out so Qt's own
    // alpha test - see the header - sees exactly 1 and keeps every fragment
    // this MAIN did not discard. Doing it here rather than by writing COLOR in
    // line_batch.vert matters: that shader is shared with the visible material,
    // and touching VAR_COLOR there changes the shader key of an Unshaded custom
    // material in a way that makes its fragment stage read the wrong varying
    // (lines come out in another line's colour). Confined to this Shaded twin
    // it is harmless. Outside the shadow passes the vertex shader has already
    // collapsed the twin to a clipped point, so the surface itself is kept
    // inert: it could never contribute light even if it were rasterized.
    BASE_COLOR = vec4(0.0, 0.0, 0.0, 1.0 / max(VAR_COLOR.a, 1e-3));
    EMISSIVE_COLOR = vec3(0.0);
    METALNESS = 0.0;
    ROUGHNESS = 1.0;
}
