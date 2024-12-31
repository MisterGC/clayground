VARYING vec4 colorOut;

void MAIN()
{
    vec4 worldPos = MODEL_MATRIX * vec4(VERTEX, 1.0);

    // Extract the side information and other end position from COLOR
    float side = COLOR.x;
    vec3 otherEnd = COLOR.yzw;
    vec4 otherWorldPos = MODEL_MATRIX * vec4(otherEnd, 1.0);

    // Calculate line direction in world space
    vec3 lineDir = normalize((otherWorldPos - worldPos).xyz);

    // Calculate camera direction
    vec3 cameraDir = normalize(CAMERA_POSITION - worldPos.xyz);

    // Calculate the perpendicular direction for billboarding
    vec3 sideDir = normalize(cross(lineDir, cameraDir));

    // Calculate the offset for the vertex
    vec3 offset = sideDir * side * lineWidth * 0.5;

    // Apply the offset to the world position
    vec4 finalWorldPos = worldPos + vec4(offset, 0.0);

    // Transform to clip space
    POSITION = MODELVIEWPROJECTION_MATRIX * finalWorldPos;

    colorOut = lineColor;
}

