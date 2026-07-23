// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// PathLabel3D word-quad vertex stage. Passes the quad through with a small
// clip-space bias toward the camera so the ground-decal word wins the depth
// fight against the (coplanar-ish, depth-writing) line it annotates.
VARYING vec2 vUV;

void MAIN()
{
    // Qt Quick renders sourceItem textures y-down; flip V so the sampled word
    // is upright (PrincipledMaterial does this internally, raw sampling not).
    vUV = vec2(UV0.x, 1.0 - UV0.y);
    vec4 clipPos = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);
    clipPos.z -= depthBias * clipPos.w;
    POSITION = clipPos;
}
