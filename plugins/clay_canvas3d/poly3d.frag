// Poly3D fragment shader - flat filled area, optional toon lighting.
//
// The lighting half is deliberately the same code Box3D runs, copied rather
// than shared: CustomMaterial snippets have no #include, so a polygon next to
// a box in the same scene can only match by repeating it.

VARYING vec4 colorOut;

// Uniforms exposed from the CustomMaterial
// - bool useToonShading      // enables toon/cartoon style lighting

void MAIN()
{
    BASE_COLOR = colorOut;

    // Toon shading wants a matte surface: no metal, no specular highlight.
    if (useToonShading) {
        METALNESS = 0.0;
        ROUGHNESS = 1.0;
    }
}

// ===== TOON SHADING IMPLEMENTATION =====
// Half-lambert lighting, the same model Box3D uses, so a Poly3D floor and the
// Box3D buildings standing on it read as one scene.

vec3 diffuseToonSimple(in vec3 normal, in vec3 toLightDirection) {
    float NdotL = dot(normal, toLightDirection);
    float value = (NdotL + 1.0) * 0.5;  // Half-lambert formula
    return vec3(value);
}

void DIRECTIONAL_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += diffuse * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    }
}

void POINT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION;
    }
}

void SPOT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION * SPOT_FACTOR;
    } else {
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION * SPOT_FACTOR;
    }
}

// Defining these at all replaces Qt's default term with nothing - there is no
// way to opt back in per frame. Toon shading wants them gone, and Box3D makes
// the same trade, so a polygon and a box keep the same matte look.
void SPECULAR_LIGHT() {
}

void IBL_PROBE() {
}
