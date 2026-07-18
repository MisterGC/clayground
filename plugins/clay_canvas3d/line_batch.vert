// LineBatch3D vertex shader.
// Expands one instanced unit quad per line segment into a camera-facing
// ribbon with round caps. The base quad vertex carries the segment
// parameter t (VERTEX.x, 0 = start, 1 = end) and the side factor
// (VERTEX.y, -1 or +1). Per-line style rides in the instance attributes:
//   INSTANCE_COLOR      = line color
//   INSTANCE_DATA.x     = line width (pixels in Pixel mode, world in World mode)
//   INSTANCE_DATA.y     = styleId (reserved, unused for now)
// Material uniforms (bound from LineBatch3D):
//   viewportSize        = View3D pixel size (vec2)
//   widthMode           = 0.0 -> Pixel width, 1.0 -> World width
//   depthBias           = pulls the line toward the camera to win z-fights

VARYING vec4 vColor;
VARYING vec2 vUV;   // x = coordinate along segment axis, y = coordinate across
VARYING vec2 vCap;  // x = segment length, y = half width (segment-space units)

void MAIN()
{
    float t = VERTEX.x;                       // 0 at start, 1 at end
    float side = VERTEX.y;                     // -1 or +1
    float capDir = (t < 0.5) ? -1.0 : 1.0;     // longitudinal cap direction

    vColor = INSTANCE_COLOR;

    float width = INSTANCE_DATA.x;
    float halfW = 0.5 * width;

    // Base-space segment endpoints.
    vec4 base0 = vec4(0.0, 0.0, 0.0, 1.0);
    vec4 base1 = vec4(1.0, 0.0, 0.0, 1.0);

    // Clip-space endpoints of the segment.
    vec4 clip0 = INSTANCE_MODELVIEWPROJECTION_MATRIX * base0;
    vec4 clip1 = INSTANCE_MODELVIEWPROJECTION_MATRIX * base1;

    vec4 clipPos = mix(clip0, clip1, t);
    float segLen;

    if (widthMode < 0.5) {
        // Pixel mode: constant on-screen width regardless of distance.
        vec2 ndc0 = clip0.xy / clip0.w;
        vec2 ndc1 = clip1.xy / clip1.w;
        vec2 dScreen = (ndc1 - ndc0) * 0.5 * viewportSize;
        segLen = length(dScreen);
        vec2 dir = segLen > 1e-6 ? dScreen / segLen : vec2(1.0, 0.0);
        vec2 perp = vec2(-dir.y, dir.x);
        vec2 offPx = perp * side * halfW + dir * capDir * halfW;
        clipPos.xy += offPx * (2.0 / viewportSize) * clipPos.w;
    } else {
        // World mode: billboarded ribbon of constant world width.
        vec3 P0 = (INSTANCE_MODEL_MATRIX * base0).xyz;
        vec3 P1 = (INSTANCE_MODEL_MATRIX * base1).xyz;
        vec3 Pc = mix(P0, P1, t);
        vec3 axis = P1 - P0;
        float wlen = length(axis);
        segLen = wlen;
        vec3 dir = wlen > 1e-6 ? axis / wlen : vec3(1.0, 0.0, 0.0);
        vec3 camDir = normalize(CAMERA_POSITION - Pc);
        vec3 sideDir = cross(dir, camDir);
        float sl = length(sideDir);
        sideDir = sl > 1e-6 ? sideDir / sl : vec3(0.0, 1.0, 0.0);
        vec3 offset = sideDir * side * halfW + dir * capDir * halfW;
        clipPos = VIEWPROJECTION_MATRIX * vec4(Pc + offset, 1.0);
    }

    // Segment-space coordinates for the capsule SDF in the fragment shader.
    // Along-axis runs from -halfW (start cap) to segLen+halfW (end cap).
    vUV = vec2(t * segLen + capDir * halfW, side * halfW);
    vCap = vec2(segLen, halfW);

    // Depth bias: shift toward the camera so overlay lines win the depth
    // fight without a separate render pass. depthBias > 0 pulls closer.
    clipPos.z -= depthBias * clipPos.w * 0.0001;

    POSITION = clipPos;
}
