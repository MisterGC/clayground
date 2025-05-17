VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec3 pos;

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
}
