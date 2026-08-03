// Box3D edge detection fragment shader with screen-space consistent edges

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

// Helper function to check if an edge should be displayed based on the mask.
// The distances arrive in pixels - .x to u=0, .y to u=1, .z to v=0, .w to v=1 -
// so this test tracks the band MAIN actually draws at any zoom. A fixed UV
// threshold stops agreeing with it the moment the face is small on screen,
// which clipped masked edges at the wide end of edgeThickness.
bool shouldShowEdge(float faceId, vec4 pixDist, float limit) {
    // First, identify which edge we're on
    bool isLeftEdge = pixDist.x <= limit;
    bool isRightEdge = pixDist.y <= limit;
    bool isBottomEdge = pixDist.z <= limit;
    bool isTopEdge = pixDist.w <= limit;

    // If we're not on any edge, return false
    if (!(isLeftEdge || isRightEdge || isBottomEdge || isTopEdge)) {
        return false;
    }

    // Map to the bit constants from Box3DGeometry::EdgeFlags
    // TopEdges = 0x3C (00111100)
    // BottomEdges = 0x03 (00000011)
    // FrontEdges = 0x99 (10011001)
    // BackEdges = 0x66 (01100110)
    // LeftEdges = 0xAA (10101010)
    // RightEdges = 0x55 (01010101)

    // Determine the bit mask for the current edge
    int edgeBit = 0;

    if (faceId == 1.0) { // Right face
        if (isTopEdge) edgeBit = 0x10;    // bit 4
        if (isBottomEdge) edgeBit = 0x01; // bit 0
        if (isLeftEdge) edgeBit = 0x40;   // bit 6
        if (isRightEdge) edgeBit = 0x04;  // bit 2
    }
    else if (faceId == 2.0) { // Left face
        if (isTopEdge) edgeBit = 0x20;    // bit 5
        if (isBottomEdge) edgeBit = 0x02; // bit 1
        if (isLeftEdge) edgeBit = 0x08;   // bit 3
        if (isRightEdge) edgeBit = 0x80;  // bit 7
    }
    else if (faceId == 3.0) { // Top face
        if (isLeftEdge) edgeBit = 0x20;   // bit 5
        if (isRightEdge) edgeBit = 0x10;  // bit 4
        if (isBottomEdge) edgeBit = 0x08; // bit 3
        if (isTopEdge) edgeBit = 0x04;    // bit 2
    }
    else if (faceId == 4.0) { // Bottom face
        if (isLeftEdge) edgeBit = 0x02;   // bit 1
        if (isRightEdge) edgeBit = 0x01;  // bit 0
        if (isBottomEdge) edgeBit = 0x40; // bit 6
        if (isTopEdge) edgeBit = 0x80;    // bit 7
    }
    else if (faceId == 5.0) { // Front face
        if (isLeftEdge) edgeBit = 0x02;   // bit 1
        if (isRightEdge) edgeBit = 0x01;  // bit 0
        if (isBottomEdge) edgeBit = 0x80; // bit 7
        if (isTopEdge) edgeBit = 0x08;    // bit 3
    }
    else if (faceId == 6.0) { // Back face
        if (isLeftEdge) edgeBit = 0x20;   // bit 5
        if (isRightEdge) edgeBit = 0x10;  // bit 4
        if (isBottomEdge) edgeBit = 0x04; // bit 2
        if (isTopEdge) edgeBit = 0x40;    // bit 6
    }

    // Check if the edge's bit is set in the mask
    return (edgeMask & edgeBit) != 0;
}

