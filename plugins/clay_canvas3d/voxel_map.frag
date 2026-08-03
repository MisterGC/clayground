VARYING vec3 vNormal;
VARYING vec4 colorOut;
VARYING vec3 pos;

// Uniforms exposed from the CustomMaterial (in addition to built-in ones)
// - float voxelSize
// - vec3 voxelOffset
// - bool showEdges
// - float edgeThickness         // thickness in pixels, as in box3d.frag
// - float edgeColorFactor
// - vec4 edgeColor              // absolute edge colour; alpha 0 means "unset"
// - bool useToonShading         // enables toon/cartoon style lighting

void MAIN()
{
    if (showEdges){
        // Calculate grid lines based on world position. The grid is procedural
        // and at voxel cadence on purpose: greedy meshing merges a run of
        // voxels into one quad, and only a mesh-independent grid still draws
        // every cell border inside that merged quad.
        vec3 gridPos = (pos - voxelOffset) / voxelSize;

        // Calculate distance to nearest grid line for each axis
        vec3 f = fract(gridPos);
        vec3 gridDist = vec3(min(1-f.x, f.x),
                             min(1-f.y, f.y),
                             min(1-f.z, f.z));

        // How much of a voxel one pixel covers, per axis (#184). Taken on
        // gridPos rather than on its fract(), which would blow up at the
        // seam. Unlike the distanceToCamera / viewportHeight ratio this
        // replaces, it follows the FOV, the actual viewport and the
        // foreshortening of the surface - so a pixel is really a pixel.
        //
        // The floor keeps the axis a face is flat in usable: there the
        // derivative is zero and gridDist is zero up to float noise, and the
        // ratio has to come out as "on the line" rather than as 0/0.
        vec3 fw = max(fwidth(gridPos), vec3(1e-4));

        // Distance to the nearest grid line in pixels - the same unit
        // box3d.frag measures edgeThickness in.
        vec3 pixelDist = gridDist / fw;

        // Half of edgeThickness, because the line straddles its grid plane.
        // That is what makes the knob mean the same number of pixels on a
        // voxel map and on a box: box3d.frag ramps its edge out over
        // edgeThickness pixels, so its line is edgeThickness wide at half
        // intensity, and this one is edgeThickness wide outright.
        float halfWidth = edgeThickness * 0.5;

        // Line is visible if two axes are close to a grid line. On a face the
        // axis the face is flat in always qualifies, which leaves the two
        // running across it to draw the grid.
        float line = (
                     (pixelDist.x < halfWidth && pixelDist.y < halfWidth) ||
                     (pixelDist.x < halfWidth && pixelDist.z < halfWidth) ||
                     (pixelDist.y < halfWidth && pixelDist.z < halfWidth))
                     ? 1.0 : 0.0;

        // Mix the voxel color with the grid line color. edgeColor wins
        // whenever it is set at all, and "set" means a visible alpha - a fully
        // transparent edge has no meaning, so it is free to serve as the
        // sentinel. Without one, "unset" and an opaque black edge would be the
        // same value.
        vec3 e = edgeColor.a > 0.0 ? edgeColor.rgb : colorOut.rgb * edgeColorFactor;
        BASE_COLOR = mix(colorOut, vec4(e.x, e.y, e.z, 1.0), line);
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
