// LabelBatch3D pill (background) vertex shader.
// One instanced unit quad per label, sized to the label's glyph bounding box
// plus padding. Instance decode (see LabelBatchInstancing pill contract):
//   translation (M*(0,0,0,1)) = anchor world position
//   col0 (M*(1,0,0,0))        = (pillCenterX, pillCenterY, size)  base px, y-up
//   col2 (M*(0,0,1,0))        = (unused, pillW, pillH)
// Uniforms mirror label_batch.vert (viewportSize, baseSize, sizeMode,
// orientationMode).

VARYING vec4 vColor;
VARYING vec2 vLocal; // base-px offset from the pill center
VARYING vec2 vHalf;  // half extents in base px

void MAIN()
{
    vec2 corner = vec2(VERTEX.x, VERTEX.y * 0.5 + 0.5); // 0..1

    mat4 M = INSTANCE_MODEL_MATRIX;
    vec3 anchor = (M * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    vec3 c0 = (M * vec4(1.0, 0.0, 0.0, 0.0)).xyz; // cx, cy, size
    vec3 c2 = (M * vec4(0.0, 0.0, 1.0, 0.0)).xyz; // -, pillW, pillH

    float cx = c0.x, cy = c0.y, size = c0.z;
    float pillW = c2.y, pillH = c2.z;

    vColor = INSTANCE_COLOR;
    vHalf = 0.5 * vec2(pillW, pillH);
    vLocal = vec2((corner.x - 0.5) * pillW, (corner.y - 0.5) * pillH);

    float lx = cx + vLocal.x;
    float ly = cy + vLocal.y;
    float k = size / max(baseSize, 1.0);

    vec4 clipPos;
    if (sizeMode < 0.5) {
        vec4 clipA = VIEWPROJECTION_MATRIX * vec4(anchor, 1.0);
        vec2 offPx = vec2(lx, ly) * k;
        clipPos = clipA;
        clipPos.xy += offPx * (2.0 / viewportSize) * clipA.w;
    } else {
        vec3 wpos;
        if (orientationMode >= 0.5) {
            wpos = anchor + vec3(lx * k, 0.0, -ly * k);
        } else {
            vec3 toCam = normalize(CAMERA_POSITION - anchor);
            vec3 right = cross(vec3(0.0, 1.0, 0.0), toCam);
            float rl = length(right);
            right = rl > 1e-5 ? right / rl : vec3(1.0, 0.0, 0.0);
            vec3 up = cross(toCam, right);
            wpos = anchor + right * (lx * k) + up * (ly * k);
        }
        clipPos = VIEWPROJECTION_MATRIX * vec4(wpos, 1.0);
    }

    // Sit just behind the glyphs, which pull to 0.00010 in pill mode. The pill
    // writes depth too (AlwaysDepthDraw), so this smaller bias makes the pill
    // depth-fail exactly on inked text pixels when it happens to draw after the
    // glyphs - the text stays readable regardless of transparent-pass order.
    clipPos.z -= 0.00004 * clipPos.w;
    POSITION = clipPos;
}
