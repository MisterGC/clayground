// Box3D edge detection fragment shader
VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec2 vUV;
VARYING vec3 vOrigPosition;
VARYING vec3 vWorldPosition;
VARYING float vFaceID;

// Edge properties automatically exposed from the CustomMaterial
// - bool showEdges
// - float edgeThickness
// - float edgeColorFactor
// - float viewportHeight

void MAIN()
{
    // Base color with lighting applied
    vec4 finalColor = colorOut.rgba;

    if (showEdges) {
        // Calculate distance from edges using UV coordinates
        float distanceFromEdgeU = min(vUV.x, 1.0 - vUV.x);
        float distanceFromEdgeV = min(vUV.y, 1.0 - vUV.y);

        // Calculate view-dependent edge thickness
        float viewDistance = length(vViewVec);
        float pixelSizeAtDistance = viewDistance * edgeThickness / viewportHeight;
        float adjustedThickness = max(edgeThickness * 0.5, pixelSizeAtDistance);

        // Check if pixel is on an edge (similar to VoxelMap approach)
        bool isEdge = (distanceFromEdgeU < adjustedThickness || distanceFromEdgeV < adjustedThickness);

        if (isEdge) {
            // Apply darker color for edges, matching VoxelMap's approach
            vec3 edgeColor = colorOut.rgb * edgeColorFactor;
            finalColor = vec4(edgeColor, 1.0);
        }
    }

    BASE_COLOR = finalColor;
}
