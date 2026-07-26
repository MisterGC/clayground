// LabelBatch3D pill (background) fragment shader.
// Rounded-rect SDF in the pill's base-px local space, unlit, premultiplied-
// correct straight-alpha blend. Uniforms:
//   pillColor  = fill rgba
//   pillRadius = corner radius in base px
//   labelOpacity = batch-wide opacity multiplier

VARYING vec4 vColor;
VARYING vec2 vLocal;
VARYING vec2 vHalf;

void MAIN()
{
    float r = min(pillRadius, min(vHalf.x, vHalf.y));
    vec2 q = abs(vLocal) - (vHalf - vec2(r));
    float dist = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;

    float aa = max(fwidth(dist), 1.0);
    float cov = 1.0 - smoothstep(-aa, aa, dist);

    float a = pillColor.a * vColor.a * cov * labelOpacity;
    if (a < 0.003)
        discard;

    FRAGCOLOR = vec4(pillColor.rgb, a);
}
