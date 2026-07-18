// LineBatch3D fragment shader.
// Shapes each segment into a round- or square-capped ribbon, applies the
// per-line dash pattern and opacity looked up from the style-table texture
// (styleTable), and discards fragments in gaps / outside the cap.
//   styleTable row (sampled by styleId): r = dash length (world units),
//   g = gap length, b = round-cap flag (>=0.5), a = opacity.
//   styleCount = number of style columns in the table.

VARYING vec4 vColor;
VARYING vec2 vUV;   // x = along-axis coordinate, y = across coordinate
VARYING vec2 vCap;  // x = segment length, y = half width
VARYING vec2 vDash; // x = path distance at segment start, y = world segment length
VARYING float vStyleId;   // constant per segment (same for all 4 quad vertices)
VARYING float vCapFlags;  // constant per segment: bit0 = start cap, bit1 = end cap

void MAIN()
{
    float segLen = vCap.x;
    float halfW = vCap.y;
    float u = vUV.x;
    float v = vUV.y;
    float uc = clamp(u, 0.0, segLen);

    // Look up this line's style row (column selected by styleId).
    float col = (vStyleId + 0.5) / max(styleCount, 1.0);
    vec4 style = texture(styleTable, vec2(col, 0.5));
    float dashLen = style.r;
    float gapLen = style.g;
    bool roundCap = style.b >= 0.5;
    float opacity = style.a;

    // Per-end cap flags: an end is rounded only when it is flagged AND the style
    // is round-capped. Interior (non-flagged) ends are flush butt edges (the
    // neighbouring segment's end cap fills the joint), so the joint region is
    // shaded once instead of twice.
    int capFlagsI = int(vCapFlags + 0.5);
    bool startRound = roundCap && ((capFlagsI & 1) != 0);
    bool endRound = roundCap && ((capFlagsI & 2) != 0);

    // Across-axis bound (rectangle body and the capsule's straight part).
    if (abs(v) > halfW)
        discard;

    if (u < 0.0) {
        // Before the segment start: only kept as a rounded start cap.
        if (!startRound || length(vec2(u, v)) > halfW)
            discard;
    } else if (u > segLen) {
        // Past the segment end: only kept as a rounded end cap.
        if (!endRound || length(vec2(u - segLen, v)) > halfW)
            discard;
    }
    // else: within the segment body, already bounded across by |v| <= halfW.

    // Dash pattern, measured in world units continuously along the polyline.
    float period = dashLen + gapLen;
    if (period > 0.0) {
        float alongN = segLen > 1e-6 ? uc / segLen : 0.0;
        float worldDist = vDash.x + alongN * vDash.y;
        float phase = mod(worldDist, period);
        if (phase > dashLen)
            discard;
    }

    FRAGCOLOR = vec4(vColor.rgb, vColor.a * opacity);
}
