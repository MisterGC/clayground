// LineBatch3D fragment shader.
// Alpha-discards outside the capsule SDF so that segments get seamless round
// caps that also close the joint gaps between consecutive segments.

VARYING vec4 vColor;
VARYING vec2 vUV;   // x = along-axis coordinate, y = across coordinate
VARYING vec2 vCap;  // x = segment length, y = half width

void MAIN()
{
    float segLen = vCap.x;
    float halfW = vCap.y;
    float u = vUV.x;
    float v = vUV.y;

    // Distance to the segment centerline (a capsule of radius halfW).
    float uc = clamp(u, 0.0, segLen);
    float dist = length(vec2(u - uc, v));
    if (dist > halfW)
        discard;

    FRAGCOLOR = vColor;
}
