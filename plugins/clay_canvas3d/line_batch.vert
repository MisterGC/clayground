// LineBatch3D vertex shader.
// Expands one instanced unit quad per line segment into a camera-facing
// ribbon with round caps. The base quad vertex carries the segment
// parameter t (VERTEX.x, 0 = start, 1 = end) and the side factor
// (VERTEX.y, -1 or +1). Per-line style rides in the instance attributes:
//   INSTANCE_COLOR      = line color
//   INSTANCE_DATA.x     = line width (pixels in Pixel mode, world in World mode)
//   INSTANCE_DATA.y     = styleId (row in the style-table texture)
//   INSTANCE_DATA.z     = accumulated path distance at this segment's start
// Material uniforms (bound from LineBatch3D):
//   viewportSize        = View3D pixel size (vec2)
//   widthMode           = 0.0 -> Pixel width, 1.0 -> World width
//   orientationMode     = 0.0 -> Billboard (face camera), 1.0 -> Flat (world +Y
//                         plane); World width only, ignored in Pixel mode
//   depthBias           = pulls the line toward the camera to win z-fights
//   depthJitter         = 1.0 in opaque mode -> tiny per-instance depth offset
//                         (deterministic table-order tie-break for coplanar
//                          lines), 0.0 otherwise
//   shadowOnly          = 1.0 for the shadow-caster twin of the batch, which
//                         exists solely to occupy the shadow map: it collapses
//                         to nothing in every other pass (see below). 0.0 for
//                         the visible material.

VARYING vec4 vColor;
VARYING vec2 vUV;   // x = coordinate along segment axis, y = coordinate across
VARYING vec2 vCap;  // x = segment length, y = half width (segment-space units)
VARYING vec2 vDash; // x = path distance at segment start, y = world segment length
VARYING float vStyleId;   // constant per segment (same for all 4 quad vertices)
VARYING float vCapFlags;  // constant per segment: bit0 = start cap, bit1 = end cap
VARYING float vScreenScale; // screen pixels per world unit for this segment
                            // (used by screen-space pattern periods)
VARYING vec2 vHead; // x = arrowhead length (segment-space), y = head half width;
                    // (0, 0) when this segment has no arrowhead

