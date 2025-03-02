VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;
VARYING vec3 pos;

void MAIN()
{
    // Calculate grid lines based on world position
    // No need for offset adjustment since we want grid lines at exact voxel boundaries
    vec3 gridPos = (pos - voxelOffset) / voxelSize;

    // Calculate distance to nearest grid line for each axis
    vec3 f = fract(gridPos);
    vec3 gridDist = vec3(min(1-f.x, f.x),
                         min(1-f.y, f.y),
                         min(1-f.z, f.z)); //abs(fract(gridPos) - 0.5) * voxelSize;

    // Line width as a fixed world-space value (not relative to voxel size)
    float lineWidth = 0.05;

    // Line is visible if any axis is close to a grid line
    float line = (
                 (gridDist.x < lineWidth && gridDist.y < lineWidth) ||
                 (gridDist.x < lineWidth && gridDist.z < lineWidth) ||
                 (gridDist.y < lineWidth && gridDist.z < lineWidth))
                 ? 1.0 : 0.0;

    // Mix the voxel color with the grid line color
    vec3 darker = colorOut.xyz * 0.2;
    BASE_COLOR = mix(colorOut, vec4(darker.x, darker.y, darker.z, 1.0), line);
}
