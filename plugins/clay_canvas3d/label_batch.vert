// LabelBatch3D glyph vertex shader.
// One instanced unit quad per inking glyph. The base quad vertex carries the
// corner in x (0..1) and y (-1..+1 -> mapped to 0..1). Per-glyph data rides in
// the instance table, decoded from INSTANCE_MODEL_MATRIX via basis vectors
// (see LabelBatchInstancing for the frozen 80-byte contract):
//   translation (M*(0,0,0,1)) = anchor world position
//   col0 (M*(1,0,0,0))        = (offX, offY, size)   label-local base px, y-up
//   col1 (M*(0,1,0,0))        = (u0, v0, u1)          atlas UV (v0 = top)
//   col2 (M*(0,0,1,0))        = (v1, glyphW, glyphH)
//   INSTANCE_DATA.z           = per-glyph yaw about the quad normal (radians)
// INSTANCE_DATA.z is 0 for every straight-baseline label (setLabels), so the
// rotation below is a guarded no-op there and the output stays byte-identical.
// Only curved labels (setCurvedLabels / PathLabel3D glyph placement) set it.
// Material uniforms:
//   viewportSize     = View3D pixel size (vec2)
//   baseSize         = atlas rasterization size in px (size / baseSize scales
//                      label-local base px to the target)
//   sizeMode         = 0 -> Screen (constant on-screen px), 1 -> World units
//   orientationMode  = 0 -> Billboard (face camera), 1 -> Flat (ground XZ plane)

VARYING vec2 vUV;
VARYING vec4 vColor;
VARYING float vOpacity;

void MAIN()
{
    vec2 corner = vec2(VERTEX.x, VERTEX.y * 0.5 + 0.5); // 0..1

    mat4 M = INSTANCE_MODEL_MATRIX;
    vec3 anchor = (M * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 c0 = (M * vec4(1.0, 0.0, 0.0, 0.0)).xyz; // offX, offY, size
    vec3 c1 = (M * vec4(0.0, 1.0, 0.0, 0.0)).xyz; // u0, v0, u1
    vec3 c2 = (M * vec4(0.0, 0.0, 1.0, 0.0)).xyz; // v1, glyphW, glyphH

    float offX = c0.x;
    float offY = c0.y;
    float size = c0.z;
    float u0 = c1.x, v0 = c1.y, u1 = c1.z;
    float v1 = c2.x, glyphW = c2.y, glyphH = c2.z;

    // corner.y == 1 is the quad top (offY + glyphH) -> atlas top row (v0).
    vUV = vec2(mix(u0, u1, corner.x), mix(v1, v0, corner.y));
    vColor = INSTANCE_COLOR;
    vOpacity = INSTANCE_DATA.y;

    float lx = offX + corner.x * glyphW;
    float ly = offY + corner.y * glyphH;

    // Per-glyph rotation about the quad normal (curved labels only). Guarded so
    // the zero-angle straight path is left exactly untouched.
    float glyphAngle = INSTANCE_DATA.z;
    if (glyphAngle != 0.0) {
        float ca = cos(glyphAngle);
        float sa = sin(glyphAngle);
        float rlx = lx * ca - ly * sa;
        float rly = lx * sa + ly * ca;
        lx = rlx;
        ly = rly;
    }

    float k = size / max(baseSize, 1.0);

    vec4 clipPos;
    if (sizeMode < 0.5) {
        // Screen: constant on-screen px, always camera-facing (billboard).
        vec4 clipA = VIEWPROJECTION_MATRIX * vec4(anchor, 1.0);
        vec2 offPx = vec2(lx, ly) * k;
        clipPos = clipA;
        clipPos.xy += offPx * (2.0 / viewportSize) * clipA.w;
    } else {
        vec3 wpos;
        if (orientationMode >= 0.5) {
            // Flat: lie in the world XZ ground plane (text upright looking down).
            wpos = anchor + vec3(lx * k, 0.0, -ly * k);
        } else {
            // World billboard: face the camera with world-sized text.
            vec3 toCam = normalize(CAMERA_POSITION - anchor);
            vec3 right = cross(vec3(0.0, 1.0, 0.0), toCam);
            float rl = length(right);
            right = rl > 1e-5 ? right / rl : vec3(1.0, 0.0, 0.0);
            vec3 up = cross(toCam, right);
            wpos = anchor + right * (lx * k) + up * (ly * k);
        }
        clipPos = VIEWPROJECTION_MATRIX * vec4(wpos, 1.0);
    }

    // Small built-in bias toward the camera so labels sit above coplanar
    // geometry; depthBias (0 by default) adds a caller-tunable shift so a ground
    // decal can out-bias a line it lies on. depthBias == 0 keeps the old value.
    clipPos.z -= (0.00005 + depthBias) * clipPos.w;
    POSITION = clipPos;
}
