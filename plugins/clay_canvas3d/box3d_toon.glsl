// ===== TOON SHADING IMPLEMENTATION =====
//
// Composed into box3d.frag and into any other fragment shader that has to sit
// next to a Box3D and be lit identically - see clay_compose_shader() in
// cmake/clayshader.cmake. Two body parts on one character lit by two copies of
// this would be one bug fix away from disagreeing, and disagreeing looks like
// one of them being a different material rather than like a lighting bug.
//
// Reads the uniform `useToonShading`, which the material is expected to carry.
//
// Cartoon-style lighting based on the half-lambert model from the
// QtWorldSummit demo.

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
