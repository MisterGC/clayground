// Pass through necessary variables for lighting
VARYING vec3 vNormal;
VARYING vec3 vViewVec;
VARYING vec4 colorOut;

void MAIN()
{
    // Transform vertex position
    POSITION = MODELVIEWPROJECTION_MATRIX * vec4(VERTEX, 1.0);

    // Pass the color through
    colorOut = COLOR;

    // Calculate and pass normal and view vector for lighting
    vNormal = normalize(NORMAL_MATRIX * NORMAL);
    vViewVec = CAMERA_POSITION - (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

