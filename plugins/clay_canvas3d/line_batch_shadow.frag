// LineBatch3D shadow-caster fragment shader.
//
// The twin material that lets a flat, world-width batch drop a shadow. The
// visible material is Unshaded: it does run in the shadow map render, but
// Qt's shader generator skips the pass's depth-output logic for unshaded
// materials, so its fragment colour would land in the map as garbage depth.
// This twin is Shaded, which makes Qt generate the proper shadow-pass
// fragment stage around it.
//
// In that generated stage the custom MAIN below is never called - the ortho
// and perspective shadow passes write their depth output directly and ignore
// the material's fragment snippet entirely. So no per-fragment shaping is
// possible here: the shadow silhouette is exactly the quad the vertex shader
// emits (the ribbon body plus the small cap extension at free ends). Dash
// gaps, glyph patterns, arrowheads and square-vs-round caps therefore do not
// cut the shadow - a dashed line casts a continuous one, which the shadow
// map's blur would have swallowed anyway.
//
// This snippet exists to keep the twin a valid Shaded material with the
// cheapest possible surface, and it must not sample any texture: Qt binds no
// custom TextureInput samplers in the shadow passes.

// Must mirror the vertex shader's set: Qt links the two VARYING blocks
// together, so the declarations have to agree even though the shadow passes
// never read them here.
VARYING vec4 vColor;
VARYING vec2 vUV;
VARYING vec2 vCap;
VARYING vec2 vDash;
VARYING float vStyleId;
VARYING float vCapFlags;
VARYING float vScreenScale;
VARYING vec2 vHead;

void MAIN()
{
    // Only reachable outside the shadow passes, where the vertex shader has
    // already collapsed the twin to a clipped point - keep the surface inert
    // so it could never contribute light even if it were rasterized.
    BASE_COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    EMISSIVE_COLOR = vec3(0.0);
    METALNESS = 0.0;
    ROUGHNESS = 1.0;
}