void MAIN()
{
    // The shadow-caster twin shares this shader so its shadow is expanded by
    // exactly the same ribbon maths as the visible line - anything else and the
    // shadow would drift from the line it belongs to. It must not draw anywhere
    // but the shadow map, so outside the shadow passes it collapses to a
    // degenerate point behind the far plane and is clipped before rasterizing.
    //
    // These must be VALUE tests: Qt emits every pass macro in every variant as
    // "#define QSSG_ENABLE_..._SHADOW_PASS 0" or "... 1", so defined() is true
    // in all of them and would gate nothing.
#if !QSSG_ENABLE_ORTHO_SHADOW_PASS && !QSSG_ENABLE_PERSPECTIVE_SHADOW_PASS
    if (shadowOnly > 0.5) {
        POSITION = vec4(0.0, 0.0, 2.0, 1.0);
        return;
    }
#endif

    float t = VERTEX.x;                       // 0 at start, 1 at end
    float side = VERTEX.y;                     // -1 or +1
    float capDir = (t < 0.5) ? -1.0 : 1.0;     // longitudinal cap direction

    vColor = INSTANCE_COLOR;

    float width = INSTANCE_DATA.x;
    float halfW = 0.5 * width;

    // Cap flags decide which ends grow a longitudinal cap extension. Interior
    // (non-flagged) ends stay flush at the segment endpoint so joints are not
    // shaded twice; the neighbouring segment's end cap fills the joint.
    int capFlagsI = int(INSTANCE_DATA.w + 0.5);
    bool startCap = (capFlagsI & 1) != 0;
    bool endCap = (capFlagsI & 2) != 0;
    bool endFlagged = (t < 0.5) ? startCap : endCap;

    // Arrowhead params live in style-table row 2 (b = length, a = width, both
    // as raw line-width multiples straight from the style). Heads are a
    // single-segment feature (capFlags == 3), so a widened quad only appears
    // where it is a real end.
#if QSSG_ENABLE_ORTHO_SHADOW_PASS || QSSG_ENABLE_PERSPECTIVE_SHADOW_PASS
    // Shadow pass: no style-table fetch. Qt binds only the uniform buffer for
    // custom materials in the shadow map render - TextureInput samplers are
    // NOT bound there, so this fetch would read an unbound sampler and the
    // garbage would widen the quad via the arrowhead path (every single
    // segment has capFlags == 3), shredding the shadow silhouette. The twin
    // casts the plain shaft; arrowheads simply widen no quad here.
    float headWidM = 0.0;
    float headLenM = 0.0;
    bool headActive = false;
#else
    float styleCol = (INSTANCE_DATA.y + 0.5) / max(styleCount, 1.0);
    vec4 headRow = texture(styleTable, vec2(styleCol, 2.5 / 3.0));
    float headWidM = headRow.a;   // requested head base width (shaft-width mult)
    float headLenM = headRow.b;   // requested head length (shaft-width mult)
    bool headActive = (headWidM > 0.0) && (capFlagsI == 3);
#endif

    // Resolve arrowhead proportions - the geometry model. The head is a clean
    // triangle: its base is clamped to a real shoulder (>= 1.5x the shaft) and
    // its length is bounded so it can never turn into a needle - length defaults
    // to ~1.1x base width, is capped at 2x base width, and is floored at 0.6x so
    // it never degenerates to a stub. A consumer that over-requests length (e.g.
    // 40x to fill a short tip segment) collapses onto the 2x cap here, then the
    // whole head scales to the segment below.
    float baseWidM = clamp(headWidM, 1.5, 8.0);
    float lenM = headLenM > 0.0 ? headLenM : 1.1 * baseWidM;
    lenM = clamp(lenM, 0.6 * baseWidM, 2.0 * baseWidM);
    float headBaseHalfW = 0.5 * baseWidM * width; // unscaled head half width
    float headLenReq = lenM * width;              // unscaled head length

    // The quad widens to the (unscaled) head base so the triangle base always
    // fits; the fragment shader clips the shaft back to halfW and shades the
    // triangle only over the head region.
    float drawHalfW = headActive ? max(halfW, headBaseHalfW) : halfW;

    // Base-space segment endpoints.
    vec4 base0 = vec4(0.0, 0.0, 0.0, 1.0);
    vec4 base1 = vec4(1.0, 0.0, 0.0, 1.0);

    // World-space endpoints. Dash distance is measured in world units in both
    // width modes so the pattern stays consistent when zooming.
    vec3 wP0 = (INSTANCE_MODEL_MATRIX * base0).xyz;
    vec3 wP1 = (INSTANCE_MODEL_MATRIX * base1).xyz;
    float worldSegLen = length(wP1 - wP0);

    // Clip-space endpoints of the segment.
    vec4 clip0 = INSTANCE_MODELVIEWPROJECTION_MATRIX * base0;
    vec4 clip1 = INSTANCE_MODELVIEWPROJECTION_MATRIX * base1;

    vec4 clipPos = mix(clip0, clip1, t);
    float segLen;
    float capExt;   // longitudinal cap extension for THIS end (segment-space)

    if (widthMode < 0.5) {
        // Pixel mode: constant on-screen width regardless of distance.
        vec2 ndc0 = clip0.xy / clip0.w;
        vec2 ndc1 = clip1.xy / clip1.w;
        vec2 dScreen = (ndc1 - ndc0) * 0.5 * viewportSize;
        segLen = length(dScreen);
        vec2 dir = segLen > 1e-6 ? dScreen / segLen : vec2(1.0, 0.0);
        vec2 perp = vec2(-dir.y, dir.x);
        // Grow only flagged ends (halfW for the round cap + ~1px AA headroom);
        // flush (0) on interior joint ends.
        capExt = endFlagged ? (halfW + 1.0) : 0.0;
        vec2 offPx = perp * side * drawHalfW + dir * capDir * capExt;
        clipPos.xy += offPx * (2.0 / viewportSize) * clipPos.w;
    } else {
        // World mode: ribbon of constant world width, oriented either toward the
        // camera (Billboard, default) or laid flat in the ground plane (Flat).
        vec3 Pc = mix(wP0, wP1, t);
        vec3 axis = wP1 - wP0;
        segLen = worldSegLen;
        vec3 dir = worldSegLen > 1e-6 ? axis / worldSegLen : vec3(1.0, 0.0, 0.0);
        vec3 camDir = normalize(CAMERA_POSITION - Pc);
        vec3 billboardSide = cross(dir, camDir);
        vec3 sideDir;
        if (orientationMode >= 0.5) {
            // Flat: the across axis lies in the plane whose normal is world +Y,
            // so it stays perpendicular to the path IN the ground plane and never
            // shears for a ground overlay (the billboard tilts the across axis out
            // of the plane, shearing filled glyphs). Only +Y for now; a
            // configurable plane normal would be a future extension. A vertical
            // line (dir ~ +/-Y) has no in-plane perpendicular, so fall back to the
            // billboard vector there.
            vec3 flatSide = cross(dir, vec3(0.0, 1.0, 0.0));
            sideDir = length(flatSide) > 1e-4 ? flatSide : billboardSide;
        } else {
            sideDir = billboardSide;
        }
        float sl = length(sideDir);
        sideDir = sl > 1e-6 ? sideDir / sl : vec3(0.0, 1.0, 0.0);
        // Grow only flagged ends (halfW + a small world-space epsilon); flush
        // (0) on interior joint ends.
        capExt = endFlagged ? (halfW * 1.02) : 0.0;
        vec3 offset = sideDir * side * drawHalfW + dir * capDir * capExt;
        clipPos = VIEWPROJECTION_MATRIX * vec4(Pc + offset, 1.0);
    }

    // Segment-space coordinates for the capsule SDF in the fragment shader.
    // Along-axis runs from -capExt (start end) to segLen+capExt (end end); the
    // fragment shader still rounds against radius halfW, so the extra margin is
    // just discard headroom on flagged ends and zero on flush joint ends.
    vUV = vec2(t * segLen + capDir * capExt, side * drawHalfW);
    vCap = vec2(segLen, halfW);
    vDash = vec2(INSTANCE_DATA.z, worldSegLen);
    vStyleId = INSTANCE_DATA.y;
    vCapFlags = INSTANCE_DATA.w;
    // Head length is min(proportion-capped request, segment length); on segments
    // shorter than the head the WHOLE head scales down (proportions preserved),
    // so a short tip segment still yields a well-formed arrow rather than one
    // clipped to a sliver. vHead carries (head length, head half width) in
    // segment-space units for the fragment shader.
    float headLen = headLenReq;
    float headHalfW = headBaseHalfW;
    if (headActive && headLenReq > segLen) {
        float s = segLen / max(headLenReq, 1e-6);
        headLen = segLen;
        headHalfW = headBaseHalfW * s;
    }
    vHead = headActive ? vec2(headLen, headHalfW) : vec2(0.0, 0.0);

    // Screen-space length of this segment (pixels), so the fragment shader can
    // express a pattern period in screen pixels as well as world units.
    vec2 sNdc0 = clip0.xy / clip0.w;
    vec2 sNdc1 = clip1.xy / clip1.w;
    float screenSegLen = length((sNdc1 - sNdc0) * 0.5 * viewportSize);
    vScreenScale = worldSegLen > 1e-6 ? screenSegLen / worldSegLen : 1.0;

    // Depth bias: shift toward the camera so overlay lines win the depth
    // fight without a separate render pass. depthBias > 0 pulls closer.
    clipPos.z -= depthBias * clipPos.w * 0.0001;

    // Opaque mode (depthJitter == 1): add a tiny, bounded, table-order depth
    // offset so coplanar same-depth lines resolve deterministically by instance
    // index instead of shimmering with GPU-order ties. Negligible (<=2e-4) and
    // fully off (0) in the blended path.
    float jitter = float(INSTANCE_INDEX % 1024) * 2.0e-7;
    clipPos.z -= depthJitter * jitter * clipPos.w;

    POSITION = clipPos;
}