void MAIN()
{
    vec4 finalColor = colorOut;

    if (showEdges) {
        float edgeFactor = 0.0;
        bool showThisEdge = true;

        // A line straddles the boundary it marks, so each side draws half of
        // it - the same rule voxel_map.frag follows, and what makes
        // edgeThickness: N mean the same visible width on both types. What
        // used to happen here was a smoothstep ramping out over the whole of
        // edgeThickness in UV space, which reads several times thinner than a
        // voxel grid line at the same setting; the demo carried a x4 factor
        // on the boxes to compensate.
        float halfWidth = edgeThickness * 0.5;

        if (edgeMode == 1) {
            // Triangles: the box's own triangulation, diagonals included. The
            // barycentric coordinate is zero along every edge of the triangle
            // it belongs to, so the smallest of its three components is the
            // distance to the nearest one. edgeMask does not apply here - a
            // triangulation missing some of its lines is not a triangulation.
            float d = min(min(vBary.x, vBary.y), vBary.z);
            float p = d / max(fwidth(d), 1e-8);
            edgeFactor = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, p);
        } else {
            // FaceBorders: the twelve borders, read off the per-face UVs.
            // Screen-space derivatives give us how much UV one pixel covers,
            // so a UV distance divided by one of them is a pixel count.
            float fwU = max(fwidth(vUV.x), 1e-8);
            float fwV = max(fwidth(vUV.y), 1e-8);

            // Pixels to each of the four borders of this face
            vec4 pixDist = vec4(vUV.x, 1.0 - vUV.x, vUV.y, 1.0 - vUV.y)
                         / vec4(fwU, fwU, fwV, fwV);

            // Solid out to halfWidth, then one pixel of ramp to keep it from
            // aliasing - which is the one thing the voxel grid, with its hard
            // threshold, does worse.
            float p = min(min(pixDist.x, pixDist.y), min(pixDist.z, pixDist.w));
            edgeFactor = 1.0 - smoothstep(halfWidth - 0.5, halfWidth + 0.5, p);

            // Check if we should show this edge based on the mask
            showThisEdge = shouldShowEdge(vFaceID, pixDist, halfWidth + 0.5);
        }

        if (edgeFactor > 0.0 && showThisEdge) {
            // edgeColor wins whenever it is set at all, and "set" means a
            // visible alpha - a fully transparent edge has no meaning, so it
            // is free to serve as the sentinel. Without one, "unset" and an
            // opaque black edge would be the same value.
            vec3 e = edgeColor.a > 0.0 ? edgeColor.rgb
                                       : colorOut.rgb * edgeColorFactor;
            finalColor = mix(finalColor, vec4(e, 1.0), edgeFactor);
        }
    }

    BASE_COLOR = finalColor;
    
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

// ===== TOON SHADING IMPLEMENTATION =====
// The following functions implement cartoon-style lighting
// Based on the half-lambert lighting model from the QtWorldSummit demo

// Core toon lighting calculation using half-lambert formula
// This creates the characteristic cartoon look by:
// 1. Adding 0.5 to the dot product to avoid completely dark areas
// 2. Scaling by 0.5 to normalize back to 0-1 range
// Result: Even surfaces facing away from light receive 50% illumination
vec3 diffuseToonSimple(in vec3 normal, in vec3 toLightDirection) {
    float NdotL = dot(normal, toLightDirection);
    float value = (NdotL + 1.0) * 0.5;  // Half-lambert formula
    return vec3(value);
}

// Handle directional lights (sun, key lights)
void DIRECTIONAL_LIGHT() {
    if (useToonShading) {
        // Calculate toon diffuse lighting
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        
        // Apply lighting with shadow contribution
        // SHADOW_CONTRIB creates the hard light/dark transitions characteristic of toon shading
        // Strong shadows (shadowFactor ~78) create distinct bands of light and shadow
        DIFFUSE += diffuse * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    } else {
        // Standard PBR diffuse lighting when toon shading is disabled
        // This replaces Qt's default behavior which we override by defining this function
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    }
}

// Handle point lights (omni-directional lights)
void POINT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        // Include light attenuation for distance falloff
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION;
    } else {
        // Standard PBR point light when toon shading is disabled
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION;
    }
}

// Handle spot lights (cone-shaped lights)
void SPOT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        // Include both attenuation and spot factor for cone falloff
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION * SPOT_FACTOR;
    } else {
        // Standard PBR spot light when toon shading is disabled
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION * SPOT_FACTOR;
    }
}

// Handle specular highlights
void SPECULAR_LIGHT() {
    if (useToonShading) {
        // Intentionally empty - no specular calculation for toon shading
    } else {
        // Allow Qt's default specular calculation when toon shading is disabled
        // We don't override this - let Qt handle standard specular
    }
}

// Handle image-based lighting
void IBL_PROBE() {
    if (useToonShading) {
        // Intentionally empty - no IBL for toon shading
    } else {
        // Allow Qt's default IBL when toon shading is disabled
        // We don't override this - let Qt handle standard IBL
    }
}
