VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec3 pos;

// Uniforms exposed from the CustomMaterial (in addition to built-in ones)
// - float voxelSize
// - vec3 voxelOffset
// - bool showEdges
// - float edgeThickness
// - float edgeColorFactor
// - float viewportHeight
// - bool useToonShading         // enables toon/cartoon style lighting

void MAIN()
{
    if (showEdges){
        // Calculate grid lines based on world position
        vec3 gridPos = (pos - voxelOffset) / voxelSize;

        // Calculate distance to nearest grid line for each axis
        vec3 f = fract(gridPos);
        vec3 gridDist = vec3(min(1-f.x, f.x),
                             min(1-f.y, f.y),
                             min(1-f.z, f.z));

        // Convert pixel width to view space based on distance from camera and viewport size
        float distanceToCamera = length(vViewVec);
        float pixelSizeAtDistance = distanceToCamera * edgeThickness / viewportHeight;

        // Account for perspective by scaling with distance
        float lineWidthVoxelSpace = pixelSizeAtDistance / voxelSize;

        // Line is visible if any axis is close to a grid line
        float line = (
                     (gridDist.x < lineWidthVoxelSpace && gridDist.y < lineWidthVoxelSpace) ||
                     (gridDist.x < lineWidthVoxelSpace && gridDist.z < lineWidthVoxelSpace) ||
                     (gridDist.y < lineWidthVoxelSpace && gridDist.z < lineWidthVoxelSpace))
                     ? 1.0 : 0.0;

        // Mix the voxel color with the grid line color
        vec3 edgeColor = colorOut.xyz * edgeColorFactor;
        BASE_COLOR = mix(colorOut, vec4(edgeColor.x, edgeColor.y, edgeColor.z, 1.0), line);
    }
    else {
        BASE_COLOR = colorOut;
    }
    
    // Set material properties appropriate for toon shading
    // For voxel maps, this is especially important to get the blocky, cartoon aesthetic
    if (useToonShading) {
        METALNESS = 0.0;
        ROUGHNESS = 1.0;  // Maximum roughness for flat shading
    }
    // When toon shading is disabled, use default material properties
}

// ===== TOON SHADING IMPLEMENTATION =====
// The following functions implement cartoon-style lighting for voxel maps
// This creates a Minecraft-like aesthetic with distinct light/shadow boundaries

// Core toon lighting calculation using half-lambert formula
// For voxel maps, this enhances the blocky aesthetic by creating
// uniform lighting on each voxel face
vec3 diffuseToonSimple(in vec3 normal, in vec3 toLightDirection) {
    float NdotL = dot(normal, toLightDirection);
    float value = (NdotL + 1.0) * 0.5;  // Half-lambert formula
    return vec3(value);
}

// Handle directional lights (sun, key lights)
// For voxel worlds, directional lights create the primary day/night cycle effect
void DIRECTIONAL_LIGHT() {
    if (useToonShading) {
        // Calculate toon diffuse lighting
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        
        // Apply lighting with shadow contribution
        // With voxels, strong shadows create dramatic blocky shadow patterns
        DIFFUSE += diffuse * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    } else {
        // Standard PBR diffuse lighting when toon shading is disabled
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB;
    }
}

// Handle point lights (torches, lamps in voxel worlds)
void POINT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
        // Point lights in voxel worlds often represent torches or lamps
        DIFFUSE += BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * diffuse * LIGHT_ATTENUATION;
    } else {
        // Standard PBR point light when toon shading is disabled
        float NdotL = max(dot(NORMAL, TO_LIGHT_DIR), 0.0);
        DIFFUSE += NdotL * BASE_COLOR.rgb * LIGHT_COLOR * SHADOW_CONTRIB * LIGHT_ATTENUATION;
    }
}

// Handle spot lights (focused light sources)
void SPOT_LIGHT() {
    if (useToonShading) {
        vec3 diffuse = diffuseToonSimple(NORMAL, TO_LIGHT_DIR);
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
        // Intentionally empty - no specular for blocky voxel aesthetic
    } else {
        // Allow Qt's default specular calculation when toon shading is disabled
    }
}

// Handle image-based lighting
void IBL_PROBE() {
    if (useToonShading) {
        // Intentionally empty - no IBL for voxel toon shading
    } else {
        // Allow Qt's default IBL when toon shading is disabled
    }
}
