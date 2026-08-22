// Box3D's own fragment entry point.
//
// Composed with box3d_edges.glsl ahead of it and box3d_toon.glsl after it into
// box3d.frag - which is generated, so edit THIS file, not that one. The
// composition is declared in plugins/clay_canvas3d/CMakeLists.txt.

VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;
VARYING vec3 vBary;

// Uniforms exposed from the CustomMaterial
// - bool showEdges
// - float edgeThickness         // thickness in pixels
// - float edgeColorFactor
// - vec4 edgeColor              // absolute edge colour; alpha 0 means "unset"
// - int edgeMask                // bit mask for selective edge rendering
// - int edgeMode                // 0 = FaceBorders, 1 = Triangles
// - bool useToonShading         // enables toon/cartoon style lighting

void MAIN()
{
    // A plain box is its own tint: nothing is drawn on the face, so the colour
    // the outline darkens from and the colour under it are the same.
    BASE_COLOR = clayEdgeMix(colorOut, colorOut, vUV, vFaceID, vBary);

    // Set material properties appropriate for toon shading
    // When toon shading is enabled, we want:
    // - No metallic properties (toon is typically matte)
    // - High roughness to eliminate specular highlights
    if (useToonShading) {
        METALNESS = 0.0;
        ROUGHNESS = 1.0;  // Maximum roughness for flat shading
    }
    // When toon shading is disabled, use default material properties
    // Qt will apply its standard PBR lighting model
}
