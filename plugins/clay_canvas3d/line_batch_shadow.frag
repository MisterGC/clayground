// LineBatch3D shadow-caster fragment shader.
//
// The twin material that lets a flat, world-width batch drop a shadow. The
// visible material is Unshaded, and Qt skips unshaded custom materials in the
// shadow pass, so a batch could never cast one; this material is Shaded, which
// puts it in the pass, and it shares line_batch.vert so its silhouette is the
// same ribbon the eye sees.
//
// It only ever runs in the shadow pass - line_batch.vert collapses it to a
// clipped point everywhere else - so all this has to do is carve the ribbon out
// of its quad and let the depth write happen.
//
// What it deliberately does NOT reproduce: dash gaps, glyph patterns and
// arrowheads. Those live in the style table and cut the visible line, not its
// shadow, so a dashed line casts a continuous one. Restoring them would mean
// duplicating the whole pattern pipeline for a silhouette that is usually
// blurred by the shadow map anyway.

// Must mirror the vertex shader's set: Qt links the two VARYING blocks
// together, so the declarations have to agree even where unused here.
VARYING vec4 vColor;
VARYING vec2 vUV;   // x = along-axis coordinate, y = across coordinate
VARYING vec2 vCap;  // x = segment length, y = half width
VARYING vec2 vDash;
VARYING float vStyleId;
VARYING float vCapFlags;
VARYING float vScreenScale;
VARYING vec2 vHead;

void MAIN()
{
    float segLen = vCap.x;
    float halfW = vCap.y;
    float u = vUV.x;
    float v = vUV.y;

    // Round vs square caps is the one style property that changes the
    // silhouette, so it is the one worth a texture fetch here (row 0, blue).
    float col = (vStyleId + 0.5) / max(styleCount, 1.0);
    bool roundCap = texture(styleTable, vec2(col, 0.5 / 3.0)).b >= 0.5;

    int capFlagsI = int(vCapFlags + 0.5);
    bool startRound = roundCap && (capFlagsI & 1) != 0;
    bool endRound = roundCap && (capFlagsI & 2) != 0;

    // The same capsule the visible shader shades, with a hard edge: a shadow
    // has no use for the anti-aliased falloff.
    bool inside;
    if (u < 0.0)
        inside = startRound && length(vec2(u, v)) <= halfW;
    else if (u > segLen)
        inside = endRound && length(vec2(u - segLen, v)) <= halfW;
    else
        inside = abs(v) <= halfW;

    if (!inside)
        discard;

    // The shadow pass reads depth, not colour; keep the surface inert so this
    // material can never contribute light if it is ever rasterized.
    BASE_COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    EMISSIVE_COLOR = vec3(0.0);
    METALNESS = 0.0;
    ROUGHNESS = 1.0;
}
