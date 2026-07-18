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
VARYING float vStyleId; // constant per segment (same for all 4 quad vertices)

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

    if (roundCap) {
        // Capsule SDF: seamless round caps that also close joint gaps.
        float dist = length(vec2(u - uc, v));
        if (dist > halfW)
            discard;
    } else {
        // Square (butt) caps: reject the longitudinal cap extension.
        if (u < 0.0 || u > segLen || abs(v) > halfW)
            discard;
    }

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
